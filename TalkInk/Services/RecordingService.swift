import AVFoundation
import Combine

/// Handles audio recording on iPhone using AVAudioRecorder.
final class RecordingService: ObservableObject, @unchecked Sendable {
    @Published var isRecording = false
    @Published var recordingStartDate: Date?
    @Published var audioLevel: Float = -160

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Convenience: current duration computed from start date.
    var recordingDuration: TimeInterval {
        guard let start = recordingStartDate else { return 0 }
        return Date().timeIntervalSince(start)
    }

    func startRecording() -> URL? {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
            return nil
        }

        let fileName = "meeting_\(UUID().uuidString).m4a"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingStartDate = Date()
            startLevelTimer()

            return fileURL
        } catch {
            print("Failed to start recording: \(error)")
            return nil
        }
    }

    func stopRecording() -> URL? {
        let url = audioRecorder?.url
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopLevelTimer()
        recordingStartDate = nil

        try? AVAudioSession.sharedInstance().setActive(false)

        return url
    }

    /// Timer only for audio level metering (visual feedback), NOT for duration.
    /// Reduced to 0.5s and only publishes when level changes meaningfully
    /// to avoid overwhelming SwiftUI with redraws.
    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let rec = self.audioRecorder else { return }
            rec.updateMeters()
            let level = rec.averagePower(forChannel: 0)
            // Only publish if level changed by more than 3dB to reduce redraws
            if abs(level - self.audioLevel) > 3 {
                self.audioLevel = level
            }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = -160
    }
}
