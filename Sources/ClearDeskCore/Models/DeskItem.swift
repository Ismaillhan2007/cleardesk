import Foundation
import UniformTypeIdentifiers

public enum DeskLocation: String, Codable, Sendable, CaseIterable {
    case desktop
    case vault
}

public enum DeskItemKind: String, Codable, Sendable, CaseIterable {
    case folder
    case document
    case image
    case other
}

public struct DeskItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let kind: DeskItemKind
    public let location: DeskLocation
    public let byteSize: Int64
    public let modifiedAt: Date
    public let isPinned: Bool
    public let isSettling: Bool
    public let isPackage: Bool
    public let relativeParentPath: String?

    public init(
        name: String,
        url: URL,
        kind: DeskItemKind,
        location: DeskLocation,
        byteSize: Int64,
        modifiedAt: Date,
        isPinned: Bool,
        isSettling: Bool,
        isPackage: Bool,
        relativeParentPath: String? = nil
    ) {
        self.id = url.standardizedFileURL.path
        self.name = name
        self.url = url
        self.kind = kind
        self.location = location
        self.byteSize = byteSize
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
        self.isSettling = isSettling
        self.isPackage = isPackage
        self.relativeParentPath = relativeParentPath
    }

    public var formattedSize: String {
        if kind == .folder && !isPackage {
            return "Folder"
        }
        return ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    public static func classifyKind(url: URL, isDirectory: Bool, isPackage: Bool) -> DeskItemKind {
        if isDirectory && !isPackage {
            return .folder
        }
        let ext = url.pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext) {
            if utType.conforms(to: .image) {
                return .image
            }
            if utType.conforms(to: .pdf)
                || utType.conforms(to: .text)
                || utType.conforms(to: .presentation)
                || utType.conforms(to: .spreadsheet)
                || utType.conforms(to: .rtf)
                || utType.conforms(to: .rtfd) {
                return .document
            }
        }
        if ["doc", "docx", "pages", "numbers", "key", "md", "txt", "pdf", "xlsx", "csv"].contains(ext) {
            return .document
        }
        if ["png", "jpg", "jpeg", "heic", "webp", "gif", "tiff", "svg"].contains(ext) {
            return .image
        }
        return .other
    }
}
