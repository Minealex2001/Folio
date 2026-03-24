# Repository security setup (GitHub)

Practical guide to harden the repository and protect collaboration.

## 1) Branch protection on `main`

In `Settings -> Branches -> Add rule`:

- Branch name pattern: `main`
- Require a pull request before merging
- Require approvals: 1 or more
- Dismiss stale pull request approvals when new commits are pushed
- Require status checks to pass before merging
- Require conversation resolution before merging
- Restrict pushes to matching branches (optional, based on your team model)
- Include administrators (recommended)

## 2) Merge rules

In `Settings -> General` (Pull Requests):

- Allow only merge methods you want to use (squash is recommended)
- Optional: disable merge commits for a cleaner history

## 3) Secret scanning and push protection

In `Settings -> Security`:

- Enable Secret scanning
- Enable Push protection to block secrets before push

## 4) Dependabot alerts and updates

In `Settings -> Security`:

- Enable Dependabot alerts
- Enable Dependabot security updates

Optionally add `dependabot.yml` for scheduled updates.

## 5) Code scanning (CodeQL)

In the `Security` tab:

- Configure Code scanning with a GitHub Actions workflow
- Run it at least on `push` and `pull_request` for `main`

## 6) Minimum GitHub Actions permissions

In `Settings -> Actions -> General`:

- Workflow permissions: `Read repository contents permission`
- Enable `Allow GitHub Actions to create and approve pull requests` only if
  needed for internal bots

## 7) Require checks on PRs

Configure required checks in branch protection:

- `flutter analyze`
- `flutter test`
- (optional) `codeql`

## 8) Secret management

- Store secrets only in `Settings -> Secrets and variables`
- Do not use plaintext secrets in code
- Rotate secrets if they are exposed

## 9) Policy for external contributors

- Require PRs from forks (no direct pushes to `main`)
- Review write/admin permissions periodically
- Use risk labels on sensitive PRs (`security`, `infra`, etc.)

## Quick hardening checklist

- [ ] Branch protection enabled on `main`
- [ ] Approval required for merge
- [ ] Required status checks enabled
- [ ] Secret scanning + push protection enabled
- [ ] Dependabot alerts and updates enabled
- [ ] Code scanning enabled
- [ ] Actions permissions set to least privilege
