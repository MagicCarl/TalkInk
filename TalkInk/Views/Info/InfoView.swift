import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Welcome
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Welcome to TalkInk", systemImage: "waveform.circle.fill")
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)

                        Text("TalkInk records your meetings, transcribes them on-device, and organizes everything into searchable notes with summaries and action items.")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Getting Started
                    infoSection(
                        icon: "arrow.right.circle.fill",
                        title: "Getting Started",
                        steps: [
                            "Open TalkInk on your iPhone and grant microphone and speech recognition permissions when prompted.",
                            "Install TalkInk on your Apple Watch — it installs automatically when the iPhone app is set up.",
                            "That's it! You can now record from either device."
                        ]
                    )

                    Divider()

                    // Recording on iPhone
                    infoSection(
                        icon: "iphone.gen3",
                        title: "Recording on iPhone",
                        steps: [
                            "Go to the Record tab and tap \"Start Recording\".",
                            "Speak naturally — TalkInk captures audio using the iPhone microphone.",
                            "Tap \"Stop\" when finished. The app will automatically transcribe your recording and generate a summary.",
                            "Find your completed notes in the Notes tab."
                        ]
                    )

                    Divider()

                    // Recording on Apple Watch
                    infoSection(
                        icon: "applewatch",
                        title: "Recording on Apple Watch",
                        steps: [
                            "Open TalkInk on your Apple Watch and tap the red record button.",
                            "The watch records using its built-in microphone — you can lower your wrist and it keeps recording.",
                            "Tap the stop button when done. The recording transfers to your iPhone automatically.",
                            "Your iPhone transcribes and summarizes the audio — check the Notes tab for results."
                        ]
                    )

                    Divider()

                    // Viewing Notes
                    infoSection(
                        icon: "doc.text.fill",
                        title: "Viewing Your Notes",
                        steps: [
                            "Go to the Notes tab to see all your meetings.",
                            "Tap any meeting to view its Summary, full Transcript, and Action Items.",
                            "Use the share button to export your notes to other apps.",
                            "Swipe left on a meeting to delete it."
                        ]
                    )

                    Divider()

                    // What Are Action Items
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What Are Action Items?", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)

                        Text("Action Items are tasks or follow-ups that TalkInk detects from your conversation. When someone says things like \"we need to...\", \"let's follow up on...\", or \"the deadline is...\", TalkInk pulls those out and lists them separately so nothing falls through the cracks.")
                            .foregroundStyle(.secondary)

                        Text("Think of them as your meeting to-do list — automatically generated so you don't have to write anything down.")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Important Note
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Good to Know", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)

                        Text("Each device records independently. If you start recording on your iPhone, you stop it on your iPhone. If you start on your Apple Watch, you stop it on your Watch. You cannot start on one device and stop on the other.")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tips for Best Results", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)

                        tipRow(icon: "speaker.wave.2.fill", text: "Record in a quiet environment for clearer transcriptions.")
                        tipRow(icon: "person.wave.2.fill", text: "Speak clearly and at a normal pace.")
                        tipRow(icon: "wifi", text: "Keep your iPhone nearby when recording on Apple Watch for faster transfers.")
                        tipRow(icon: "clock.fill", text: "Longer recordings take more time to transcribe — be patient.")
                    }

                    Divider()

                    // Privacy
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Privacy", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        Text("TalkInk processes everything on your device. Your recordings, transcripts, and notes never leave your iPhone. No cloud. No servers. No accounts. Your meetings stay private.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Info")
        }
    }

    // MARK: - Components

    private func infoSection(icon: String, title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor)
                            .clipShape(Circle())

                        Text(step)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    InfoView()
}
