import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var phoneSessionManager: PhoneSessionManager

    @State private var showDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Watch connection
                Section("Apple Watch") {
                    HStack {
                        Image(systemName: "applewatch")
                            .foregroundStyle(Color.accentColor)
                        Text("Watch Status")
                        Spacer()
                        Text(watchStatusText)
                            .foregroundStyle(watchStatusColor)
                    }
                }

                // Transcription
                Section("Transcription") {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(Color.accentColor)
                        Text("Engine")
                        Spacer()
                        Text("Apple Speech (On-Device)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(Color.accentColor)
                        Text("Language")
                        Spacer()
                        Text("English")
                            .foregroundStyle(.secondary)
                    }
                }

                // Data
                Section("Data") {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(Color.accentColor)
                        Text("Total Meetings")
                        Spacer()
                        Text("\(meetingStore.meetings.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete All Meetings")
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("All data stays on device")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Meetings?", isPresented: $showDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    meetingStore.deleteAllMeetings()
                }
            } message: {
                Text("This will permanently delete all meetings, recordings, and transcripts. This cannot be undone.")
            }
        }
    }

    private var watchStatusText: String {
        if phoneSessionManager.isWatchPaired && phoneSessionManager.isWatchAppInstalled {
            return "Connected"
        } else if phoneSessionManager.isWatchPaired {
            return "Paired (App Not Installed)"
        } else {
            return "Not Paired"
        }
    }

    private var watchStatusColor: Color {
        if phoneSessionManager.isWatchPaired && phoneSessionManager.isWatchAppInstalled {
            return .green
        } else if phoneSessionManager.isWatchPaired {
            return .orange
        } else {
            return .secondary
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MeetingStore())
        .environmentObject(PhoneSessionManager())
}
