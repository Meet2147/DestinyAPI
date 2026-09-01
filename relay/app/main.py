"""AuraScan relay.

Holds the Anthropic key so the app does not have to. Everything else here
exists because the client cannot be trusted: it decides who may take a reading,
how often, and stops the whole service before a runaway bill.
"""
from __future__ import annotations

import logging

import httpx
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse

from app import models
from app.config import settings
from app.models import (count_recent, init_db, record_reading, set_subscriber,
                        spend_today, touch_device)
from app.receipts import ReceiptError, verify_transaction

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("relay")

@asynccontextmanager
async def lifespan(_: FastAPI):
    _prepare()
    yield


app = FastAPI(title="AuraScan Relay", version="1.0.0",
              docs_url=None, redoc_url=None, lifespan=lifespan)

# Per-million-token prices for the pinned model, used to meter spend.
PRICE_IN, PRICE_OUT, PRICE_CACHE_READ = 1.00, 5.00, 0.10


def _prepare() -> None:
    init_db()
    if not settings.anthropic_api_key:
        log.error("ANTHROPIC_API_KEY is not set — every reading will fail")
    if not settings.allow_unverified_devices:
        from app.receipts import roots
        if not roots():
            log.warning("no Apple root certificate installed; "
                        "subscriptions cannot be verified")


# Also run at import. A worker that somehow starts without the lifespan hook
# would otherwise 500 on every request with "no such table", which is a
# miserable thing to debug in production.
_prepare()


@app.get("/health")
def health():
    # `key_configured` is a boolean, never the key. Without it every reading
    # fails upstream, and that is otherwise indistinguishable from a network
    # problem — which is exactly the confusion this is here to end.
    return {
        "ok": True,
        "model": settings.model,
        "key_configured": bool(settings.anthropic_api_key),
        "roots_installed": len(_root_count()),
    }


def _root_count():
    try:
        from app.receipts import roots
        return roots()
    except Exception:
        return []


@app.get("/v1/selftest")
async def selftest():
    """Proves whether the relay can actually reach Anthropic.

    Returns a status and a short reason, never the upstream body: an error
    message can echo request contents back to whoever asks.
    """
    if not settings.anthropic_api_key:
        return {"ok": False, "reason": "ANTHROPIC_API_KEY is not set on this service"}
    try:
        async with httpx.AsyncClient(timeout=45) as client:
            r = await client.post(
                settings.anthropic_url,
                json={"model": settings.model, "max_tokens": 1,
                      "messages": [{"role": "user", "content": "hi"}]},
                headers={"x-api-key": settings.anthropic_api_key,
                         "anthropic-version": settings.anthropic_version,
                         "content-type": "application/json"})
    except httpx.RequestError as exc:
        return {"ok": False, "reason": f"cannot reach Anthropic: {type(exc).__name__}"}
    if r.status_code >= 400:
        try:
            kind = r.json().get("error", {}).get("type", "")
        except Exception:
            kind = ""
        return {"ok": False, "upstream_status": r.status_code, "upstream_error": kind}
    return {"ok": True, "upstream_status": r.status_code}


def _cost(usage: dict) -> float:
    return (usage.get("input_tokens", 0) * PRICE_IN
            + usage.get("output_tokens", 0) * PRICE_OUT
            + usage.get("cache_read_input_tokens", 0) * PRICE_CACHE_READ) / 1e6


