import AVFoundation
import WatchKit

/// Records audio on Apple Watch. Background recording is kept alive by the
/// `WKBackgroundModes: audio` plist entry combined with an active AVAudioSession.
/// No WKExtendedRuntimeSession is used — the audio session alone is sufficient
/// and avoids session-expiration interruptions.
final class WatchRecordingService: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isRecording = false
    @Published var recordingStartDate: Date?
    @Published var micPermissionDenied = false

    private var audioRecorder: AVAudioRecorder?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override init() {
        super.init()
        observeInterruptions()
    }

    func startRecording() {
        // Check mic permission first
        let permStatus = AVAudioApplication.shared.recordPermission
        if permStatus == .denied {
            print("[WatchRecording] Microphone permission DENIED")
            DispatchQueue.main.async { self.micPermissionDenied = true }
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            // Use .record category (same as working iPhone version).
            // WKBackgroundModes:audio keeps the app alive as long as the
            // session is active — .record category is sufficient.
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            print("[WatchRecording] Audio session active (.record/.default)")
        } catch {
            print("[WatchRecording] Audio session error: \(error)")
            return
        }

        let fileName = "watch_\(UUID().uuidString).m4a"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true

            guard recorder.record() else {
                print("[WatchRecording] record() returned false — mic may not be available")
                return
            }

            audioRecorder = recorder
            isRecording = true
            recordingStartDate = Date()
            print("[WatchRecording] Recording started: \(fileName)")

            // Log audio levels after a short delay to verify mic is capturing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, let rec = self.audioRecorder, rec.isRecording else { return }
                rec.updateMeters()
                let avg = rec.averagePower(forChannel: 0)
                let peak = rec.peakPower(forChannel: 0)
                print("[WatchRecording] Audio levels after 1.5s — avg: \(String(format: "%.1f", avg))dB, peak: \(String(format: "%.1f", peak))dB")
                if avg < -50 {
                    print("[WatchRecording] WARNING: Very low audio level — mic may not be capturing properly")
                }
            }
        } catch {
            print("[WatchRecording] Recording error: \(error)")
        }
    }

    func stopRecording() -> URL? {
        guard let recorder = audioRecorder else { return nil }

        // Log final audio levels
        recorder.updateMeters()
        let avgLevel = recorder.averagePower(forChannel: 0)
        print("[WatchRecording] Final audio level: \(String(format: "%.1f", avgLevel))dB")

        let url = recorder.url
        let duration = recorder.currentTime
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        recordingStartDate = nil

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            print("[WatchRecording] Stopped. Duration: \(String(format: "%.1f", duration))s, file size: \(size) bytes")
            if size < 1000 {
                print("[WatchRecording] WARNING: File suspiciously small — recording may have been interrupted")
            }
        } else {
            print("[WatchRecording] WARNING: Could not read file attributes for \(url.lastPathComponent)")
        }

        try? AVAudioSession.sharedInstance().setActive(false)
        return url
    }

    // MARK: - Audio Interruption Handling

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print("[WatchRecording] Audio session interrupted")
        case .ended:
            print("[WatchRecording] Interruption ended")
            // Re-activate session and resume recording
            do {
                try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                audioRecorder?.record()
                print("[WatchRecording] Recording resumed after interruption")
            } catch {
                print("[WatchRecording] Failed to resume: \(error)")
            }
        @unknown default:
            break
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension WatchRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("[WatchRecording] Recorder finished, success: \(flag)")
        if !flag {
            DispatchQueue.main.async {
                self.isRecording = false
                self.recordingStartDate = nil
            }
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        print("[WatchRecording] Encode error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStartDate = nil
        }
    }
}
