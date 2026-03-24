# Security Policy

## Reporting vulnerabilities

If you find a security vulnerability:

1. Do not publish it in a public issue with exploitable details.
2. Share a minimal impact description and technical context responsibly with
   maintainers.
3. Include reproduction steps and affected version when possible.

## Scope

This policy applies to:

- Application source code
- Dependencies declared in `pubspec.yaml`
- CI configuration and related workflows

## Security best practices for contributors

- Do not commit secrets, tokens, or personal data.
- Avoid including temporary/build artifacts in PRs.
- Keep dependencies up to date and review advisories.
- Run `flutter analyze` and `flutter test` before opening a PR.
