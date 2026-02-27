import WatchConnectivity
import Combine

/// Manages WatchConnectivity session on the iPhone side.
/// Receives audio files from Apple Watch and triggers transcription pipeline.
@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {
    @Published var isWatchReachable = false
    @Published var isTransferring = false

    private var session: WCSession?
    var onAudioReceived: ((URL) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Send a message to the Watch (e.g., to start/stop recording).
    func sendCommand(_ command: String) {
        guard let session, session.isReachable else { return }
        session.sendMessage(["command": command], replyHandler: nil)
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    /// Receive audio file transferred from Apple Watch.
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docs.appendingPathComponent(file.fileURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)

            Task { @MainActor in
                isTransferring = false
                onAudioReceived?(destURL)
            }
        } catch {
            print("Failed to receive Watch audio: \(error)")
        }
    }
}
