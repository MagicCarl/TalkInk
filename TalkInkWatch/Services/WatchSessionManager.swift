import WatchConnectivity

/// Manages WatchConnectivity on the Watch side.
/// Transfers recorded audio files to the paired iPhone for transcription.
final class WatchSessionManager: NSObject, ObservableObject, @unchecked Sendable {
    @MainActor @Published var isTransferring = false
    @MainActor @Published var isPhoneReachable = false
    @MainActor @Published var transferError: String?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let wc = WCSession.default
            wc.delegate = self
            wc.activate()
            session = wc
        }
    }

    /// Transfer an audio file to the paired iPhone.
    @MainActor
    func transferAudio(url: URL) {
        guard let session else {
            print("[WatchSession] No session available")
            return
        }
        print("[WatchSession] Starting file transfer: \(url.lastPathComponent)")
        isTransferring = true
        transferError = nil
        session.transferFile(url, metadata: ["type": "meeting_audio"])
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        print("[WatchSession] Activated: \(activationState.rawValue), reachable: \(reachable), error: \(String(describing: error))")
        Task { @MainActor in
            self.isPhoneReachable = reachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        print("[WatchSession] Reachability changed: \(reachable)")
        Task { @MainActor in
            self.isPhoneReachable = reachable
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error {
            print("[WatchSession] Transfer FAILED: \(error)")
        } else {
            print("[WatchSession] Transfer completed successfully")
        }
        Task { @MainActor in
            self.isTransferring = false
            if let error {
                self.transferError = error.localizedDescription
            }
        }
    }
}
