import Foundation

public enum PathGuardError: Error, LocalizedError, Equatable, Sendable {
    case outsideAuthorizedRoot(String)
    case invalidFileName(String)
    case symlinkEscapeDetected(String)
    case ignoredTransientFile(String)
    case sourceDoesNotExist(String)

    public var errorDescription: String? {
        switch self {
        case .outsideAuthorizedRoot(let path):
            return "Security block: path is outside authorized ClearDesk roots (\(path))."
        case .invalidFileName(let name):
            return "Security block: invalid filename (\(name))."
        case .symlinkEscapeDetected(let path):
            return "Security block: symbolic link points outside authorized boundaries (\(path))."
        case .ignoredTransientFile(let name):
            return "Skipped transient or iCloud placeholder file (\(name))."
        case .sourceDoesNotExist(let path):
            return "File no longer exists at \(path)."
        }
    }
}

/// Cybersecurity boundary enforcer for all ClearDesk filesystem operations.
public struct PathGuard: Sendable {
    public let desktopRoot: URL
    public let vaultRoot: URL

    private static let ignoredExactNames: Set<String> = [
        ".DS_Store",
        ".localized",
        "Icon\r",
        ".Spotlight-V100",
        ".Trashes"
    ]

    private static let ignoredExtensions: Set<String> = [
        "crdownload",
        "download",
        "part",
        "tmp",
        "icloud"
    ]

    public init(desktopRoot: URL, vaultRoot: URL) {
        self.desktopRoot = desktopRoot.standardizedFileURL
        self.vaultRoot = vaultRoot.standardizedFileURL
    }

    /// Creates a directory if missing and locks POSIX permissions to 0700 (owner only).
    public static func ensureSecureDirectory(_ url: URL, fileManager: FileManager = .default) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } else {
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
    }

    /// Writes sensitive local metadata atomically with 0600 (owner read/write only) permissions.
    public static func writeSecureFile(_ data: Data, to url: URL, fileManager: FileManager = .default) throws {
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Rejects path separators, traversal segments, null bytes, and control characters.
    public func validateFileName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != ".." else {
            throw PathGuardError.invalidFileName(name)
        }
        if name.contains("/") || name.contains("\\") || name.contains("\0") {
            throw PathGuardError.invalidFileName(name)
        }
        if name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            throw PathGuardError.invalidFileName(name)
        }
    }

    /// Detects transient/incomplete files and iCloud Drive evicted stubs that must never be moved.
    public func isIgnoredTransientFile(url: URL) -> Bool {
        let name = url.lastPathComponent
        if Self.ignoredExactNames.contains(name) {
            return true
        }
        if name.hasPrefix("._") || name.hasPrefix("~$") || name.hasPrefix(".~") {
            return true
        }
        if name.hasPrefix(".") && name.hasSuffix(".icloud") {
            return true
        }
        let ext = url.pathExtension.lowercased()
        if Self.ignoredExtensions.contains(ext) {
            return true
        }
        return false
    }

    /// Ensures `url` sits strictly inside `root` (as a direct child or descendant) and does not escape via traversal or symlinks.
    public func validateContained(_ url: URL, within root: URL, fileManager: FileManager = .default) throws {
        let standardizedRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        let parentResolved = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().path
        let candidateStandardized = url.standardizedFileURL.path

        let rootPrefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"

        guard parentResolved == standardizedRoot || parentResolved.hasPrefix(rootPrefix) else {
            throw PathGuardError.outsideAuthorizedRoot(candidateStandardized)
        }

        try validateFileName(url.lastPathComponent)

        // If the item itself is a symlink, refuse if its resolved target escapes outside Desktop & Vault roots.
        if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
            let resolvedTarget = url.resolvingSymlinksInPath().path
            let desktopPath = desktopRoot.resolvingSymlinksInPath().path
            let vaultPath = vaultRoot.resolvingSymlinksInPath().path
            let desktopPrefix = desktopPath.hasSuffix("/") ? desktopPath : desktopPath + "/"
            let vaultPrefix = vaultPath.hasSuffix("/") ? vaultPath : vaultPath + "/"

            let targetSafe = resolvedTarget.hasPrefix(desktopPrefix) || resolvedTarget.hasPrefix(vaultPrefix)
            if !targetSafe {
                throw PathGuardError.symlinkEscapeDetected(url.path)
            }
        }
    }

    /// Computes a collision-safe destination URL inside `directory` without ever overwriting an existing file.
    public func safeDestinationURL(
        forName originalName: String,
        in directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try validateFileName(originalName)

        let baseCandidate = directory.appendingPathComponent(originalName, isDirectory: false)
        try validateContained(baseCandidate, within: directory, fileManager: fileManager)

        if !fileManager.fileExists(atPath: baseCandidate.path) {
            return baseCandidate
        }

        let nsName = originalName as NSString
        let ext = nsName.pathExtension
        let stem = ext.isEmpty ? originalName : nsName.deletingPathExtension

        var counter = 2
        while counter < 10_000 {
            let suffixed = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
            let candidate = directory.appendingPathComponent(suffixed, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) {
                try validateContained(candidate, within: directory, fileManager: fileManager)
                return candidate
            }
            counter += 1
        }

        let fallback = ext.isEmpty
            ? "\(stem) (\(UUID().uuidString.prefix(8)))"
            : "\(stem) (\(UUID().uuidString.prefix(8))).\(ext)"
        return directory.appendingPathComponent(fallback, isDirectory: false)
    }
}
