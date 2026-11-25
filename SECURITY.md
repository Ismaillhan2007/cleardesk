# Security Policy

## Security & Privacy Guarantees

**ClearDesk** is designed from the ground up to be transparent, auditable, and safe for personal files:

- **100% Offline:** Zero outbound network connections, zero analytics, zero telemetry, and no network libraries imported.
- **Zero Third-Party Dependencies:** Built exclusively on Apple system frameworks (`Foundation`, `SwiftUI`, `AppKit`, `CoreServices`, `Quartz`, `UniformTypeIdentifiers`).
- **Strict Filesystem Boundaries (`PathGuard`):** Every file operation is canonicalized and verified to stay strictly within `~/Desktop` and `~/DesktopVault`. Path traversal (`..`), invalid filenames, and symlink escapes outside authorized roots are blocked.
- **Zero Data Loss Design:** Files are never silently overwritten (collisions are safely suffixed, e.g., `Notes (2).txt`), transient downloads (`.crdownload`, `.part`, `.tmp`) and `.icloud` placeholders are skipped, and sweeps are recorded in an owner-only (`0600`) log for 1-click Undo.
- **Owner-Only Local Permissions:** `~/DesktopVault` and app metadata directories enforce `0700` permissions; state and transaction logs enforce `0600`.

For full architectural details, see [docs/SECURITY.md](docs/SECURITY.md).

## Supported Versions

| Version | Supported |
| :--- | :--- |
| `1.x` (macOS 14.0+) | Yes |

## Reporting a Vulnerability

If you discover a security issue (such as a path-boundary bypass, symlink handling flaw, or data-loss edge case):

1. Please **do not** open a public issue with exploit details.
2. Use GitHub's **Private Vulnerability Reporting** (Security tab → *Report a vulnerability*) on this repository.
3. Include clear reproduction steps and expected vs. actual behavior.
