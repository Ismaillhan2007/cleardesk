import Foundation

public struct MoveRecord: Codable, Equatable, Sendable {
    public let sourcePath: String
    public let destinationPath: String
    public let timestamp: Date

    public init(sourcePath: String, destinationPath: String, timestamp: Date = Date()) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.timestamp = timestamp
    }
}

public struct SweepBatch: Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let moves: [MoveRecord]

    public init(id: UUID = UUID(), timestamp: Date = Date(), moves: [MoveRecord]) {
        self.id = id
        self.timestamp = timestamp
        self.moves = moves
    }
}

public struct PersistedState: Codable, Equatable, Sendable {
    public var pinnedFileNames: Set<String>
    public var autoSweepEnabled: Bool

    public init(pinnedFileNames: Set<String> = [], autoSweepEnabled: Bool = false) {
        self.pinnedFileNames = pinnedFileNames
        self.autoSweepEnabled = autoSweepEnabled
    }
}

/// Crash-safe, owner-only (0600) local persistence for sweep undo batches and pinned state.
public final class TransactionLog: @unchecked Sendable {
    private let stateDirectory: URL
    private let logURL: URL
    private let stateURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(stateDirectory: URL, fileManager: FileManager = .default) throws {
        self.stateDirectory = stateDirectory
        self.logURL = stateDirectory.appendingPathComponent("transactions.jsonl")
        self.stateURL = stateDirectory.appendingPathComponent("state.json")
        self.fileManager = fileManager

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        try PathGuard.ensureSecureDirectory(stateDirectory, fileManager: fileManager)
    }

    public func loadState() -> PersistedState {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? Data(contentsOf: stateURL),
              let state = try? decoder.decode(PersistedState.self, from: data) else {
            return PersistedState()
        }
        return state
    }

    public func saveState(_ state: PersistedState) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try encoder.encode(state)
        try PathGuard.writeSecureFile(data, to: stateURL, fileManager: fileManager)
    }

    public func appendBatch(_ batch: SweepBatch) throws {
        guard !batch.moves.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        var batches = loadAllBatchesUnlocked()
        batches.append(batch)
        // Keep last 50 sweep batches to bound disk usage cleanly.
        if batches.count > 50 {
            batches = Array(batches.suffix(50))
        }
        try writeAllBatchesUnlocked(batches)
    }

    public func peekLastBatch() -> SweepBatch? {
        lock.lock()
        defer { lock.unlock() }
        return loadAllBatchesUnlocked().last
    }

    public func popLastBatch() throws -> SweepBatch? {
        lock.lock()
        defer { lock.unlock() }

        var batches = loadAllBatchesUnlocked()
        guard let last = batches.popLast() else {
            return nil
        }
        try writeAllBatchesUnlocked(batches)
        return last
    }

    private func loadAllBatchesUnlocked() -> [SweepBatch] {
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else {
            return []
        }
        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(SweepBatch.self, from: data)
            }
    }

    private func writeAllBatchesUnlocked(_ batches: [SweepBatch]) throws {
        var lines: [String] = []
        for batch in batches {
            let data = try encoder.encode(batch)
            if let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }
        let payload = (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")).data(using: .utf8) ?? Data()
        try PathGuard.writeSecureFile(payload, to: logURL, fileManager: fileManager)
    }
}
