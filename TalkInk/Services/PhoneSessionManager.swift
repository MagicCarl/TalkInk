import WatchConnectivity
import Combine

/// Manages WatchConnectivity session on the iPhone side.
/// Receives audio files from Apple Watch and triggers transcription pipeline.
final class PhoneSessionManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isWatchReachable = false
    @Published var isTransferring = false
    @Published var lastReceivedFile: String?

    private var session: WCSession?
    var onAudioReceived: ((URL) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let wc = WCSession.default
            wc.delegate = self
            wc.activate()
            session = wc
        }
    }

    /// Send a message to the Watch (e.g., to start/stop recording).
    func sendCommand(_ command: String) {
        guard let session, session.isReachable else { return }
        session.sendMessage(["command": command], replyHandler: nil)
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        print("[PhoneSession] Activated: \(activationState.rawValue), reachable: \(reachable), error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.isWatchReachable = reachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[PhoneSession] Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[PhoneSession] Session deactivated, reactivating...")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        print("[PhoneSession] Reachability changed: \(reachable)")
        DispatchQueue.main.async {
            self.isWatchReachable = reachable
        }
    }

    /// Receive audio file transferred from Apple Watch.
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("[PhoneSession] Received file: \(file.fileURL.lastPathComponent)")
        print("[PhoneSession] Metadata: \(String(describing: file.metadata))")

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "watch_\(UUID().uuidString).m4a"
        let destURL = docs.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: file.fileURL, to: destURL)
            print("[PhoneSession] Saved audio to: \(destURL.lastPathComponent)")

            DispatchQueue.main.async {
                self.isTransferring = false
                self.lastReceivedFile = fileName
                self.onAudioReceived?(destURL)
            }
        } catch {
            print("[PhoneSession] Failed to save Watch audio: \(error)")
        }
    }
}
