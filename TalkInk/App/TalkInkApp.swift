import SwiftUI

@main
struct TalkInkApp: App {
    @StateObject private var recordingService = RecordingService()
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var meetingStore = MeetingStore()
    @StateObject private var phoneSessionManager = PhoneSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingService)
                .environmentObject(transcriptionService)
                .environmentObject(meetingStore)
                .environmentObject(phoneSessionManager)
                .preferredColorScheme(.dark)
        }
    }
}
