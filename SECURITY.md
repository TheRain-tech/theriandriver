# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability or exposed credentials in this repository, please **do not report it in public issues**. Instead, use the private vulnerability reporting mechanism available on GitHub, or coordinate with the platform owners directly.

## Key Security Practices

1. **Exposed Credentials:** If credentials are accidentally committed or exposed, they must be **revoked and rotated immediately** in the respective provider console (e.g., Google Cloud, Firebase, Railway, WhatsApp, PayUnit).
2. **Ignored Files:** Do not commit or push `.env` files, Firebase service account keys, mobile signing keystores, or private keys. Ensure they are covered by `.gitignore` rules.
3. **Firebase Credentials:** Firebase Admin SDK service account credentials contain full administrative access to Firebase services. They must **never** be compiled or included in mobile client applications (such as Flutter apps) or web client bundles.
4. **Central Security Reports:** Phase 0 central audit findings, rotation checklists, and inventories are hosted in the `therainAdmin` repository under `docs/platform/phase-0/`.
