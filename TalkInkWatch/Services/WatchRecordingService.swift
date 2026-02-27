import AVFoundation
import WatchKit

/// Records audio on Apple Watch using AVAudioRecorder with an extended runtime session
/// to keep recording when the wrist drops.
final class WatchRecordingService: ObservableObject, @unchecked Sendable {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var extendedSession: WKExtendedRuntimeSession?
    private var timer: Timer?
    private var startTime: Date?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("Watch audio session error: \(error)")
            return
        }

        // Start extended runtime session to keep recording when wrist drops
        startExtendedSession()

        let fileName = "watch_\(UUID().uuidString).m4a"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            startTime = Date()
            startTimer()
        } catch {
            print("Watch recording error: \(error)")
        }
    }

    func stopRecording() -> URL? {
        let url = audioRecorder?.url
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopTimer()
        stopExtendedSession()
        try? AVAudioSession.sharedInstance().setActive(false)
        return url
    }

    private func startExtendedSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.start()
    }

    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.startTime else { return }
            self.duration = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        duration = 0
    }
}
