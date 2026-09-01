"""Exercise the gates that protect the bill.

Each gate gets its own database and its own settings, because they interact:
a low spend cap will trip during a rate-limit test and hide the result.
"""
import importlib, os, sys

FAILS = []
def check(label, cond, extra=""):
    print(f"  {'PASS' if cond else 'FAIL'}  {label}{('  ' + extra) if extra else ''}")
    if not cond: FAILS.append(label)

def fresh(db, **env):
    """A relay with its own database and settings."""
    for f in (db, db + "-journal"):
        if os.path.exists(f): os.remove(f)
    os.environ.update({"DATABASE_URL": f"sqlite:///./{db}",
                       "ANTHROPIC_API_KEY": "test-key", **env})
    for mod in ("app.config", "app.models", "app.receipts", "app.main"):
        if mod in sys.modules: del sys.modules[mod]
    import app.main as M
    captured = {}
    class FakeResponse:
        status_code = 200
        def json(self): return {
            "content": [{"type": "text", "text": '{"ok":true}'}],
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 6000, "output_tokens": 1400,
                      "cache_read_input_tokens": 4500}}
    class FakeClient:
        def __init__(self, *a, **k): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *a): return False
        async def post(self, url, json=None, headers=None):
            captured.clear(); captured.update(json); return FakeResponse()
    M.httpx.AsyncClient = FakeClient
    from fastapi.testclient import TestClient
    client = TestClient(M.app); client.__enter__()
    return client, captured

BODY = {"modality": "face", "system": "sys", "max_tokens": 99999,
        "output_config": {"effort": "high", "format": {"type": "json_schema", "schema": {}}},
        "messages": [{"role": "user", "content": "hi"}]}
GENEROUS = {"DAILY_SPEND_CAP_USD": "1000", "RATE_LIMIT_PER_HOUR": "100",
            "RATE_LIMIT_PER_DAY": "100"}

print("\n— identity —")
c, _ = fresh("t1.db", FREE_READINGS="3", **GENEROUS)
check("no device id is rejected", c.post("/v1/reading", json=BODY).status_code == 400)
check("a too-short id is rejected",
      c.post("/v1/reading", json=BODY, headers={"x-device-id": "abc"}).status_code == 400)

print("\n— free allowance (3) —")
H = {"x-device-id": "device-aaaaaaaa"}
for i, expected in enumerate([2, 1, 0], start=1):
    r = c.post("/v1/reading", json=BODY, headers=H)
    check(f"free reading {i} allowed", r.status_code == 200,
          f"remaining={r.json().get('free_remaining')}")
    check(f"  remaining counts down to {expected}",
          r.json().get("free_remaining") == expected)
r = c.post("/v1/reading", json=BODY, headers=H)
check("4th is refused with 402", r.status_code == 402)
check("a fresh device still gets its own allowance",
      c.post("/v1/reading", json=BODY,
             headers={"x-device-id": "device-zzzzzzzz"}).status_code == 200)

print("\n— the relay decides the model, not the client —")
c2, cap = fresh("t2.db", FREE_READINGS="9", **GENEROUS)
c2.post("/v1/reading", json={**BODY, "model": "claude-opus-5"},
        headers={"x-device-id": "device-bbbbbbbb"})
check("client's model is ignored", cap.get("model") == "claude-haiku-4-5",
      f"sent={cap.get('model')}")
check("max_tokens is capped", cap.get("max_tokens") == 8000,
      f"asked 99999, sent {cap.get('max_tokens')}")
check("effort stripped (Haiku rejects it)", "effort" not in cap.get("output_config", {}))
check("system prompt is cached",
      cap.get("system", [{}])[0].get("cache_control") == {"type": "ephemeral"})

print("\n— rate limit (5/hour) —")
c3, _ = fresh("t3.db", FREE_READINGS="99", RATE_LIMIT_PER_HOUR="5",
              RATE_LIMIT_PER_DAY="99", DAILY_SPEND_CAP_USD="1000")
codes = [c3.post("/v1/reading", json=BODY,
                 headers={"x-device-id": "device-cccccccc"}).status_code
         for _ in range(7)]
check("allows exactly 5 then blocks", codes[:5] == [200]*5 and codes[5:] == [429, 429],
      f"codes={codes}")

print("\n— spend cap —")
c4, _ = fresh("t4.db", FREE_READINGS="99", RATE_LIMIT_PER_HOUR="99",
              RATE_LIMIT_PER_DAY="99", DAILY_SPEND_CAP_USD="0.02")
codes = [c4.post("/v1/reading", json=BODY,
                 headers={"x-device-id": "device-dddddddd"}).status_code
         for _ in range(4)]
check("pauses the whole service once the cap trips", 503 in codes, f"codes={codes}")
check("a different device is paused too — the cap is global",
      c4.post("/v1/reading", json=BODY,
              headers={"x-device-id": "device-eeeeeeee"}).status_code == 503)

print("\n— forged subscription —")
c5, _ = fresh("t5.db", FREE_READINGS="1", **GENEROUS)
r = c5.post("/v1/reading", json=BODY,
            headers={"x-device-id": "device-ffffffff", "x-transaction": "not.a.jws"})
check("a bad transaction does not grant a subscription",
      r.status_code == 200 and r.json().get("subscribed") is False)
r = c5.post("/v1/reading", json=BODY,
            headers={"x-device-id": "device-ffffffff", "x-transaction": "not.a.jws"})
check("and it still consumes the free allowance", r.status_code == 402)

print("\n— status endpoint —")
r = c5.get("/v1/status", headers={"x-device-id": "device-ffffffff"})
check("reports the true remaining count", r.json().get("free_remaining") == 0)

for f in ("t1.db", "t2.db", "t3.db", "t4.db", "t5.db"):
    if os.path.exists(f): os.remove(f)
print(f"\n{'ALL PASS' if not FAILS else 'FAILURES: ' + ', '.join(FAILS)}")
sys.exit(1 if FAILS else 0)
