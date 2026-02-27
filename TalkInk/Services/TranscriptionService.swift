import Speech
import Combine

/// Handles speech-to-text transcription using Apple's Speech framework.
/// Uses on-device recognition for privacy — no data leaves the device.
@MainActor
final class TranscriptionService: ObservableObject {
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

        isTranscribing = true
        progress = 0
        currentTranscript = ""

        defer {
            isTranscribing = false
            progress = 1.0
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }

        let fullText = result.bestTranscription.formattedString
        currentTranscript = fullText

        // Build segments from transcription segments
        var segments: [TranscriptSegment] = []
        for segment in result.bestTranscription.segments {
            segments.append(TranscriptSegment(
                timestamp: segment.timestamp,
                text: segment.substring
            ))
        }

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
