# Security policy

## Supported versions

Atrium is pre-1.0. Only the latest commit on `main` is supported.

## Reporting a vulnerability

Please report security issues privately - do **not** open a public issue.

- Email: see the maintainer's GitHub profile.
- Or use GitHub's "Report a vulnerability" private disclosure flow on the
  repository.

Please include:

- Affected version / commit
- A clear description of the issue and its impact
- Reproduction steps or a proof of concept
- Any suggested mitigation

We aim to acknowledge within 72 hours and to land a fix or workaround
within 30 days for high-severity issues.

## Threat model

Atrium stores API keys for self-hosted services (Sonarr, Radarr, qBit,
etc.) in the Android Keystore via `flutter_secure_storage`. Optional
biometric unlock can gate access. Non-secret configuration lives in
plain Hive boxes excluded from Android auto-backup.

We are not in scope for:

- Compromise of the upstream services themselves (report those upstream)
- Attacks requiring an already-rooted device with debug access
- Vulnerabilities in third-party plugins not maintained by this project
