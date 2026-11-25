import ClearDeskCore
import Foundation
import Testing

@Suite("ClearDeskCore Engine & Security Tests")
struct ClearDeskCoreTests {
    private func makeIsolatedEnvironment() throws -> (tempRoot: URL, desktop: URL, vault: URL, engine: FileVaultEngine) {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClearDeskTests-\(UUID().uuidString)")
        let desktop = tempRoot.appendingPathComponent("Desktop")
        let vault = tempRoot.appendingPathComponent("DesktopVault")
        let state = tempRoot.appendingPathComponent("State")

        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        let engine = try FileVaultEngine(desktopURL: desktop, vaultURL: vault, stateURL: state)
        return (tempRoot, desktop, vault, engine)
    }

    @Test("Sweep and 1-click Undo round-trip preserves files")
    func sweepAndUndoRoundTrip() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let doc = env.desktop.appendingPathComponent("Roadmap.pdf")
        try Data("hello".utf8).write(to: doc)

        let batch = try env.engine.sweepDesktop()
        #expect(batch.moves.count == 1)
        #expect(!FileManager.default.fileExists(atPath: doc.path))
        #expect(FileManager.default.fileExists(atPath: env.vault.appendingPathComponent("Roadmap.pdf").path))

        let restored = try env.engine.undoLastSweep()
        #expect(restored == 1)
        #expect(FileManager.default.fileExists(atPath: doc.path))
    }

    @Test("Collision-safe naming never overwrites existing files")
    func collisionSafeNamingNeverOverwrites() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let existing = env.vault.appendingPathComponent("Notes.txt")
        try Data("original".utf8).write(to: existing)

        let incoming = env.desktop.appendingPathComponent("Notes.txt")
        try Data("new".utf8).write(to: incoming)

        try env.engine.sweepDesktop()

        let originalContent = try String(contentsOf: existing, encoding: .utf8)
        let renamedURL = env.vault.appendingPathComponent("Notes (2).txt")
        let renamedContent = try String(contentsOf: renamedURL, encoding: .utf8)

        #expect(originalContent == "original")
        #expect(renamedContent == "new")
    }

    @Test("Pinned and settling items are excluded from sweeps")
    func pinnedAndSettlingItemsExcluded() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let pinned = env.desktop.appendingPathComponent("CurrentSprint")
        try FileManager.default.createDirectory(at: pinned, withIntermediateDirectories: true)
        try env.engine.togglePin(fileName: "CurrentSprint")

        let settling = env.desktop.appendingPathComponent("NewFolder")
        try FileManager.default.createDirectory(at: settling, withIntermediateDirectories: true)

        let ready = env.desktop.appendingPathComponent("Ready.txt")
        try Data("ok".utf8).write(to: ready)

        let batch = try env.engine.sweepDesktop(settlingNames: ["NewFolder"])
        #expect(batch.moves.count == 1)
        #expect(FileManager.default.fileExists(atPath: pinned.path))
        #expect(FileManager.default.fileExists(atPath: settling.path))
        #expect(!FileManager.default.fileExists(atPath: ready.path))
    }

    @Test("PathGuard blocks path traversal and symlink escapes")
    func pathGuardBlocksTraversalAndSymlinkEscape() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let guardObj = env.engine.pathGuard

        #expect(throws: PathGuardError.self) { try guardObj.validateFileName("../etc/passwd") }
        #expect(throws: PathGuardError.self) { try guardObj.validateFileName("bad/name") }
        #expect(throws: PathGuardError.self) { try guardObj.validateFileName("bad\0name") }

        let outsideFile = env.tempRoot.appendingPathComponent("SecretOutside.txt")
        try Data("secret".utf8).write(to: outsideFile)
        #expect(throws: PathGuardError.self) {
            try guardObj.validateContained(outsideFile, within: env.desktop)
        }

        let maliciousLink = env.desktop.appendingPathComponent("escape_link")
        try FileManager.default.createSymbolicLink(at: maliciousLink, withDestinationURL: outsideFile)
        #expect(throws: PathGuardError.self) {
            try guardObj.validateContained(maliciousLink, within: env.desktop)
        }
    }

    @Test("Transient download and iCloud stub files are ignored")
    func transientAndICloudStubsIgnored() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let guardObj = env.engine.pathGuard
        #expect(guardObj.isIgnoredTransientFile(url: env.desktop.appendingPathComponent(".DS_Store")))
        #expect(guardObj.isIgnoredTransientFile(url: env.desktop.appendingPathComponent("movie.crdownload")))
        #expect(guardObj.isIgnoredTransientFile(url: env.desktop.appendingPathComponent(".Report.pdf.icloud")))
        #expect(guardObj.isIgnoredTransientFile(url: env.desktop.appendingPathComponent("~$Budget.xlsx")))
        #expect(!guardObj.isIgnoredTransientFile(url: env.desktop.appendingPathComponent("Report.pdf")))
    }

    @Test("Vault directory enforces owner-only 0700 POSIX permissions")
    func vaultDirectoryOwnerOnlyPermissions() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let attrs = try FileManager.default.attributesOfItem(atPath: env.vault.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue
        #expect(perms == 0o700)
    }
}
