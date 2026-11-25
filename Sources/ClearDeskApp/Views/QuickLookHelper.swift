import AppKit
import Quartz

@MainActor
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()
    private var currentURL: URL?

    func preview(url: URL) {
        currentURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            currentURL == nil ? 0 : 1
        }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated {
            currentURL as NSURL?
        }
    }
}
