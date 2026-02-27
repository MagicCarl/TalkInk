import SwiftUI

@main
struct TalkInkWatchApp: App {
    @StateObject private var watchRecordingService = WatchRecordingService()
    @StateObject private var watchSessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchRecordingView()
                .environmentObject(watchRecordingService)
                .environmentObject(watchSessionManager)
        }
    }
}
