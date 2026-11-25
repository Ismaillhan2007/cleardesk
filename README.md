# ClearDesk

A lightweight, native macOS SwiftUI app that keeps your `~/Desktop` spotless while giving you instant, Finder-like access to every file and folder.

## How It Works
- **Live Mirror (`~/Desktop`):** Watches your Desktop in real time via macOS `FSEvents` with a 2-second stability debounce so newly created folders and active downloads are never interrupted.
- **Instant Vault (`~/DesktopVault`):** One click on **Sweep Desktop** (or optional **Auto-Sweep**) atomically moves unpinned Desktop items into `~/DesktopVault` in milliseconds with zero disk duplication.
- **Native macOS Experience:** Translucent sidebar, unified toolbar, real Finder icons, double-click to open, **Spacebar** for native Quick Look, right-click context menus, and a quiet Menu Bar companion.
- **1-Click Undo & Restore:** Every sweep is logged atomically so you can undo an entire sweep or restore any folder back to your Desktop anytime.

## Quick Start

```bash
# 1. Enable the local pre-commit security hook
git config core.hooksPath .githooks

# 2. Build & run unit/security tests
swift test

# 3. Launch ClearDesk
swift run ClearDeskApp
```

> **macOS Permissions:** On first launch, macOS will prompt you to grant ClearDesk access to your **Desktop** folder.

## Documentation & Agent Guides
- **[AGENTS.md](AGENTS.md)** — Rules and architecture map for AI coding agents.
- **[docs/STACK_AND_PRINCIPLES.md](docs/STACK_AND_PRINCIPLES.md)** — Tech stack, Apple HIG rules, and engineering principles.
- **[docs/SECURITY.md](docs/SECURITY.md)** — Cybersecurity protection layers, `.env` hygiene, and filesystem safety invariants.
- **[docs/IMPLEMENTATION_STEPS.md](docs/IMPLEMENTATION_STEPS.md)** — Phased implementation plan and roadmap.
