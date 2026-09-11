# Security Policy & Repository Security Setup

This document describes Folio's security policy, reporting guidelines, and GitHub repository hardening standards.

---

## 1. Reporting Vulnerabilities

If you discover a security vulnerability:

1. **Do not create a public GitHub issue** with exploitable details.
2. Share a minimal impact description and technical context responsibly with maintainers.
3. Include reproduction steps and affected version when possible.

### Policy Scope

This policy applies to:
- Application source code and local cryptographic logic
- Dependencies declared in `pubspec.yaml`
- Firebase Cloud Functions and backend API services
- CI/CD configurations and GitHub Actions workflows

---

## 2. Security Best Practices for Contributors

- **Zero Secret Ingestion**: Do not commit secrets, private keys, tokens, or credentials to Git. Use environment variables and local `.env` files (which are gitignored).
- **Sanitize Contributions**: Avoid staging temporary files, build artifacts (`build/`, `.dart_tool/`), or local log files.
- **Dependency Hygiene**: Keep dependencies up to date and review advisories.
- **Pre-PR Validation**: Run static analysis (`flutter analyze`) and tests (`flutter test`) before opening a pull request.

---

## 3. GitHub Repository Hardening Configuration

Guidelines for repository administrators to protect `main` and automated pipelines:

### Branch Protection (`main`)
In GitHub `Settings -> Branches -> Add rule`:
- Target branch pattern: `main`
- Require a pull request before merging (minimum 1 approval)
- Dismiss stale pull request approvals when new commits are pushed
- Require status checks to pass before merging (`flutter analyze`, `flutter test`)
- Require conversation resolution before merging
- Include administrators

### Secret Scanning & Push Protection
In `Settings -> Security`:
- Enable **Secret scanning**
- Enable **Push protection** to block commits containing sensitive strings prior to push

### Automated Vulnerability Tracking (Dependabot)
In `Settings -> Security`:
- Enable **Dependabot alerts**
- Enable **Dependabot security updates**

### Static Code Scanning (CodeQL)
Configure CodeQL workflow in GitHub Actions to run on `push` and `pull_request` against `main`.

### Actions Least-Privilege Permissions
In `Settings -> Actions -> General`:
- Default workflow permissions set to `Read repository contents permission`.
- Restrict write/admin permissions to required bots only.

---

## Checklist for Maintainers

- [x] Branch protection rule enabled on `main`
- [x] Required status checks configured (`flutter analyze`, `flutter test`)
- [x] Secret scanning and Push protection enabled
- [x] Dependabot security updates enabled
- [x] Least-privilege Actions permissions enforced
