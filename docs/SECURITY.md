# Cybersecurity & Data Protection Architecture (`SECURITY.md`)

Even though **ClearDesk** is a personal-use macOS app, it manages sensitive personal files on `~/Desktop` and lives in a **public GitHub repository**. Defense-in-depth is mandatory across both the **runtime app** and the **development / repository workflow**.

---

## 1. Environment & Secret Hygiene (`.env` Protection)

1. **Zero Secrets in Git:**
   - `.gitignore` explicitly excludes `.env`, `.env.*` (except `.env.example`), `*.pem`, `*.key`, `*.p12`, `*.mobileprovision`, and macOS `.DS_Store` files.
   - Only `.env.example` (containing non-sensitive placeholder documentation) may ever be committed.
2. **Strict File Permissions for Local `.env`:**
   - If a local `.env` file is used for developer overrides (e.g., custom test vault path), it MUST be created with owner-only permissions:
     ```bash
     chmod 600 .env
     ```
   - Never store credentials, API keys, or tokens in `.env` for ClearDesk—the app is 100% offline and requires zero cloud secrets.
3. **Automated Pre-Commit Secret Scanner (`.githooks/pre-commit`):**
   - Before every commit, the local pre-commit hook blocks:
     - Any staged `.env` or private key file.
     - High-risk secret patterns (GitHub tokens `ghp_`/`github_pat_`, AWS keys `AKIA`, private key headers `BEGIN PRIVATE KEY`, generic `API_KEY=`/`SECRET=` assignments).
   - Activate with: `git config core.hooksPath .githooks`.

---

## 2. Runtime Cybersecurity Protection Layers

### Layer 1: Strict Path Boundary & Symlink Escape Defense (`PathGuard`)
- **Threat:** A malicious or accidental symlink (`~/Desktop/link -> /etc` or `~/Desktop/../../Sensitive`) or path-traversal filename could trick a file manager into moving or exposing system files outside `~/Desktop` and `~/DesktopVault`.
- **Control:**
  - Every operation passes through `PathGuard`.
  - Paths are standardized and canonicalized (`standardizedFileURL`) and verified to sit strictly inside the allowed root directory (`desktopRoot` or `vaultRoot`).
  - Symlinks are **never followed recursively**; a symlink on Desktop is treated strictly as the link entry itself (or refused if it attempts boundary escape).
  - Control characters, null bytes (`\0`), and path separators inside item names are rejected.

### Layer 2: Atomic Operations & Zero-Overwrite Invariant
- **Threat:** Partial moves, race conditions, or filename collisions causing silent data loss.
- **Control:**
  - Same-volume moves use atomic filesystem renames.
  - Destinations are verified non-existent before moving; collisions automatically receive a safe numeric suffix (`Report (2).pdf`).
  - Temporary/incomplete files (`.crdownload`, `.download`, `.part`, `.tmp`, `~$*`) and iCloud Drive evicted stubs (`.icloud`) are strictly skipped so in-flight downloads or cloud placeholders are never corrupted.

### Layer 3: Restrictive POSIX File Permissions (`0700` / `0600`)
- **Threat:** Other local user accounts or unprivileged processes reading ClearDesk's vault metadata or transaction history.
- **Control:**
  - `~/DesktopVault` and ClearDesk's internal state directory (`~/Library/Application Support/ClearDesk`) are created with `0700` (owner read/write/execute only).
  - The transaction log (`transactions.jsonl`) and pinned-items config (`state.json`) are written atomically with `0600` (owner read/write only).

### Layer 4: Zero Network & Zero Supply-Chain Surface
- **Threat:** Exfiltration of private filenames/documents or compromised third-party dependencies.
- **Control:**
  - **No outbound network requests**—ClearDesk never phones home, never collects analytics, and never imports network SDKs.
  - **Zero third-party packages** in `Package.swift`.

### Layer 5: macOS OS-Level Protections (Distribution Readiness)
- When packaged as a `.app` bundle for daily use:
  - Enable **Hardened Runtime** (prevents dylib injection and memory tampering).
  - Rely on macOS **TCC (Transparency, Consent, and Control)** so the OS explicitly prompts the user to grant `Desktop Folder` access.
  - Never request Full Disk Access unless strictly required; operate with least privilege on `~/Desktop` and `~/DesktopVault` only.
  - Treat macOS bundles (`.app`, `.pages`, `.key`, `.rtfd`) as atomic packages—never reach inside and split their contents.
