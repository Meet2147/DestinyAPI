# Apple root certificate

Drop `AppleIncRootCertificate.cer` here — it is what StoreKit transaction
signatures are checked against. Without it the relay refuses every
subscription rather than trusting one it cannot verify.

    curl -o AppleIncRootCertificate.cer \
      https://www.apple.com/appleca/AppleIncRootCertificate.cer

`.cer` (DER) and `.pem` are both accepted. The file is ~1 KB and safe to
commit: it is a public root certificate, not a secret.
