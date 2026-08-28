import Foundation
import WatchConnectivity
import os.log

/// Manages iPhone → Watch communication.
///
/// Responsibilities:
/// - Syncs user preferences to Watch via `applicationContext` whenever they change.
/// - Sends real-time timer events via `sendMessage` when the Watch is reachable.
/// - Receives timer events from Watch (e.g., user started timer on wrist).

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "PhoneConnectivity")

@MainActor
final class PhoneConnectivityService: NSObject, ObservableObject, Sendable {

    private let session: WCSession

    /// Callback for timer events received from the Watch.
    var onWatchTimerEvent: (@MainActor @Sendable (WatchMessage) -> Void)?

    /// Retains the block-based notification observer so it stays alive
    /// for the lifetime of this object.
    private var defaultsObserver: (any NSObjectProtocol)?

    override init() {
        self.session = WCSession.default
        super.init()
        guard WCSession.isSupported() else {
            log.debug("WCSession not supported on this device")
            return
        }
        session.delegate = self
        session.activate()
        log.debug("session activated")

        // Observe UserDefaults changes to auto-sync preferences.
        // IMPORTANT: Use the queue-based API so delivery always happens
        // on the main queue. The old selector-based addObserver delivers
        // on the *posting* thread, which crashes when a background actor
        // writes to UserDefaults (dispatch_assert_queue_fail).
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncPreferences()
            }
        }
    }

    isolated deinit {
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Preference Sync

    /// Push the current preference state to the Watch.
    /// Called automatically when UserDefaults change, and can be called manually.
    func syncPreferences() {
        guard session.activationState == .activated else {
            log.debug("syncPreferences - session not activated, skipping")
            return
        }
        guard session.isPaired else { return }
        let prefs = SyncedPreferences.fromCurrentState()
        do {
            try session.updateApplicationContext(prefs.toDictionary())
            log.debug("preferences synced to Watch")
        } catch {
            log.error("failed to sync preferences: \(error)")
        }
    }

    // MARK: - Timer Events

    /// Send a timer event to the Watch in real-time.
    func send(_ message: WatchMessage) {
        guard session.activationState == .activated else { return }
        guard session.isPaired else { return }

        if session.isReachable {
            session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
                log.error("sendMessage failed: \(error)")
            }
        } else {
            // Queue for delivery when Watch wakes
            session.transferUserInfo(message.toDictionary())
            log.debug("Watch not reachable - queued via transferUserInfo")
        }
    }

    /// Respond to a state request from the Watch with the current timer state.
    func sendStateResponse(endDate: Date?, isRunning: Bool, presetName: String?, duration: TimeInterval) {
        let response = WatchMessage.stateResponse(
            endDate: endDate,
            isRunning: isRunning,
            presetName: presetName,
            duration: duration
        )
        send(response)
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let state = activationState.rawValue
        log.debug("activation completed - state=\(state), error=\(error?.localizedDescription ?? "nil")")
        Task { @MainActor in
            if activationState == .activated {
                syncPreferences()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        log.debug("session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        log.debug("session deactivated - reactivating")
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: message) else { return }
        log.debug("received message from Watch: \(String(describing: watchMessage))")
        Task { @MainActor in
            onWatchTimerEvent?(watchMessage)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: userInfo) else { return }
        log.debug("received userInfo from Watch: \(String(describing: watchMessage))")
        Task { @MainActor in
            onWatchTimerEvent?(watchMessage)
        }
    }
}
