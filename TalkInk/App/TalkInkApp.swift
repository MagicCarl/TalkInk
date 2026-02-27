import SwiftUI

@main
struct TalkInkApp: App {
    @StateObject private var recordingService = RecordingService()
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var summaryService = AISummaryService()
    @StateObject private var meetingStore = MeetingStore()
    @StateObject private var phoneSessionManager = PhoneSessionManager()
    @StateObject private var pipeline: MeetingPipeline

    init() {
        let transcription = TranscriptionService()
        let summary = AISummaryService()
        let store = MeetingStore()
        let pipe = MeetingPipeline(
            transcriptionService: transcription,
            summaryService: summary,
            meetingStore: store
        )

        _transcriptionService = StateObject(wrappedValue: transcription)
        _summaryService = StateObject(wrappedValue: summary)
        _meetingStore = StateObject(wrappedValue: store)
        _pipeline = StateObject(wrappedValue: pipe)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingService)
                .environmentObject(transcriptionService)
                .environmentObject(meetingStore)
                .environmentObject(phoneSessionManager)
                .environmentObject(pipeline)
                .preferredColorScheme(.dark)
                .task {
                    await pipeline.checkPermissions()
                    setupWatchAudioHandler()
                }
        }
    }

    private func setupWatchAudioHandler() {
        phoneSessionManager.onAudioReceived = { [pipeline] url in
            Task { @MainActor in
                await pipeline.processWatchAudio(audioURL: url)
            }
        }
    }
}
