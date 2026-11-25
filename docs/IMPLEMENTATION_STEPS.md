# Implementation Steps & Milestones

This document tracks the step-by-step engineering plan for **ClearDesk** so any human or AI agent can see what is built, what is verified, and what comes next.

---

## Phase 1: Foundation, Docs & Security Guardrails
- [x] Create project structure (`ClearDeskCore`, `ClearDeskApp`, `ClearDeskCoreTests`).
- [x] Author `AGENTS.md`, `docs/STACK_AND_PRINCIPLES.md`, `docs/SECURITY.md`, and `docs/IMPLEMENTATION_STEPS.md`.
- [x] Configure strict `.gitignore`, safe `.env.example`, and automated `.githooks/pre-commit` secret scanner.

## Phase 2: Core Engine & Cybersecurity Layer (`ClearDeskCore`)
- [x] `DeskItem` model (Desktop vs Vault location, file kind, pinned state, settling state, macOS package detection).
- [x] `PathGuard` security module (root containment checks, traversal rejection, symlink safety, temporary & `.icloud` stub filtering).
- [x] `TransactionLog` (atomic `0600` append-only audit log for sweep batches & 1-click Undo).
- [x] `FileVaultEngine` (collision-safe atomic sweeps, single-item move/restore, pin persistence, batch undo).
- [x] `DesktopWatcher` (macOS `FSEvents` real-time observer with 2-second stability debounce).

## Phase 3: Native macOS SwiftUI Application (`ClearDeskApp`)
- [x] `ClearDeskViewModel` bridging `DesktopWatcher` and `FileVaultEngine` on `@MainActor`.
- [x] `SidebarView` (Apple HIG translucent `NavigationSplitView` sidebar: Locations, Kinds, Auto-Sweep toggle).
- [x] `FileGridView` (spacious Finder-style icon grid with real `NSWorkspace` icons, double-click open, right-click native context menu, Spacebar Quick Look).
- [x] `QuickLookHelper` (native `Quartz.QuickLookUI` `QLPreviewPanel` integration).
- [x] `ClearDeskApp` entry point with unified toolbar, `.searchable`, **Sweep Desktop** button, Undo toast, and quiet `MenuBarExtra`.

## Phase 4: Automated Verification & Public GitHub Setup
- [x] Unit tests in `ClearDeskCoreTests` covering path traversal attacks, symlink containment, `.icloud`/temp file skipping, collision-safe renames, pinned item protection, and full sweep/undo round-trips.
- [x] `swift build` and `swift test` passing cleanly on macOS.
- [x] Git initialization, pre-commit hook activation, and push to public GitHub repository.

## Phase 5: Next Enhancements (Post-MVP)
- [ ] Bundle as a signed `.app` with Hardened Runtime and custom macOS AppIcon.
- [ ] Optional Launch-at-Login (`SMAppService`) toggle.
- [ ] Optional dated sweep groupings (e.g., *Today*, *This Week*) inside Vault.
- [ ] Keyboard shortcuts (`⌘⇧S` global hotkey to sweep Desktop, `⌘Z` to undo last sweep).
