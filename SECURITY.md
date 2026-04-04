# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.6.x   | Yes                |
| < 0.6   | No                 |

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

- Issues in upstream dependencies (GSD, Superpowers, Engineering, Design plugins)
- Claude Code platform vulnerabilities (report to Anthropic directly)
- Issues requiring physical access to the machine

## Acknowledgments

We appreciate responsible disclosure and will credit reporters in release notes (unless anonymity is requested).
