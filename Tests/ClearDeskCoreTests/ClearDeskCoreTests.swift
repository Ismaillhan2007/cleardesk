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

    @Test("Search finds top-level and nested Desktop & Vault files with relevance ranking")
    func searchFindsTopLevelAndNestedFilesWithRanking() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        // Top-level Desktop folder + nested file
        let taxesDir = env.desktop.appendingPathComponent("Taxes 2025")
        try FileManager.default.createDirectory(at: taxesDir, withIntermediateDirectories: true)
        try Data("w2".utf8).write(to: taxesDir.appendingPathComponent("W2_Form_Final.pdf"))

        // Top-level Desktop files for ranking checks
        try Data("a".utf8).write(to: env.desktop.appendingPathComponent("Roadmap.pdf"))
        try Data("b".utf8).write(to: env.desktop.appendingPathComponent("Q4_Product_Roadmap_2026.pdf"))

        // Nested Vault file
        let archiveDir = env.vault.appendingPathComponent("Client Archive")
        try FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        try Data("c".utf8).write(to: archiveDir.appendingPathComponent("Invoice_Nov.pdf"))

        // 1. Exact stem ranks above longer substring match
        let roadmapResults = env.engine.search("roadmap")
        #expect(roadmapResults.count == 2)
        #expect(roadmapResults.first?.name == "Roadmap.pdf")

        // 2. Multi-word token match works across underscores/spaces in any order
        let tokenResults = env.engine.search("2026 q4 roadmap")
        #expect(tokenResults.first?.name == "Q4_Product_Roadmap_2026.pdf")

        // 3. Nested Desktop file found with parent path context
        let nestedDesktop = env.engine.search("w2")
        #expect(nestedDesktop.count == 1)
        #expect(nestedDesktop.first?.name == "W2_Form_Final.pdf")
        #expect(nestedDesktop.first?.relativeParentPath == "Taxes 2025")

        // 4. Nested Vault file found via parent + filename tokens
        let nestedVault = env.engine.search("client invoice")
        #expect(nestedVault.count == 1)
        #expect(nestedVault.first?.name == "Invoice_Nov.pdf")
        #expect(nestedVault.first?.relativeParentPath == "Client Archive")

        // 5. Folder search finds folder directly by name
        let folderResults = env.engine.search("taxes")
        #expect(folderResults.contains(where: { $0.name == "Taxes 2025" && $0.kind == .folder }))
    }

    @Test("Recursive search never traverses symlinks outside Desktop or heavy build dirs")
    func recursiveSearchRespectsSecurityBoundaries() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let outsideDir = env.tempRoot.appendingPathComponent("OutsideSecretDir")
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        try Data("top-secret".utf8).write(to: outsideDir.appendingPathComponent("Passwords.txt"))

        let symlinkOnDesktop = env.desktop.appendingPathComponent("LinkToOutside")
        try FileManager.default.createSymbolicLink(at: symlinkOnDesktop, withDestinationURL: outsideDir)

        let nodeModules = env.desktop.appendingPathComponent("Project/node_modules")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try Data("js".utf8).write(to: nodeModules.appendingPathComponent("hidden_dep.js"))

        #expect(env.engine.search("Passwords").isEmpty)
        #expect(env.engine.search("hidden_dep").isEmpty)
    }

    @Test("Moving files into folders is collision-safe and blocks self-containment")
    func moveIntoFolderCollisionSafeAndBlocksSelfMove() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let targetFolder = env.vault.appendingPathComponent("Projects")
        try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: targetFolder.appendingPathComponent("Spec.pdf"))

        let incoming = env.desktop.appendingPathComponent("Spec.pdf")
        try Data("new".utf8).write(to: incoming)

        let record = try env.engine.moveItem(incoming, intoFolder: targetFolder)
        #expect(!FileManager.default.fileExists(atPath: incoming.path))
        #expect(URL(fileURLWithPath: record.destinationPath).lastPathComponent == "Spec (2).pdf")
        #expect(try String(contentsOf: targetFolder.appendingPathComponent("Spec.pdf"), encoding: .utf8) == "existing")
        #expect(try String(contentsOf: targetFolder.appendingPathComponent("Spec (2).pdf"), encoding: .utf8) == "new")

        // Moving a folder into itself or its own subfolder must fail
        let childFolder = targetFolder.appendingPathComponent("Sub")
        try FileManager.default.createDirectory(at: childFolder, withIntermediateDirectories: true)
        #expect(throws: PathGuardError.self) {
            try env.engine.moveItem(targetFolder, intoFolder: targetFolder)
        }
        #expect(throws: PathGuardError.self) {
            try env.engine.moveItem(targetFolder, intoFolder: childFolder)
        }
    }

    @Test("Delete blocks unauthorized paths and root folders")
    func deleteEnforcesSecurityBoundaries() throws {
        let env = try makeIsolatedEnvironment()
        defer { try? FileManager.default.removeItem(at: env.tempRoot) }

        let outside = env.tempRoot.appendingPathComponent("Outside.txt")
        try Data("keep".utf8).write(to: outside)

        #expect(throws: PathGuardError.self) { try env.engine.deleteItem(outside) }
        #expect(throws: PathGuardError.self) { try env.engine.deleteItem(env.desktop) }
        #expect(throws: PathGuardError.self) { try env.engine.deleteItem(env.vault) }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }
}
