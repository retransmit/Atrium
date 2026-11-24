# Security policy

## Supported versions

Only the latest release is supported. Please check that an issue still
happens on it before reporting.

## Reporting a vulnerability

Please report security issues privately - do **not** open a public issue.

Use GitHub's private reporting form:
[Report a vulnerability](https://github.com/retransmit/Atrium/security/advisories/new)
(also under the repository's **Security** tab). Only the maintainers can
see what you send there.

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
