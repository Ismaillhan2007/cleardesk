# Tech Stack & Software Engineering Principles

This document defines the approved technology stack, Apple macOS design standards, and coding principles for **ClearDesk**.

---

## 1. Approved Technology Stack

| Layer | Technology | Why |
| :--- | :--- | :--- |
| **Language** | **Swift 6** (Strict Concurrency) | Native macOS performance, memory safety, compile-time data-race checking. |
| **UI Framework** | **SwiftUI + AppKit / QuickLookUI** | Authentic macOS vibrancy, SF Symbols, unified toolbars, `NSWorkspace` icons, Spacebar `QLPreviewPanel`, and minimal RAM (~30 MB). |
| **Filesystem Watching** | **macOS `FSEvents` (`CoreServices`)** | Event-driven OS notifications with ~0% idle CPU usage (never polling). |
| **File Operations** | **APFS Same-Volume Atomic `rename()`** via `FileManager` | Sub-millisecond moves regardless of folder size, 0 bytes duplicated. |
| **Persistence / Undo Log** | **Append-Only Atomic JSONL / Local Metadata** (`0600` permissions) | Crash-safe audit trail for 1-click Undo and pinned-item state without external DB bloat. |
| **Build & Test** | **Swift Package Manager (`Package.swift`)** | Zero third-party dependencies, fast CLI builds (`swift build`), deterministic unit tests (`swift test`). |
| **Target OS** | **macOS 14.0+ (Sonoma / Sequoia)** | Modern SwiftUI `NavigationSplitView`, `@Observable`, and `MenuBarExtra`. |

### Zero Third-Party Dependency Policy
ClearDesk intentionally uses **zero third-party packages**. A personal filesystem utility with access to `~/Desktop` should have the smallest possible supply-chain attack surface.

---

## 2. Apple Human Interface Guidelines (HIG) Rules

ClearDesk must look and feel like an app built by Apple:
- **Calm, uncluttered chrome:** Translucent `NavigationSplitView` sidebar, unified toolbar with a native `.searchable` field and one primary **Sweep Desktop** action.
- **No unnecessary controls:** Do not add Grid/List toggles, Trash views, redundant status badges, or decorative cards.
- **Native macOS idioms:**
  - Single-click selects an item.
  - Double-click opens it in its default macOS app (`NSWorkspace.shared.open`).
  - **Spacebar** opens native macOS Quick Look (`QLPreviewPanel`).
  - **Right-click** opens a native `.contextMenu` (*Open*, *Quick Look*, *Move to Vault* / *Restore to Desktop*, *Pin to Desktop*).
- **Quiet Menu Bar presence:** A lightweight `MenuBarExtra` shows Desktop status and allows a 1-click sweep without opening the main window.

---

## 3. Software Engineering Principles

1. **Core / UI Isolation:**
   - All filesystem logic, security checks, debouncing, and transaction logging live in `ClearDeskCore`.
   - Never call `FileManager.default.moveItem` directly from a SwiftUI `View`.
2. **Idempotency & Atomicity:**
   - Every move validates source and destination through `PathGuard` before touching disk.
   - Collisions are resolved deterministically (`Invoices (2)`), never overwritten.
3. **Debounce Before Acting:**
   - Wait for a stability window (default 2.0 s) after `FSEvents` fires before marking newly created items as sweep-ready.
4. **Explicit Error Handling:**
   - Never use `try!` or force-unwraps (`!`) on filesystem paths or user data.
   - Surface actionable, calm error messages to the user if macOS permissions or disk space prevent an operation.
5. **Test-First for Safety Invariants:**
   - Every security check, collision rule, pin exclusion, and undo flow must have automated tests in `Tests/ClearDeskCoreTests` running inside ephemeral temporary directories (never touching the developer's real `~/Desktop`).
