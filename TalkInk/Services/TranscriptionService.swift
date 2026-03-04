import Speech
import Combine
import AVFoundation

/// Handles speech-to-text transcription using Apple's Speech framework.
/// iOS 26+: Uses SpeechAnalyzer (no duration limit, 2x faster, fully on-device).
/// iOS 18-25: Falls back to SFSpeechRecognizer with audio chunking.
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

    // MARK: - Main Entry Point

    /// Transcribe a recording of any length.
    /// iOS 26+: SpeechAnalyzer handles any duration natively.
    /// Older iOS: Splits into 55s chunks for SFSpeechRecognizer's ~1 min limit.
    func transcribeLongAudio(
        audioURL: URL,
        chunkDuration: TimeInterval = 55
    ) async throws -> (String, [TranscriptSegment]) {
        await MainActor.run {
            isTranscribing = true
            progress = 0
            currentTranscript = ""
        }

        defer {
            Task { @MainActor in
                isTranscribing = false
                progress = 1.0
            }
        }

        // Log audio file info
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let size = attrs[.size] as? Int {
            print("[Transcription] File: \(audioURL.lastPathComponent), size: \(size) bytes")
        }

        // iOS 26+: Use SpeechAnalyzer — no duration limit, faster, fully on-device
        if #available(iOS 26, *) {
            do {
                print("[Transcription] Using SpeechAnalyzer (iOS 26+)")
                let result = try await transcribeWithSpeechAnalyzer(audioURL: audioURL)
                print("[Transcription] SpeechAnalyzer complete: \(result.1.count) segments, \(result.0.count) chars")
                await MainActor.run { currentTranscript = result.0 }
                return result
            } catch {
                print("[Transcription] SpeechAnalyzer failed: \(error.localizedDescription), falling back to SFSpeechRecognizer")
            }
        }

        // Fallback: SFSpeechRecognizer with chunking
        return try await transcribeWithLegacyRecognizer(audioURL: audioURL, chunkDuration: chunkDuration)
    }

    // MARK: - iOS 26+ SpeechAnalyzer

    /// Transcribe using the new SpeechAnalyzer API (iOS 26+).
    /// No duration limit. Processes the entire file at once, on-device.
    @available(iOS 26, *)
    private func transcribeWithSpeechAnalyzer(audioURL: URL) async throws -> (String, [TranscriptSegment]) {
        let locale = Locale(identifier: "en-US")
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        // Ensure the on-device speech model is downloaded
        try await Self.ensureSpeechModel(for: transcriber, locale: locale)

        let audioFile = try AVAudioFile(forReading: audioURL)

        // Start collecting results before creating the analyzer
        async let results = Self.collectSpeechAnalyzerResults(from: transcriber)

        // Create analyzer and start processing — finishAfterFile auto-finalizes
        let _ = try await SpeechAnalyzer(
            inputAudioFile: audioFile,
            modules: [transcriber],
            finishAfterFile: true
        )

        let (text, segments) = try await results

        guard !text.isEmpty else {
            throw TranscriptionError.recognizerUnavailable
        }

        return (text, segments)
    }

    /// Collect transcription results from a SpeechTranscriber's async sequence.
    /// Static to avoid capturing `self` in concurrent contexts.
    @available(iOS 26, *)
    private static func collectSpeechAnalyzerResults(
        from transcriber: SpeechTranscriber
    ) async throws -> (String, [TranscriptSegment]) {
        var allText = ""
        var segments: [TranscriptSegment] = []

        for try await result in transcriber.results {
            guard result.isFinal else { continue }
            let chunk = String(result.text.characters)
            guard !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            allText += allText.isEmpty ? chunk : " " + chunk

            // Use the result's time range for accurate timestamps
            let timestamp = result.range.start.seconds

            segments.append(TranscriptSegment(timestamp: timestamp, text: chunk))
        }

        return (allText, segments)
    }

    /// Ensure the speech model for a locale is downloaded on-device.
    @available(iOS 26, *)
    private static func ensureSpeechModel(
        for transcriber: SpeechTranscriber,
        locale: Locale
    ) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            print("[Transcription] Locale \(locale.identifier) not supported by SpeechTranscriber")
            throw TranscriptionError.recognizerUnavailable
        }

        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            print("[Transcription] Speech model for \(locale.identifier) already installed")
            return
        }

        print("[Transcription] Downloading speech model for \(locale.identifier)...")
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await downloader.downloadAndInstall()
        }
        print("[Transcription] Speech model download complete")
    }

    // MARK: - Legacy SFSpeechRecognizer (iOS 18-25 fallback)

    /// Transcribe using SFSpeechRecognizer with audio chunking for long files.
    private func transcribeWithLegacyRecognizer(
        audioURL: URL,
        chunkDuration: TimeInterval
    ) async throws -> (String, [TranscriptSegment]) {
        // Determine audio duration
        var totalSeconds: TimeInterval = 0
        do {
            let asset = AVURLAsset(url: audioURL)
            let dur = try await asset.load(.duration)
            totalSeconds = dur.seconds
        } catch {
            print("[Transcription] AVURLAsset duration failed: \(error.localizedDescription)")
        }

        if !totalSeconds.isFinite || totalSeconds <= 0 {
            do {
                let audioFile = try AVAudioFile(forReading: audioURL)
                totalSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                print("[Transcription] Duration from AVAudioFile: \(String(format: "%.1f", totalSeconds))s")
            } catch {
                print("[Transcription] AVAudioFile duration failed: \(error.localizedDescription)")
            }
        }

        if !totalSeconds.isFinite || totalSeconds <= 0 {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
               let size = attrs[.size] as? Int {
                totalSeconds = Double(size) / 12_000.0
                print("[Transcription] Estimated from file size: \(String(format: "%.0f", totalSeconds))s")
            }
        }

        print("[Transcription] Using SFSpeechRecognizer, duration: \(String(format: "%.1f", totalSeconds))s")

        // Short audio — transcribe directly
        if totalSeconds > 0 && totalSeconds <= chunkDuration + 5 {
            return try await transcribeSingleFile(audioURL: audioURL)
        }

        // Unknown duration — try single-file
        if totalSeconds <= 0 {
            print("[Transcription] WARNING: Unknown duration, trying single-file")
            return try await transcribeSingleFile(audioURL: audioURL)
        }

        // Long audio — chunk and transcribe
        do {
            return try await transcribeWithAudioFileChunking(
                audioURL: audioURL,
                totalSeconds: totalSeconds,
                chunkDuration: chunkDuration
            )
        } catch {
            print("[Transcription] Chunking failed, falling back to single-file")
            return try await transcribeSingleFile(audioURL: audioURL)
        }
    }

    /// Transcribe a single audio file (≤ ~1 minute) using SFSpeechRecognizer.
    private func transcribeSingleFile(
        audioURL: URL,
        onDevice: Bool? = nil
    ) async throws -> (String, [TranscriptSegment]) {
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        let useOnDevice = onDevice ?? recognizer.supportsOnDeviceRecognition
        request.requiresOnDeviceRecognition = useOnDevice
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        let timeoutSeconds: TimeInterval = useOnDevice ? 90 : 120
        let args = UncheckedSendableBox(value: (recognizer, request, timeoutSeconds))

        return try await withThrowingTaskGroup(of: (String, [TranscriptSegment]).self) { group in
            group.addTask {
                try await Self.performRecognition(
                    recognizer: args.value.0,
                    request: args.value.1
                )
            }

            group.addTask {
                try await Task.sleep(for: .seconds(args.value.2))
                throw TranscriptionError.timeout
            }

            guard let result = try await group.next() else {
                throw TranscriptionError.recognizerUnavailable
            }
            group.cancelAll()
            return result
        }
    }

    /// Perform SFSpeechRecognizer recognition with proper continuation handling.
    private static func performRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechRecognitionRequest
    ) async throws -> (String, [TranscriptSegment]) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, [TranscriptSegment]), Error>) in
            var bestText = ""
            var bestSegments: [TranscriptSegment] = []
            var hasResumed = false

            recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    bestText = result.bestTranscription.formattedString
                    bestSegments = result.bestTranscription.segments.map { seg in
                        TranscriptSegment(timestamp: seg.timestamp, text: seg.substring)
                    }

                    if result.isFinal, !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: (bestText, bestSegments))
                    }
                }

                if let error {
                    guard !hasResumed else { return }
                    hasResumed = true
                    if !bestText.isEmpty {
                        print("[Transcription] Error after partial results: \(error.localizedDescription)")
                        continuation.resume(returning: (bestText, bestSegments))
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Chunk audio using AVAudioFile and transcribe each piece sequentially.
    private func transcribeWithAudioFileChunking(
        audioURL: URL,
        totalSeconds: TimeInterval,
        chunkDuration: TimeInterval
    ) async throws -> (String, [TranscriptSegment]) {
        let sourceFile = try AVAudioFile(forReading: audioURL)
        let format = sourceFile.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = format.channelCount
        let totalFrames = AVAudioFrameCount(sourceFile.length)
        let framesPerChunk = AVAudioFrameCount(chunkDuration * sampleRate)

        let wavSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let chunkCount = Int(ceil(Double(totalFrames) / Double(framesPerChunk)))
        print("[Transcription] Chunking: \(chunkCount) chunks × \(Int(chunkDuration))s")

        var allText = ""
        var allSegments: [TranscriptSegment] = []
        var frameOffset: AVAudioFramePosition = 0
        var successCount = 0
        var failCount = 0

        for chunkIndex in 1...chunkCount {
            let remainingFrames = AVAudioFrameCount(sourceFile.length - frameOffset)
            let framesToRead = min(framesPerChunk, remainingFrames)
            guard framesToRead > 0 else { break }

            let chunkURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("talkink_chunk_\(chunkIndex)_\(UUID().uuidString).wav")

            defer { try? FileManager.default.removeItem(at: chunkURL) }

            do {
                sourceFile.framePosition = frameOffset
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                    frameOffset += AVAudioFramePosition(framesToRead)
                    failCount += 1
                    continue
                }
                try sourceFile.read(into: buffer, frameCount: framesToRead)

                let chunkFile = try AVAudioFile(forWriting: chunkURL, settings: wavSettings)
                try chunkFile.write(from: buffer)

                // Delay between chunks to let the recognizer reset
                if chunkIndex > 1 {
                    try await Task.sleep(for: .seconds(3))
                }

                // Transcribe this chunk
                var chunkText = ""
                var chunkSegments: [TranscriptSegment] = []

                do {
                    (chunkText, chunkSegments) = try await transcribeSingleFile(
                        audioURL: chunkURL, onDevice: true
                    )
                } catch {
                    print("[Transcription] Chunk \(chunkIndex) on-device failed, retrying with server...")
                    try await Task.sleep(for: .seconds(2))
                    do {
                        (chunkText, chunkSegments) = try await transcribeSingleFile(
                            audioURL: chunkURL, onDevice: false
                        )
                    } catch {
                        print("[Transcription] Chunk \(chunkIndex) server also failed: \(error.localizedDescription)")
                    }
                }

                if !chunkText.isEmpty {
                    allText += allText.isEmpty ? chunkText : "\n\n" + chunkText
                    successCount += 1
                } else {
                    failCount += 1
                }

                let currentStart = Double(frameOffset) / sampleRate
                let adjusted = chunkSegments.map { seg in
                    TranscriptSegment(timestamp: seg.timestamp + currentStart, text: seg.text, speaker: seg.speaker)
                }
                allSegments.append(contentsOf: adjusted)

            } catch {
                print("[Transcription] Chunk \(chunkIndex) FAILED: \(error.localizedDescription)")
                failCount += 1
            }

            frameOffset += AVAudioFramePosition(framesToRead)

            let pct = Double(chunkIndex) / Double(chunkCount)
            await MainActor.run {
                progress = pct
                currentTranscript = allText
            }
        }

        print("[Transcription] Done: \(successCount)/\(chunkCount) succeeded, \(allText.split(separator: " ").count) words")

        guard !allText.isEmpty else {
            throw TranscriptionError.recognizerUnavailable
        }

        await MainActor.run { currentTranscript = allText }
        return (allText, allSegments)
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case authorizationDenied
    case timeout

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .authorizationDenied:
            return "Speech recognition permission was denied."
        case .timeout:
            return "Speech recognition timed out."
        }
    }
}

/// Wraps a non-Sendable value so it can be captured in `sending` closures.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}
