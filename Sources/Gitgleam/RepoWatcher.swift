import CoreServices
import Foundation

/// Watches a directory tree for filesystem changes via **FSEvents** and invokes
/// a callback whenever anything under it changes.
///
/// This lets `GitMonitor` refresh the instant the working tree or `.git`
/// changes, rather than only on the periodic timer (which becomes a safety-net
/// fallback). FSEvents watches recursively and coalesces a burst of changes
/// into a single callback after a short latency window, so a big operation
/// (checkout, pull, mass edit) triggers one refresh, not hundreds.
///
/// The whole tree — including `.git` — is watched so that commits made outside
/// the app (which touch `.git` but not the working files) are still picked up.
/// `git status` may itself rewrite `.git/index`'s stat cache, which can produce
/// one extra follow-up event; the latency coalescing plus `GitMonitor`'s
/// in-flight guard keep that from looping.
final class RepoWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "nl.mo6.gitgleam.repowatcher")
    private let onChange: @Sendable () -> Void

    /// Coalescing latency in seconds: FSEvents batches a burst of changes into
    /// a single callback after this quiet period.
    private let latency: CFTimeInterval = 0.5

    /// Starts watching `path` immediately. `onChange` is called (on a private
    /// background queue) for each coalesced batch of changes.
    init?(path: String, onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = UInt32(kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            repoWatcherCallback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            return nil
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    /// Invoked by the C callback for each coalesced batch of events.
    fileprivate func fire() {
        onChange()
    }
}

/// FSEvents C callback: recovers the `RepoWatcher` from `info` and forwards.
/// The specific paths/flags are ignored — any change means "re-check the repo".
private func repoWatcherCallback(
    _ stream: ConstFSEventStreamRef,
    _ info: UnsafeMutableRawPointer?,
    _ count: Int,
    _ paths: UnsafeMutableRawPointer,
    _ flags: UnsafePointer<FSEventStreamEventFlags>,
    _ ids: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    Unmanaged<RepoWatcher>.fromOpaque(info).takeUnretainedValue().fire()
}
