import AppKit
import ClearDeskCore
import Foundation
import Observation

public enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case all = "All Files"
    case desktop = "On Desktop"
    case vault = "Vault"
    case folders = "Folders"
    case documents = "Documents"
    case images = "Images"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .all: return "macwindow"
        case .desktop: return "menubar.dock.rectangle"
        case .vault: return "archivebox"
        case .folders: return "folder.fill"
        case .documents: return "doc.text"
        case .images: return "photo"
        }
    }
}

@MainActor
@Observable
final class ClearDeskViewModel {
    private let engine: FileVaultEngine
    private var watcher: DesktopWatcher?
    private var settlingNames: Set<String> = []
    private var autoSweepTask: Task<Void, Never>?

    var items: [DeskItem] = []
    var selectedSection: SidebarSection = .all
    var selectedItemID: DeskItem.ID?
    var searchText: String = ""
    var autoSweepEnabled: Bool = false
    var hudMessage: String?
    var canUndo: Bool = false
    var errorMessage: String?

    init() {
        do {
            self.engine = try FileVaultEngine()
            self.autoSweepEnabled = engine.autoSweepEnabled
            self.canUndo = engine.canUndo
            refresh()
            startWatching()
        } catch {
            fatalError("Failed to initialize ClearDesk engine: \(error.localizedDescription)")
        }
    }

    var desktopCount: Int {
        items.filter { $0.location == .desktop }.count
    }

    var sweepableDesktopCount: Int {
        items.filter { $0.location == .desktop && !$0.isPinned && !$0.isSettling }.count
    }

    var selectedItem: DeskItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .all: return items.count
        case .desktop: return items.filter { $0.location == .desktop }.count
        case .vault: return items.filter { $0.location == .vault }.count
        case .folders: return items.filter { $0.kind == .folder }.count
        case .documents: return items.filter { $0.kind == .document }.count
        case .images: return items.filter { $0.kind == .image }.count
        }
    }

    var filteredItems: [DeskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            if !query.isEmpty && !item.name.lowercased().contains(query) {
                return false
            }
            switch selectedSection {
            case .all: return true
            case .desktop: return item.location == .desktop
            case .vault: return item.location == .vault
            case .folders: return item.kind == .folder
            case .documents: return item.kind == .document
            case .images: return item.kind == .image
            }
        }
    }

    func refresh() {
        items = engine.listItems(settlingNames: settlingNames)
        canUndo = engine.canUndo
        if let selectedItemID, !items.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = nil
        }
    }

    func sweepDesktop() {
        do {
            let batch = try engine.sweepDesktop(settlingNames: settlingNames)
            refresh()
            if !batch.moves.isEmpty {
                let count = batch.moves.count
                showHUD("Swept \(count) item\(count == 1 ? "" : "s") into Vault")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveToVault(_ item: DeskItem) {
        do {
            try engine.moveToVault(itemURL: item.url)
            refresh()
            showHUD("Moved “\(item.name)” to Vault")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreToDesktop(_ item: DeskItem) {
        do {
            try engine.restoreToDesktop(itemURL: item.url)
            refresh()
            showHUD("Restored “\(item.name)” to Desktop")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoLastSweep() {
        do {
            let restored = try engine.undoLastSweep()
            refresh()
            if restored > 0 {
                showHUD("Restored \(restored) item\(restored == 1 ? "" : "s") to Desktop")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePin(_ item: DeskItem) {
        do {
            let pinned = try engine.togglePin(fileName: item.name)
            refresh()
            showHUD(pinned ? "Pinned “\(item.name)” to Desktop" : "Unpinned “\(item.name)”")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setAutoSweep(_ enabled: Bool) {
        do {
            try engine.setAutoSweepEnabled(enabled)
            autoSweepEnabled = enabled
            if enabled {
                scheduleAutoSweepIfNeeded()
            } else {
                autoSweepTask?.cancel()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openItem(_ item: DeskItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealInFinder(_ item: DeskItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func quickLook(_ item: DeskItem) {
        QuickLookCoordinator.shared.preview(url: item.url)
    }

    // MARK: - Private

    private func startWatching() {
        let watcher = DesktopWatcher(desktopURL: engine.desktopURL, debounceInterval: 2.0) { [weak self] settling in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.settlingNames = settling
                self.refresh()
                if self.autoSweepEnabled && settling.isEmpty && self.sweepableDesktopCount > 0 {
                    self.scheduleAutoSweepIfNeeded()
                }
            }
        }
        watcher.start()
        self.watcher = watcher
    }

    private func scheduleAutoSweepIfNeeded() {
        autoSweepTask?.cancel()
        guard autoSweepEnabled else { return }
        autoSweepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, self.autoSweepEnabled else { return }
            if self.sweepableDesktopCount > 0 {
                self.sweepDesktop()
            }
        }
    }

    private func showHUD(_ message: String) {
        hudMessage = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            if self?.hudMessage == message {
                self?.hudMessage = nil
            }
        }
    }
}