@app.post("/v1/reading")
async def reading(
    request: Request,
    x_device_id: str | None = Header(default=None),
    x_transaction: str | None = Header(default=None),
):
    if not x_device_id or len(x_device_id) < 8:
        raise HTTPException(400, "missing device identifier")
    device_id = x_device_id[:64]

    device = touch_device(device_id)
    if device["blocked"]:
        raise HTTPException(403, "This device has been blocked.")

    # --- who is this, and may they? -------------------------------------
    subscriber = False
    if x_transaction:
        try:
            verify_transaction(x_transaction)
            subscriber = True
        except ReceiptError as exc:
            # Not fatal: fall through to the free allowance rather than
            # locking out someone whose receipt is merely stale.
            log.info("transaction rejected for %s: %s", device_id[:8], exc)
    if subscriber != device["is_subscriber"]:
        set_subscriber(device_id, subscriber)

    consuming_free = not subscriber
    if consuming_free and device["free_used"] >= settings.free_readings:
        raise HTTPException(402, "Free readings used. Subscribe to continue.")

    # --- abuse limits ---------------------------------------------------
    if count_recent(device_id, 1) >= settings.rate_limit_per_hour:
        raise HTTPException(429, "Too many readings in the last hour.")
    if count_recent(device_id, 24) >= settings.rate_limit_per_day:
        raise HTTPException(429, "Daily reading limit reached.")

    # The backstop. One compromised device should not be able to spend more
    # than the whole service earns in a day.
    if spend_today() >= settings.daily_spend_cap_usd:
        log.error("daily spend cap hit — refusing readings")
        raise HTTPException(503, "Readings are paused. Please try again later.")

    if not settings.anthropic_api_key:
        log.error("ANTHROPIC_API_KEY is not set — cannot serve readings")
        raise HTTPException(503, "The reading service is not configured.")

    body = await request.json()
    modality = str(body.get("modality", ""))[:24]
    upstream = _build_upstream_request(body)

    async with httpx.AsyncClient(timeout=settings.upstream_timeout_s) as client:
        try:
            response = await client.post(
                settings.anthropic_url, json=upstream,
                headers={
                    "x-api-key": settings.anthropic_api_key,
                    "anthropic-version": settings.anthropic_version,
                    "content-type": "application/json",
                })
        except httpx.RequestError as exc:
            log.error("upstream unreachable: %s", exc)
            raise HTTPException(502, "The reading service is unreachable.")

    if response.status_code >= 400:
        detail = ""
        try:
            detail = response.json().get("error", {}).get("message", "")
        except Exception:
            pass
        log.error("upstream %s: %s", response.status_code, detail[:200])
        # Never surface upstream text to the client: it can leak request shape.
        raise HTTPException(502, "The reading could not be completed.")

    payload = response.json()
    usage = payload.get("usage", {}) or {}
    record_reading(device_id, modality, usage, _cost(usage), consuming_free)

    remaining = (None if subscriber
                 else max(0, settings.free_readings - device["free_used"] - 1))
    return JSONResponse({
        "content": payload.get("content", []),
        "stop_reason": payload.get("stop_reason"),
        "free_remaining": remaining,
        "subscribed": subscriber,
    })


def _build_upstream_request(body: dict) -> dict:
    """Assemble the upstream call from the client's request.

    The model, the token ceiling and the API key are decided here, not by the
    caller — otherwise a valid device could ask for an expensive model and the
    spend cap would be the only thing standing in the way.
    """
    system = body.get("system")
    messages = body.get("messages")
    if not isinstance(messages, list) or not messages:
        raise HTTPException(400, "malformed request")

    upstream: dict = {
        "model": settings.model,
        "max_tokens": min(int(body.get("max_tokens") or settings.max_output_tokens),
                          settings.max_output_tokens),
        "messages": messages,
    }
    if system:
        # Cache the system block: it is identical for every reading of a
        # modality and is most of the non-image input.
        upstream["system"] = ([{"type": "text", "text": system,
                                "cache_control": {"type": "ephemeral"}}]
                              if isinstance(system, str) else system)
    output_config = body.get("output_config") or {}
    # `effort` is rejected by Haiku, and the model is pinned to Haiku here.
    output_config.pop("effort", None)
    if output_config:
        upstream["output_config"] = output_config
    return upstream


@app.get("/v1/status")
def status(x_device_id: str | None = Header(default=None)):
    """Lets the app show an accurate free count without taking a reading."""
    if not x_device_id:
        raise HTTPException(400, "missing device identifier")
    device = touch_device(x_device_id[:64])
    return {
        "free_remaining": max(0, settings.free_readings - device["free_used"]),
        "subscribed": device["is_subscriber"],
        "blocked": device["blocked"],
    }
