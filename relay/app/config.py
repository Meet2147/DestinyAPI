"""Relay configuration."""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- upstream ---
    anthropic_api_key: str = ""
    anthropic_url: str = "https://api.anthropic.com/v1/messages"
    anthropic_version: str = "2023-06-01"

    # The relay pins the model. A client cannot ask for a more expensive one:
    # the whole point of holding the key here is that spend is our decision.
    model: str = "claude-haiku-4-5"
    max_output_tokens: int = 8_000
    upstream_timeout_s: float = 240.0

    # --- entitlement ---
    free_readings: int = 7
    bundle_id: str = "ai.aurascan.app"
    # Apple's App Store Server API root, used to verify StoreKit transactions.
    apple_root_ca_urls: str = (
        "https://www.apple.com/appleca/AppleIncRootCertificate.cer"
    )

    # --- abuse limits ---
    # A device that cannot possibly be a human taking readings.
    rate_limit_per_hour: int = 20
    rate_limit_per_day: int = 60
    # Hard ceiling across every user. If this trips, something is wrong and
    # stopping is cheaper than finding out how wrong.
    daily_spend_cap_usd: float = 50.0
    # Measured: Haiku 4.5 with caching, one reading.
    assumed_cost_per_reading_usd: float = 0.0092

    # --- storage ---
    database_url: str = "sqlite:///./relay.db"

    # Lets you run the relay locally without StoreKit.
    allow_unverified_devices: bool = False


settings = Settings()
