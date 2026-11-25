import CoreServices
import Foundation

/// Event-driven macOS FSEvents watcher for `~/Desktop` with stability debouncing.
public final class DesktopWatcher: @unchecked Sendable {
    private let desktopURL: URL
    private let debounceInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.cleardesk.fsevents", qos: .utility)
    private let onUpdate: @Sendable (Set<String>) -> Void

    private var streamRef: FSEventStreamRef?
    private var knownEntries: Set<String> = []
    private var settlingDeadlines: [String: Date] = [:]
    private var settleTimer: DispatchSourceTimer?

    public init(
        desktopURL: URL,
        debounceInterval: TimeInterval = 2.0,
        onUpdate: @escaping @Sendable (Set<String>) -> Void
    ) {
        self.desktopURL = desktopURL.standardizedFileURL
        self.debounceInterval = debounceInterval
        self.onUpdate = onUpdate
    }

    deinit {
        stop()
    }

    public func start() {
        queue.sync {
            guard streamRef == nil else { return }
            knownEntries = snapshotTopLevelNames()

            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )

            let pathsToWatch = [desktopURL.path] as CFArray
            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
            )

            guard let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                { _, clientCallBackInfo, _, _, _, _ in
                    guard let info = clientCallBackInfo else { return }
                    let watcher = Unmanaged<DesktopWatcher>.fromOpaque(info).takeUnretainedValue()
                    watcher.handleFilesystemEvent()
                },
                &context,
                pathsToWatch,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.35,
                flags
            ) else {
                return
            }

            streamRef = stream
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    public func stop() {
        queue.sync {
            settleTimer?.cancel()
            settleTimer = nil
            if let stream = streamRef {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                streamRef = nil
            }
        }
    }

    private func handleFilesystemEvent() {
        let current = snapshotTopLevelNames()
        let newlyAppeared = current.subtracting(knownEntries)
        let removed = knownEntries.subtracting(current)
        knownEntries = current

        let deadline = Date().addingTimeInterval(debounceInterval)
        for name in newlyAppeared {
            settlingDeadlines[name] = deadline
        }
        for name in removed {
            settlingDeadlines.removeValue(forKey: name)
        }

        scheduleSettleCheckIfNeeded()
        emitCurrentSettlingSet()
    }

    private func scheduleSettleCheckIfNeeded() {
        settleTimer?.cancel()
        guard let nextDeadline = settlingDeadlines.values.min() else {
            settleTimer = nil
            return
        }

        let delay = max(0.1, nextDeadline.timeIntervalSinceNow)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            self?.pruneSettledItems()
        }
        timer.resume()
        settleTimer = timer
    }

    private func pruneSettledItems() {
        let now = Date()
        settlingDeadlines = settlingDeadlines.filter { $0.value > now }
        scheduleSettleCheckIfNeeded()
        emitCurrentSettlingSet()
    }

    private func emitCurrentSettlingSet() {
        let activeSettling = Set(settlingDeadlines.keys)
        onUpdate(activeSettling)
    }

    private func snapshotTopLevelNames() -> Set<String> {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return Set(urls.map(\.lastPathComponent))
    }
}
