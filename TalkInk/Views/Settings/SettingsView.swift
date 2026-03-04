import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var phoneSessionManager: PhoneSessionManager

    @State private var showDeleteAllConfirmation = false
    @State private var apiKeyInput = ""
    @State private var hasAPIKey = false
    @State private var showAPIKeySaved = false
    @State private var developerTapCount = 0
    @State private var showDeveloperSection = false

    var body: some View {
        NavigationStack {
            List {
                // AI Notes
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)
                        Text("AI Notes")
                        Spacer()
                        if #available(iOS 26, *) {
                            Text("On-Device (Apple Intelligence)")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text(hasAPIKey ? "Claude API" : "Basic")
                                .font(.caption)
                                .foregroundStyle(hasAPIKey ? .green : .secondary)
                        }
                    }
                } header: {
                    Text("AI Summary")
                } footer: {
                    if #available(iOS 26, *) {
                        Text("Meeting notes are generated on-device using Apple Intelligence. Your data never leaves your device.")
                    } else {
                        Text("On iOS 26+, meeting notes are generated on-device using Apple Intelligence. On older iOS, basic keyword extraction is used.")
                    }
                }

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
                    .onTapGesture {
                        developerTapCount += 1
                        if developerTapCount >= 7 {
                            showDeveloperSection = true
                            developerTapCount = 0
                        }
                    }

                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text(hasAPIKey ? "Transcripts sent to Claude API" : "All data stays on device")
                            .foregroundStyle(.secondary)
                    }
                }

                // Developer section — hidden until unlocked by tapping Version 7 times
                if showDeveloperSection {
                    Section {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Status")
                            Spacer()
                            Text(hasAPIKey ? "Configured" : "Not Set")
                                .foregroundStyle(hasAPIKey ? .green : .secondary)
                        }

                        if hasAPIKey {
                            Button(role: .destructive) {
                                KeychainHelper.delete(key: "anthropic_api_key")
                                apiKeyInput = ""
                                hasAPIKey = false
                            } label: {
                                HStack {
                                    Image(systemName: "key.slash")
                                    Text("Remove API Key")
                                }
                            }
                        } else {
                            SecureField("sk-ant-...", text: $apiKeyInput)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Button {
                                let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                KeychainHelper.save(key: "anthropic_api_key", value: trimmed)
                                hasAPIKey = true
                                apiKeyInput = ""
                                showAPIKeySaved = true
                            } label: {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(Color.accentColor)
                                    Text("Save API Key")
                                }
                            }
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } header: {
                        Text("Developer")
                    } footer: {
                        Text("Claude API key for AI summarization. Overrides on-device AI when set. Get a key at console.anthropic.com")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                hasAPIKey = KeychainHelper.read(key: "anthropic_api_key") != nil
                // Auto-show developer section if key is already configured
                if hasAPIKey { showDeveloperSection = true }
            }
            .alert("API Key Saved", isPresented: $showAPIKeySaved) {
                Button("OK") {}
            } message: {
                Text("Claude API is now enabled. It will be used as a fallback if on-device AI is unavailable.")
            }
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
