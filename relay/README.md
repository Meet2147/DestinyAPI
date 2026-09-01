# AuraScan relay

Holds the Anthropic API key so the iOS app does not have to, and decides who
may take a reading.

A key shipped inside an `.ipa` can be extracted by anyone who downloads the
app. Everything else here exists because the client cannot be trusted.

## What it enforces

| Gate | Why |
|---|---|
| **Model is pinned** to `claude-haiku-4-5` | A caller cannot request an expensive model. Spend is our decision. |
| **`max_tokens` capped** at 8,000 | An unbounded output is an unbounded bill. |
| **`effort` stripped** | Haiku rejects it, and rejects the whole request with it. |
| **7 free readings per device**, server-side | The client's own count can be reset by reinstalling. |
| **20/hour, 60/day per device** | No human takes twenty readings an hour. |
| **$50/day global spend cap** | The backstop. If it trips, something is wrong and stopping is cheaper than finding out how wrong. |
| **StoreKit transactions verified** | The signature chain is checked against Apple's root, then the bundle id, product, revocation and expiry. |

All of it is covered by `test_relay.py`, which stubs the upstream so the tests
cost nothing.

```bash
python -m venv .venv && ./.venv/bin/pip install -r requirements.txt
./.venv/bin/python test_relay.py
```

## Before deploying

1. **Install Apple's root certificate** — see `app/certs/README.md`. Without it
   the relay cannot verify a subscription and treats every user as free-tier.
2. Set `ANTHROPIC_API_KEY` in the Render dashboard.
3. Point the app's `RELAY_URL` at the deployed service.

## Running locally

```bash
cp .env.example .env      # add your key
ALLOW_UNVERIFIED_DEVICES=true ./.venv/bin/uvicorn app.main:app --reload
```

## Known limits

The client still composes the prompt, so a caller holding a valid entitlement
could use the relay as a general Claude proxy — bounded by their own rate limit
and the global cap, but not prevented. Moving the prompt and schema server-side
would close that, at the cost of duplicating them out of the Swift source.
Worth doing once the prompts settle.
