import WatchConnectivity

/// Manages WatchConnectivity on the Watch side.
/// Transfers recorded audio files to the paired iPhone for transcription.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    @Published var isTransferring = false
    @Published var isPhoneReachable = false

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Transfer an audio file to the paired iPhone.
    func transferAudio(url: URL) {
        guard let session else { return }
        isTransferring = true
        session.transferFile(url, metadata: ["type": "meeting_audio"])
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPhoneReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            isTransferring = false
            if let error {
                print("Watch file transfer failed: \(error)")
            }
        }
    }
}
