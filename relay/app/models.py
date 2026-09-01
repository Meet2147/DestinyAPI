"""Persistence: who has used what, and how much has been spent."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import (Boolean, Column, DateTime, Float, Integer, MetaData,
                        String, Table, create_engine, func, insert, select,
                        update)

from app.config import settings

metadata = MetaData()

devices = Table(
    "devices", metadata,
    Column("device_id", String(64), primary_key=True),
    Column("free_used", Integer, default=0, nullable=False),
    Column("is_subscriber", Boolean, default=False, nullable=False),
    Column("first_seen", DateTime, default=lambda: datetime.now(timezone.utc)),
    Column("last_seen", DateTime),
    Column("blocked", Boolean, default=False, nullable=False),
)

# One row per reading. Rate limits and the spend cap are both derived from
# this, so there is a single source of truth for what has actually happened.
readings = Table(
    "readings", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("device_id", String(64), index=True, nullable=False),
    Column("modality", String(24)),
    Column("created_at", DateTime, default=lambda: datetime.now(timezone.utc),
           index=True),
    Column("input_tokens", Integer, default=0),
    Column("output_tokens", Integer, default=0),
    Column("cache_read_tokens", Integer, default=0),
    Column("cost_usd", Float, default=0.0),
)

_url = settings.database_url
if _url.startswith("postgres://"):
    _url = "postgresql+psycopg://" + _url[len("postgres://"):]
elif _url.startswith("postgresql://"):
    _url = "postgresql+psycopg://" + _url[len("postgresql://"):]

engine = create_engine(
    _url, future=True, pool_pre_ping=True,
    connect_args={"check_same_thread": False} if _url.startswith("sqlite") else {},
)


def init_db() -> None:
    metadata.create_all(engine)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def touch_device(device_id: str) -> dict:
    with engine.begin() as cx:
        row = cx.execute(
            select(devices).where(devices.c.device_id == device_id)).first()
        if row is None:
            cx.execute(insert(devices).values(
                device_id=device_id, free_used=0, is_subscriber=False,
                first_seen=_now(), last_seen=_now(), blocked=False))
            return {"device_id": device_id, "free_used": 0,
                    "is_subscriber": False, "blocked": False}
        cx.execute(update(devices).where(devices.c.device_id == device_id)
                   .values(last_seen=_now()))
        return {"device_id": row.device_id, "free_used": row.free_used,
                "is_subscriber": row.is_subscriber, "blocked": row.blocked}


def set_subscriber(device_id: str, value: bool) -> None:
    with engine.begin() as cx:
        cx.execute(update(devices).where(devices.c.device_id == device_id)
                   .values(is_subscriber=value))


def count_recent(device_id: str, hours: int) -> int:
    since = _now() - timedelta(hours=hours)
    with engine.begin() as cx:
        return cx.execute(
            select(func.count()).select_from(readings)
            .where(readings.c.device_id == device_id,
                   readings.c.created_at >= since)).scalar_one()


def spend_today() -> float:
    since = _now() - timedelta(hours=24)
    with engine.begin() as cx:
        total = cx.execute(
            select(func.coalesce(func.sum(readings.c.cost_usd), 0.0))
            .where(readings.c.created_at >= since)).scalar_one()
    return float(total)


def record_reading(device_id: str, modality: str, usage: dict,
                   cost: float, consumed_free: bool) -> None:
    with engine.begin() as cx:
        cx.execute(insert(readings).values(
            device_id=device_id, modality=modality, created_at=_now(),
            input_tokens=usage.get("input_tokens", 0),
            output_tokens=usage.get("output_tokens", 0),
            cache_read_tokens=usage.get("cache_read_input_tokens", 0),
            cost_usd=cost))
        if consumed_free:
            cx.execute(
                update(devices).where(devices.c.device_id == device_id)
                .values(free_used=devices.c.free_used + 1))
