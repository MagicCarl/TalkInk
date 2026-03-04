import WatchConnectivity

/// Manages WatchConnectivity on the Watch side.
/// Transfers recorded audio files to the paired iPhone for transcription.
final class WatchSessionManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isTransferring = false
    @Published var isPhoneReachable = false
    @Published var transferError: String?

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
    func transferAudio(url: URL) {
        guard let session else {
            print("[WatchSession] No session available")
            return
        }
        // Log file size before transfer to verify recording captured audio
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            print("[WatchSession] Starting transfer: \(url.lastPathComponent), size: \(size) bytes")
            if size < 1000 {
                print("[WatchSession] WARNING: File very small — may be empty recording")
            }
        } else {
            print("[WatchSession] Starting transfer: \(url.lastPathComponent), size: UNKNOWN")
        }

        isTransferring = true
        transferError = nil
        session.transferFile(url, metadata: ["type": "meeting_audio"])
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        print("[WatchSession] Activated: \(activationState.rawValue), reachable: \(reachable), error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.isPhoneReachable = reachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        print("[WatchSession] Reachability changed: \(reachable)")
        DispatchQueue.main.async {
            self.isPhoneReachable = reachable
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let errorMsg = error?.localizedDescription
        if let error {
            print("[WatchSession] Transfer FAILED: \(error)")
        } else {
            print("[WatchSession] Transfer completed successfully")
        }
        DispatchQueue.main.async {
            self.isTransferring = false
            self.transferError = errorMsg
        }
    }
}
