# ClearDesk

**A clean, native macOS app that keeps your Desktop spotless while keeping every file and folder one click away.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![100% Offline](https://img.shields.io/badge/Network-100%25%20Offline-brightgreen)
![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-brightgreen)

---

## Why ClearDesk?

Most people drop screenshots, folders, and PDFs onto their Desktop and end up with visual clutter—yet moving them away makes them hard to find (especially with Finder's slow search).

**ClearDesk** solves this cleanly using **Live Mirror + Atomic Vault**:
- **Live Mirror (`~/Desktop`):** Watches your Desktop in real time via macOS `FSEvents` with a 2-second stability debounce so newly created folders and in-progress downloads are never interrupted.
- **Instant Atomic Sweep (`~/DesktopVault`):** Click **Sweep Desktop** (or enable **Auto-Sweep**) to move unpinned Desktop items into `~/DesktopVault` in under 1 ms using APFS atomic renames—zero disk space duplicated.
- **Fast Ranked Search (`⌘F`):** Searches both top-level and nested files/folders across Desktop and Vault with exact, prefix, word-boundary, multi-word token, and fuzzy matching.
- **Native macOS Experience:** Built in pure SwiftUI + AppKit/QuickLookUI—translucent sidebar, real Finder icons, double-click to open, **Spacebar** for Quick Look, right-click context menus, and a quiet Menu Bar companion.
- **Pin & 1-Click Undo:** Pin active folders so they stay on Desktop during sweeps, restore any vaulted file back to Desktop anytime, or undo an entire sweep in one click.

---

## Security & Trust

ClearDesk is **open-source under the MIT License** so anyone can inspect every line of code before building it:
- **100% Offline:** Zero network requests, zero analytics, zero telemetry.
- **Zero Third-Party Packages:** Uses only native Apple macOS frameworks (`Foundation`, `SwiftUI`, `AppKit`, `CoreServices`, `Quartz`).
- **Strict Boundary Guard (`PathGuard`):** Enforces canonical containment inside `~/Desktop` and `~/DesktopVault`, blocks path traversal and symlink escapes, skips temporary downloads and `.icloud` stubs, and never silently overwrites existing files.
- **Owner-Only Permissions:** Vault and local metadata use `0700` / `0600` POSIX permissions.

Read [SECURITY.md](SECURITY.md) and [docs/SECURITY.md](docs/SECURITY.md) for the full security model.

---

## Install on Your Mac

### Option 1: Direct Download (`.dmg` Installer)
1. Download **`ClearDesk-1.0.0.dmg`** from the **[Latest Release](https://github.com/Ismaillhan2007/cleardesk/releases/latest)**.
2. Open the `.dmg` and drag **ClearDesk** into **Applications**.
3. Launch **ClearDesk** from **Spotlight (`⌘Space` → ClearDesk)** or **Applications**.

> **First-Launch Note (Ad-Hoc Signed Open-Source Build):** Because this indie open-source release is ad-hoc signed rather than Apple-notarized, macOS Gatekeeper may ask you to confirm on first launch. Open **Applications**, **right-click ClearDesk → Open**, or run `xattr -cr /Applications/ClearDesk.app`. You can also verify the download with `shasum -a 256 -c ClearDesk-1.0.0.dmg.sha256`, or build directly from source below.

### Option 2: Build From Source
**Requirements:** macOS 14.0+ (Sonoma/Sequoia) and Xcode Command Line Tools (`xcode-select --install`).

```bash
# 1. Clone the repository
git clone https://github.com/Ismaillhan2007/cleardesk.git
cd cleardesk

# 2. Build ClearDesk.app (or ./scripts/build_dmg.sh 1.0.0 for a .dmg)
./scripts/build_app.sh

# 3. Install to Applications and launch
cp -R dist/ClearDesk.app /Applications/
open /Applications/ClearDesk.app
```

> **Desktop Permission:** On first launch, macOS will prompt *"ClearDesk would like to access files in your Desktop folder."* Click **Allow** so live Desktop syncing and sweeping work.

---

## Development & Testing

```bash
# Enable the local pre-commit secret & .env guard
git config core.hooksPath .githooks

# Run all core engine, search, and security unit tests
swift test
```

## Documentation
- **[AGENTS.md](AGENTS.md)** — Architecture map and engineering rules.
- **[docs/STACK_AND_PRINCIPLES.md](docs/STACK_AND_PRINCIPLES.md)** — Tech stack, Apple HIG rules, and coding principles.
- **[docs/SECURITY.md](docs/SECURITY.md)** — Cybersecurity protection layers and `.env` hardening.
- **[docs/IMPLEMENTATION_STEPS.md](docs/IMPLEMENTATION_STEPS.md)** — Implementation milestones and roadmap.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — How to contribute.

## License
Released under the [MIT License](LICENSE).
