import Foundation
import AVFoundation
import Speech

/// Orchestrates the full meeting pipeline: audio → transcription → AI summary → storage.
/// Central coordinator that connects RecordingService, TranscriptionService, AISummaryService, and MeetingStore.
final class MeetingPipeline: ObservableObject, @unchecked Sendable {
    @Published var permissionsGranted = false
    @Published var micPermission: PermissionStatus = .unknown
    @Published var speechPermission: PermissionStatus = .unknown

    private let transcriptionService: TranscriptionService
    private let summaryService: AISummaryService
    private let meetingStore: MeetingStore

    enum PermissionStatus {
        case unknown, granted, denied
    }

    init(transcriptionService: TranscriptionService, summaryService: AISummaryService, meetingStore: MeetingStore) {
        self.transcriptionService = transcriptionService
        self.summaryService = summaryService
        self.meetingStore = meetingStore
    }

    // MARK: - Permissions

    func checkPermissions() async {
        // Microphone
        var mic: PermissionStatus = .unknown
        let micStatus = AVAudioApplication.shared.recordPermission
        switch micStatus {
        case .granted:
            mic = .granted
        case .denied:
            mic = .denied
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            mic = granted ? .granted : .denied
        @unknown default:
            mic = .unknown
        }

        // Speech recognition
        let speechGranted = await transcriptionService.requestAuthorization()
        let speech: PermissionStatus = speechGranted ? .granted : .denied

        await MainActor.run {
            micPermission = mic
            speechPermission = speech
            permissionsGranted = mic == .granted && speech == .granted
        }
    }

    // MARK: - Pipeline

    /// Process an audio file through the full pipeline: transcribe → summarize → store.
    func processAudio(meetingID: UUID, audioURL: URL) async {
        // Step 1: Transcribe
        await updateMeetingStatus(id: meetingID, status: .transcribing)

        // Log audio file size for debugging watch transfer issues
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let size = attrs[.size] as? Int {
            print("[Pipeline] Audio file: \(audioURL.lastPathComponent), size: \(size) bytes")
        }

        do {
            // Get actual audio duration from file
            let asset = AVURLAsset(url: audioURL)
            let audioDuration = try await asset.load(.duration).seconds

            let (transcript, segments) = try await transcriptionService.transcribeLongAudio(audioURL: audioURL)
            print("[Pipeline] Transcription complete: \(segments.count) segments, \(transcript.count) chars")

            // Update with transcript and actual duration
            guard var meeting = await meetingStore.meetings.first(where: { $0.id == meetingID }) else { return }

            meeting.transcript = transcript
            meeting.segments = segments
            if audioDuration.isFinite && audioDuration > 0 {
                meeting.duration = audioDuration
            }
            meeting.status = .summarizing
            await meetingStore.updateMeeting(meeting)

            // Step 2: Generate structured notes
            let notes = try await summaryService.generateNotes(from: transcript)

            meeting.overview = notes.overview
            meeting.topics = notes.topics
            meeting.decisions = notes.decisions
            meeting.actionItems = notes.actionItems
            meeting.isAIGenerated = notes.isAIGenerated
            meeting.status = .ready

            // Also populate legacy fields for backward compatibility
            meeting.summary = notes.overview

            // Use AI-generated title if available, otherwise heuristic
            if let aiTitle = notes.title, !aiTitle.isEmpty {
                meeting.title = aiTitle
            } else {
                let autoTitle = generateTitle(from: transcript)
                if !autoTitle.isEmpty {
                    meeting.title = autoTitle
                }
            }

            await meetingStore.updateMeeting(meeting)
        } catch {
            print("[Pipeline] Error for meeting \(meetingID): \(error.localizedDescription)")
            await updateMeetingStatus(id: meetingID, status: .failed)
        }
    }

    /// Process audio received from Apple Watch.
    func processWatchAudio(audioURL: URL) async {
        var meeting = Meeting(
            title: "Watch Recording",
            date: Date(),
            duration: 0,
            source: .appleWatch,
            status: .transcribing
        )
        meeting.audioFileName = audioURL.lastPathComponent
        await meetingStore.addMeeting(meeting)

        await processAudio(meetingID: meeting.id, audioURL: audioURL)
    }

    /// Re-generate AI notes for a meeting that already has a transcript.
    func regenerateNotes(meetingID: UUID) async {
        guard var meeting = await meetingStore.meetings.first(where: { $0.id == meetingID }),
              let transcript = meeting.transcript, !transcript.isEmpty else { return }

        meeting.status = .summarizing
        await meetingStore.updateMeeting(meeting)

        do {
            let notes = try await summaryService.generateNotes(from: transcript)

            meeting.overview = notes.overview
            meeting.topics = notes.topics
            meeting.decisions = notes.decisions
            meeting.actionItems = notes.actionItems
            meeting.isAIGenerated = notes.isAIGenerated
            meeting.summary = notes.overview
            meeting.status = .ready

            if let aiTitle = notes.title, !aiTitle.isEmpty {
                meeting.title = aiTitle
            }

            await meetingStore.updateMeeting(meeting)
        } catch {
            print("[Pipeline] Regenerate failed: \(error.localizedDescription)")
            meeting.status = .ready
            await meetingStore.updateMeeting(meeting)
        }
    }

    // MARK: - Helpers

    private func updateMeetingStatus(id: UUID, status: MeetingStatus) async {
        if var meeting = await meetingStore.meetings.first(where: { $0.id == id }) {
            meeting.status = status
            await meetingStore.updateMeeting(meeting)
        }
    }

    private func generateTitle(from transcript: String) -> String {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        let firstSentence = cleaned.components(separatedBy: ". ").first ?? cleaned
        let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= 40 {
            return trimmed
        }
        let truncated = String(trimmed.prefix(40))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        return truncated + "..."
    }
}
