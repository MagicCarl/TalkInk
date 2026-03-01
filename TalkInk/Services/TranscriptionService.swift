import Speech
import Combine

/// Handles speech-to-text transcription using Apple's Speech framework.
/// Uses on-device recognition for privacy — no data leaves the device.
final class TranscriptionService: ObservableObject, @unchecked Sendable {
    @Published var isTranscribing = false
    @Published var progress: Double = 0
    @Published var currentTranscript = ""

    private var recognizer: SFSpeechRecognizer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Request speech recognition authorization.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe an audio file at the given URL.
    func transcribe(audioURL: URL) async throws -> (String, [TranscriptSegment]) {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        DispatchQueue.main.async { [self] in
            isTranscribing = true
            progress = 0
            currentTranscript = ""
        }

        defer {
            DispatchQueue.main.async { [self] in
                isTranscribing = false
                progress = 1.0
            }
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let (fullText, segments) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, [TranscriptSegment]), Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    let segs = result.bestTranscription.segments.map { seg in
                        TranscriptSegment(timestamp: seg.timestamp, text: seg.substring)
                    }
                    continuation.resume(returning: (text, segs))
                }
            }
        }

        DispatchQueue.main.async { [self] in currentTranscript = fullText }
        return (fullText, segments)
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .authorizationDenied:
            return "Speech recognition permission was denied."
        }
    }
}
