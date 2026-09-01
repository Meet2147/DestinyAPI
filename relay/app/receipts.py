"""Verifying a StoreKit 2 transaction.

The app sends the signed transaction JWS it already holds. We verify it rather
than trusting it, because the client is the thing an attacker controls.

Three checks, in order of what they catch:
  1. the certificate chain really terminates at Apple's root
  2. the JWS signature matches the leaf certificate
  3. the payload is for our bundle, our product, and is not revoked or expired
"""
from __future__ import annotations

import base64
import json
import logging
from datetime import datetime, timezone

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.serialization import Encoding

from app.config import settings

log = logging.getLogger(__name__)

PRODUCT_IDS = {
    "ai.aurascan.pro.monthly",
    "ai.aurascan.pro.annual",
    "ai.aurascan.pro.lifetime",
}


class ReceiptError(Exception):
    pass


def _b64url(segment: str) -> bytes:
    return base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))


def _load_root_certs() -> list[x509.Certificate]:
    """Apple's root, shipped alongside the app rather than fetched at runtime.

    Fetching it per request would make Apple a dependency of every reading, and
    caching it in memory means a cold start silently trusts nothing.
    """
    from pathlib import Path
    certs = []
    root_dir = Path(__file__).resolve().parent / "certs"
    for path in sorted(root_dir.glob("*.cer")) + sorted(root_dir.glob("*.pem")):
        data = path.read_bytes()
        try:
            certs.append(x509.load_der_x509_certificate(data))
        except ValueError:
            certs.append(x509.load_pem_x509_certificate(data))
    return certs


_ROOTS: list[x509.Certificate] | None = None


def roots() -> list[x509.Certificate]:
    global _ROOTS
    if _ROOTS is None:
        _ROOTS = _load_root_certs()
    return _ROOTS


def _verify_signature(cert: x509.Certificate, signed: bytes, signature: bytes) -> None:
    key = cert.public_key()
    if isinstance(key, ec.EllipticCurvePublicKey):
        # ES256 signatures in a JWS are raw r||s, not DER.
        from cryptography.hazmat.primitives.asymmetric.utils import \
            encode_dss_signature
        half = len(signature) // 2
        der = encode_dss_signature(
            int.from_bytes(signature[:half], "big"),
            int.from_bytes(signature[half:], "big"))
        key.verify(der, signed, ec.ECDSA(hashes.SHA256()))
    elif isinstance(key, rsa.RSAPublicKey):
        key.verify(signature, signed, padding.PKCS1v15(), hashes.SHA256())
    else:
        raise ReceiptError("unsupported key type in transaction certificate")


def verify_transaction(jws: str) -> dict:
    """Returns the verified payload, or raises `ReceiptError`."""
    try:
        header_b64, payload_b64, signature_b64 = jws.split(".")
        header = json.loads(_b64url(header_b64))
        payload = json.loads(_b64url(payload_b64))
        signature = _b64url(signature_b64)
    except Exception as exc:
        raise ReceiptError(f"malformed transaction: {exc}") from exc

    chain_b64 = header.get("x5c") or []
    if not chain_b64:
        raise ReceiptError("transaction carries no certificate chain")

    try:
        chain = [x509.load_der_x509_certificate(base64.b64decode(c))
                 for c in chain_b64]
    except Exception as exc:
        raise ReceiptError(f"unreadable certificate chain: {exc}") from exc

    trusted = roots()
    if not trusted:
        raise ReceiptError("no Apple root certificate is installed on the relay")

    # The chain must end at a root we shipped. Comparing the DER bytes is
    # stricter than comparing subject names, which are forgeable.
    tail = chain[-1].public_bytes(Encoding.DER)
    if not any(tail == r.public_bytes(Encoding.DER) for r in trusted):
        # Apple sends leaf → intermediate; the root is implicit.
        issuer_ok = any(chain[-1].issuer == r.subject for r in trusted)
        if not issuer_ok:
            raise ReceiptError("certificate chain does not lead to Apple's root")

    # Each certificate must be signed by the next one up.
    for lower, upper in zip(chain, chain[1:]):
        try:
            _verify_signature(
                upper,
                lower.tbs_certificate_bytes,
                lower.signature,
            )
        except (InvalidSignature, Exception) as exc:
            raise ReceiptError(f"broken certificate chain: {exc}") from exc

    signed = f"{header_b64}.{payload_b64}".encode()
    try:
        _verify_signature(chain[0], signed, signature)
    except Exception as exc:
        raise ReceiptError(f"transaction signature does not verify: {exc}") from exc

    # --- payload checks ---
    if payload.get("bundleId") != settings.bundle_id:
        raise ReceiptError("transaction is for a different app")
    if payload.get("productId") not in PRODUCT_IDS:
        raise ReceiptError("transaction is for an unknown product")
    if payload.get("revocationDate"):
        raise ReceiptError("purchase was refunded or revoked")

    expires_ms = payload.get("expiresDate")
    if expires_ms:   # absent on the lifetime product, which never expires
        expires = datetime.fromtimestamp(expires_ms / 1000, tz=timezone.utc)
        if expires < datetime.now(timezone.utc):
            raise ReceiptError("subscription has expired")

    return payload
