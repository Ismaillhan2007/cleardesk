# Contributing to ClearDesk

Thank you for your interest in contributing to **ClearDesk**!

## Development Principles
Before opening a pull request, please read:
- [AGENTS.md](AGENTS.md) — Repo layout and non-negotiable safety rules.
- [docs/STACK_AND_PRINCIPLES.md](docs/STACK_AND_PRINCIPLES.md) — Swift 6, Apple HIG design standards, and zero-dependency policy.
- [docs/SECURITY.md](docs/SECURITY.md) — Filesystem boundary and privacy invariants.

## Local Setup

```bash
git clone https://github.com/Ismaillhan2007/cleardesk.git
cd cleardesk

# Enable the local pre-commit secret & .env guard
git config core.hooksPath .githooks

# Run all unit and security tests
swift test
```

## Pull Request Checklist
- [ ] Zero third-party dependencies added.
- [ ] All filesystem operations pass through `PathGuard`.
- [ ] No personal paths, `.env` files, or secrets anywhere in the diff.
- [ ] `swift test` passes with zero errors.
- [ ] UI changes follow native macOS Human Interface Guidelines (clean, minimal, no clutter).
