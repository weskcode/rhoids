import Foundation
import WatchConnectivity
import os.log

/// Manages Watch ↔ iPhone communication.
///
/// Receives synced preferences from iPhone via `applicationContext` and
/// exchanges real-time timer events via `sendMessage`/`transferUserInfo`.

private let log = Logger(subsystem: "com.wesley.RHOIDS.watch", category: "Connectivity")

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject, Sendable {

    private let session: WCSession

    /// Published so views can react to preference updates.
    @Published private(set) var lastSyncDate: Date?

    /// Callback for timer events received from the iPhone.
    var onPhoneTimerEvent: (@MainActor @Sendable (WatchMessage) -> Void)?

    override init() {
        self.session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
        log.debug("session activated")

        // Apply any previously received context on launch
        if !session.receivedApplicationContext.isEmpty {
            applyReceivedContext(session.receivedApplicationContext)
        }
    }

    // MARK: - Sending to iPhone

    /// Send a timer event to the iPhone.
    func send(_ message: WatchMessage) {
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
                log.error("sendMessage failed: \(error)")
            }
        } else {
            session.transferUserInfo(message.toDictionary())
            log.debug("iPhone not reachable - queued via transferUserInfo")
        }
    }

    /// Request the current timer state from the iPhone.
    func requestState() {
        send(.requestState)
    }

    // MARK: - Receiving Preferences

    private func applyReceivedContext(_ context: [String: Any]) {
        guard let prefs = SyncedPreferences.from(context: context) else {
            log.error("failed to decode preferences from context")
            return
        }
        prefs.applyToLocalDefaults()
        lastSyncDate = Date()
        log.debug("preferences applied from iPhone")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        log.debug("activation completed - state=\(activationState.rawValue), error=\(error?.localizedDescription ?? "nil")")
        Task { @MainActor in
            if activationState == .activated {
                // Request current state from phone on activation
                self.requestState()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        log.debug("received applicationContext from iPhone")
        // Decode on this thread to avoid sending non-Sendable dict across isolation boundary
        let prefs = SyncedPreferences.from(context: applicationContext)
        Task { @MainActor in
            if let prefs {
                prefs.applyToLocalDefaults()
                self.lastSyncDate = Date()
                log.debug("preferences applied from iPhone (delegate path)")
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: message) else { return }
        log.debug("received message from iPhone: \(String(describing: watchMessage))")
        Task { @MainActor in
            self.onPhoneTimerEvent?(watchMessage)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: userInfo) else { return }
        log.debug("received userInfo from iPhone: \(String(describing: watchMessage))")
        Task { @MainActor in
            self.onPhoneTimerEvent?(watchMessage)
        }
    }
}
