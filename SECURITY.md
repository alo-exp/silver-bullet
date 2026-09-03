# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.52.x  | Yes                |
| < 0.52  | No                 |

## Reporting a Vulnerability

If you discover a security vulnerability in Silver Bullet, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email **security@alolabs.dev** with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 5 business days
- **Fix release**: As soon as practical, typically within 2 weeks for critical issues

## Scope

Silver Bullet's hooks execute shell commands as part of their enforcement logic. The following are in scope:

- Command injection through `.silver-bullet.json` configuration values
- Path traversal in hook scripts
- Unauthorized file access or modification by hooks
- Bypass of enforcement gates that could lead to unsafe deployments

The following are out of scope:

- Vulnerabilities in optional third-party extension plugins; report those to their maintainers
- Host-platform vulnerabilities in Claude Code, Codex, or Cursor; report those to the relevant platform vendor
- Issues requiring physical access to the machine

## Acknowledgments

We appreciate responsible disclosure and will credit reporters in release notes (unless anonymity is requested).
