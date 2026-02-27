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
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordingService())
        .environmentObject(TranscriptionService())
        .environmentObject(MeetingStore())
        .environmentObject(PhoneSessionManager())
}
