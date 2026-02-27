import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }

            TranscriptsListView()
                .tabItem {
                    Label("Notes", systemImage: "doc.text.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    let store = MeetingStore()
    ContentView()
        .environmentObject(RecordingService())
        .environmentObject(TranscriptionService())
        .environmentObject(store)
        .environmentObject(PhoneSessionManager())
        .environmentObject(MeetingPipeline(
            transcriptionService: TranscriptionService(),
            summaryService: AISummaryService(),
            meetingStore: store
        ))
}
