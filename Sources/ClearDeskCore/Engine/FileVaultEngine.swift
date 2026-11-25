import Foundation

/// Core engine managing Live Mirror (`~/Desktop`) and Vault (`~/DesktopVault`) operations.
public final class FileVaultEngine: @unchecked Sendable {
    public let desktopURL: URL
    public let vaultURL: URL
    public let pathGuard: PathGuard
    private let transactionLog: TransactionLog
    private let fileManager: FileManager

    public init(
        desktopURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
        vaultURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("DesktopVault"),
        stateURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClearDesk"),
        fileManager: FileManager = .default
    ) throws {
        self.desktopURL = desktopURL.standardizedFileURL
        self.vaultURL = vaultURL.standardizedFileURL
        self.fileManager = fileManager
        self.pathGuard = PathGuard(desktopRoot: self.desktopURL, vaultRoot: self.vaultURL)

        try PathGuard.ensureSecureDirectory(self.vaultURL, fileManager: fileManager)
        self.transactionLog = try TransactionLog(stateDirectory: stateURL, fileManager: fileManager)
    }

    public var canUndo: Bool {
        transactionLog.peekLastBatch() != nil
    }

    public var autoSweepEnabled: Bool {
        transactionLog.loadState().autoSweepEnabled
    }

    public func setAutoSweepEnabled(_ enabled: Bool) throws {
        var state = transactionLog.loadState()
        state.autoSweepEnabled = enabled
        try transactionLog.saveState(state)
    }

    @discardableResult
    public func togglePin(fileName: String) throws -> Bool {
        try pathGuard.validateFileName(fileName)
        var state = transactionLog.loadState()
        let nowPinned: Bool
        if state.pinnedFileNames.contains(fileName) {
            state.pinnedFileNames.remove(fileName)
            nowPinned = false
        } else {
            state.pinnedFileNames.insert(fileName)
            nowPinned = true
        }
        try transactionLog.saveState(state)
        return nowPinned
    }

    public func listItems(settlingNames: Set<String> = []) -> [DeskItem] {
        let state = transactionLog.loadState()
        let desktopItems = scanDirectory(
            desktopURL,
            location: .desktop,
            pinnedNames: state.pinnedFileNames,
            settlingNames: settlingNames
        )
        let vaultItems = scanDirectory(
            vaultURL,
            location: .vault,
            pinnedNames: [],
            settlingNames: []
        )
        return (desktopItems + vaultItems).sorted { lhs, rhs in
            if lhs.location != rhs.location {
                return lhs.location == .desktop
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    /// Moves all settled, unpinned, non-transient Desktop items into the Vault atomically.
    @discardableResult
    public func sweepDesktop(settlingNames: Set<String> = []) throws -> SweepBatch {
        let state = transactionLog.loadState()
        let candidates = scanDirectory(
            desktopURL,
            location: .desktop,
            pinnedNames: state.pinnedFileNames,
            settlingNames: settlingNames
        ).filter { !$0.isPinned && !$0.isSettling }

        var records: [MoveRecord] = []
        for item in candidates {
            do {
                let record = try moveFile(item.url, from: desktopURL, to: vaultURL)
                records.append(record)
            } catch PathGuardError.symlinkEscapeDetected, PathGuardError.ignoredTransientFile {
                continue
            }
        }

        let batch = SweepBatch(moves: records)
        if !records.isEmpty {
            try transactionLog.appendBatch(batch)
        }
        return batch
    }

    @discardableResult
    public func moveToVault(itemURL: URL) throws -> MoveRecord {
        let record = try moveFile(itemURL, from: desktopURL, to: vaultURL)
        try transactionLog.appendBatch(SweepBatch(moves: [record]))
        return record
    }

    @discardableResult
    public func restoreToDesktop(itemURL: URL) throws -> MoveRecord {
        return try moveFile(itemURL, from: vaultURL, to: desktopURL)
    }

    /// Reverses the most recent sweep batch back to Desktop using collision-safe naming.
    @discardableResult
    public func undoLastSweep() throws -> Int {
        guard let batch = try transactionLog.popLastBatch() else {
            return 0
        }

        var restoredCount = 0
        for record in batch.moves.reversed() {
            let currentURL = URL(fileURLWithPath: record.destinationPath)
            guard fileManager.fileExists(atPath: currentURL.path) else { continue }
            let originalName = URL(fileURLWithPath: record.sourcePath).lastPathComponent
            let safeTarget = try pathGuard.safeDestinationURL(
                forName: originalName,
                in: desktopURL,
                fileManager: fileManager
            )
            try pathGuard.validateContained(currentURL, within: vaultURL, fileManager: fileManager)
            try fileManager.moveItem(at: currentURL, to: safeTarget)
            restoredCount += 1
        }
        return restoredCount
    }

    // MARK: - Private

    private func moveFile(_ sourceURL: URL, from sourceRoot: URL, to destinationRoot: URL) throws -> MoveRecord {
        let standardized = sourceURL.standardizedFileURL
        guard fileManager.fileExists(atPath: standardized.path) else {
            throw PathGuardError.sourceDoesNotExist(standardized.path)
        }
        if pathGuard.isIgnoredTransientFile(url: standardized) {
            throw PathGuardError.ignoredTransientFile(standardized.lastPathComponent)
        }

        try pathGuard.validateContained(standardized, within: sourceRoot, fileManager: fileManager)

        let destination = try pathGuard.safeDestinationURL(
            forName: standardized.lastPathComponent,
            in: destinationRoot,
            fileManager: fileManager
        )

        try fileManager.moveItem(at: standardized, to: destination)
        return MoveRecord(sourcePath: standardized.path, destinationPath: destination.path)
    }

    private func scanDirectory(
        _ root: URL,
        location: DeskLocation,
        pinnedNames: Set<String>,
        settlingNames: Set<String>
    ) -> [DeskItem] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isPackageKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey
        ]

        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        return urls.compactMap { url -> DeskItem? in
            if pathGuard.isIgnoredTransientFile(url: url) {
                return nil
            }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isHidden == true {
                return nil
            }

            let isDir = values?.isDirectory ?? false
            let isPkg = values?.isPackage ?? false
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate ?? Date()
            let name = url.lastPathComponent
            let kind = DeskItem.classifyKind(url: url, isDirectory: isDir, isPackage: isPkg)

            return DeskItem(
                name: name,
                url: url.standardizedFileURL,
                kind: kind,
                location: location,
                byteSize: size,
                modifiedAt: modified,
                isPinned: location == .desktop && pinnedNames.contains(name),
                isSettling: location == .desktop && settlingNames.contains(name),
                isPackage: isPkg
            )
        }
    }
}
