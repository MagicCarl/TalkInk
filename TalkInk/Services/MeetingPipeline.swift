import Foundation
import AVFoundation
import Speech

/// Orchestrates the full meeting pipeline: audio → transcription → AI summary → storage.
/// Central coordinator that connects RecordingService, TranscriptionService, AISummaryService, and MeetingStore.
@MainActor
final class MeetingPipeline: ObservableObject {
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
        if #available(iOS 17.0, *) {
            let micStatus = AVAudioApplication.shared.recordPermission
            switch micStatus {
            case .granted:
                micPermission = .granted
            case .denied:
                micPermission = .denied
            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                micPermission = granted ? .granted : .denied
            @unknown default:
                micPermission = .unknown
            }
        }

        // Speech recognition
        let speechGranted = await transcriptionService.requestAuthorization()
        speechPermission = speechGranted ? .granted : .denied

        permissionsGranted = micPermission == .granted && speechPermission == .granted
    }

    // MARK: - Pipeline

    /// Process an audio file through the full pipeline: transcribe → summarize → store.
    func processAudio(meetingID: UUID, audioURL: URL) async {
        // Step 1: Transcribe
        updateMeetingStatus(id: meetingID, status: .transcribing)

        do {
            let (transcript, segments) = try await transcriptionService.transcribe(audioURL: audioURL)

            // Update with transcript
            if var meeting = meetingStore.meetings.first(where: { $0.id == meetingID }) {
                meeting.transcript = transcript
                meeting.segments = segments
                meeting.status = .summarizing
                meetingStore.updateMeeting(meeting)

                // Step 2: AI summarize
                let notes = try await summaryService.generateNotes(from: transcript)

                meeting.summary = notes.summary
                meeting.keyPoints = notes.keyPoints
                meeting.actionItems = notes.actionItems
                meeting.status = .ready

                // Auto-generate title from first sentence of transcript
                let autoTitle = generateTitle(from: transcript)
                if !autoTitle.isEmpty {
                    meeting.title = autoTitle
                }

                meetingStore.updateMeeting(meeting)
            }
        } catch {
            print("Pipeline error: \(error)")
            updateMeetingStatus(id: meetingID, status: .failed)
        }
    }

    /// Process audio received from Apple Watch.
    func processWatchAudio(audioURL: URL) async {
        var meeting = Meeting(
            title: "Watch Recording",
            date: Date(),
            duration: 0, // Will be updated after transcription
            source: .appleWatch,
            status: .transcribing
        )
        meeting.audioFileName = audioURL.lastPathComponent
        meetingStore.addMeeting(meeting)

        await processAudio(meetingID: meeting.id, audioURL: audioURL)
    }

    // MARK: - Helpers

    private func updateMeetingStatus(id: UUID, status: MeetingStatus) {
        if var meeting = meetingStore.meetings.first(where: { $0.id == id }) {
            meeting.status = status
            meetingStore.updateMeeting(meeting)
        }
    }

    private func generateTitle(from transcript: String) -> String {
        // Use first meaningful sentence as title (up to 40 chars)
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        let firstSentence = cleaned.components(separatedBy: ". ").first ?? cleaned
        let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= 40 {
            return trimmed
        }
        // Truncate at word boundary
        let truncated = String(trimmed.prefix(40))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        return truncated + "..."
    }
}
