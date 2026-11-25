# ClearDesk — Agent Instructions (`AGENTS.md`)

This document is the authoritative entry point for any AI coding agent or contributor working on **ClearDesk**, a native macOS app that keeps `~/Desktop` spotless while preserving instant, zero-copy access to every file and folder.

Read the companion docs before making changes:
- [docs/STACK_AND_PRINCIPLES.md](docs/STACK_AND_PRINCIPLES.md) — Approved stack, Apple HIG rules, and software engineering principles.
- [docs/SECURITY.md](docs/SECURITY.md) — Mandatory cybersecurity layers, `.env` hardening, and filesystem safety invariants.
- [docs/IMPLEMENTATION_STEPS.md](docs/IMPLEMENTATION_STEPS.md) — Phased implementation roadmap and verification checklist.

---

## 1. What We Are Building

ClearDesk follows **Option 1: Live Mirror + Vault**:
1. **Live Mirror (`~/Desktop`):** Watches `~/Desktop` in real time using macOS `FSEvents` with a 2-second stability debounce so unfinished downloads or newly created `untitled folder` entries are never interrupted.
2. **Atomic Vault (`~/DesktopVault`):** Moves settled, unpinned items off `~/Desktop` into `~/DesktopVault` via same-volume APFS atomic `rename()` (< 1 ms, 0 bytes duplicated).
3. **1-Click Undo & Restore:** Every sweep is recorded in an append-only transaction log (`0600` permissions) so sweeps can be undone and individual items can be restored to `~/Desktop` anytime.
4. **Native Apple macOS UX:** Built in pure **SwiftUI + AppKit/QuickLookUI** following Apple's Human Interface Guidelines — translucent sidebar, unified toolbar, native Finder icons, Spacebar Quick Look, and right-click context menus. No cluttered web-style badges, no Grid/List toggles, and no redundant Trash UI.

---

## 2. Repository Layout

```text
cleardesk/
├── AGENTS.md                        # Agent entry point & strict rules
├── README.md                        # User-facing overview & setup
├── Package.swift                    # Swift 6 Package Manager manifest (macOS 14+)
├── .env.example                     # Safe config template (never commit real .env)
├── .gitignore                       # Strict secret, env, and build ignore rules
├── .githooks/
│   └── pre-commit                   # Automated secret & .env leak prevention hook
├── docs/
│   ├── STACK_AND_PRINCIPLES.md      # Stack rules & engineering standards
│   ├── SECURITY.md                  # Cybersecurity protection layers
│   └── IMPLEMENTATION_STEPS.md      # Documented build steps & milestones
├── Sources/
│   ├── ClearDeskCore/               # Pure, testable core engine (no SwiftUI)
│   │   ├── Models/DeskItem.swift
│   │   ├── Security/PathGuard.swift
│   │   ├── Storage/TransactionLog.swift
│   │   └── Engine/
│   │       ├── FileVaultEngine.swift
│   │       └── DesktopWatcher.swift
│   └── ClearDeskApp/                # Native macOS SwiftUI application
│       ├── ClearDeskApp.swift
│       ├── ViewModels/ClearDeskViewModel.swift
│       └── Views/
│           ├── SidebarView.swift
│           ├── FileGridView.swift
│           └── QuickLookHelper.swift
└── Tests/
    └── ClearDeskCoreTests/          # Unit & security boundary tests
```

---

## 3. Non-Negotiable Agent Rules

1. **Zero Data Loss Above All Else:**
   - Never silently overwrite an existing file or folder. Always resolve collisions with deterministic suffixes (`Name (2).ext`).
   - Never issue destructive deletes (`removeItem` on user data) during sweep or restore operations.
   - Always ignore temporary/incomplete files (`.DS_Store`, `.crdownload`, `.download`, `.part`, `.tmp`, `~$*`, `.icloud` stubs).
2. **Strict Boundary Enforcement (`PathGuard`):**
   - Every filesystem operation MUST pass through `PathGuard` to canonicalize paths, reject `..` traversal, and refuse symlink escapes outside the authorized Desktop and Vault roots.
3. **No Secret / `.env` Leaks:**
   - Never commit `.env`, `.env.local`, keys, tokens, or personal paths.
   - Keep `.githooks/pre-commit` enabled (`git config core.hooksPath .githooks`).
4. **Native macOS Design Discipline:**
   - Keep UI minimal and faithful to macOS HIG. Do not add unnecessary toggles (no Grid/List toggle, no Trash tab, no verbose debug/telemetry banners in the main window).
5. **Architecture Separation:**
   - `ClearDeskCore` must remain UI-agnostic (`Foundation`, `CoreServices`) and 100% unit-testable in isolated temporary directories.
   - `ClearDeskApp` handles SwiftUI presentation, `NSWorkspace`, and `QuickLookUI`.

---

## 4. Build, Test, and Run Commands

```bash
# Enable local security pre-commit hook
git config core.hooksPath .githooks

# Build everything
swift build

# Run all unit & security tests
swift test

# Run the native macOS app
swift run ClearDeskApp
```
