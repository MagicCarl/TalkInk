import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var recordingService: RecordingService
    @EnvironmentObject var transcriptionService: TranscriptionService
    @EnvironmentObject var meetingStore: MeetingStore

    @State private var currentAudioURL: URL?
    @State private var showingResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Waveform visualization
                waveformCircle

                // Duration
                if recordingService.isRecording {
                    Text(formatDuration(recordingService.recordingDuration))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(.primary)
                } else {
                    Text("Ready to Record")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Record button
                recordButton

                // Source indicator
                Text("Recording from iPhone mic")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Record")
        }
    }

    private var waveformCircle: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(recordingService.isRecording ? Color.red.opacity(0.3) : Color.accent.opacity(0.2), lineWidth: 3)
                .frame(width: 200, height: 200)
                .scaleEffect(recordingService.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recordingService.isRecording)

            // Inner circle
            Circle()
                .fill(recordingService.isRecording ? Color.red.opacity(0.15) : Color.accent.opacity(0.1))
                .frame(width: 180, height: 180)

            // Mic icon
            Image(systemName: recordingService.isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(recordingService.isRecording ? .red : .accent)
                .symbolEffect(.variableColor, isActive: recordingService.isRecording)
        }
    }

    private var recordButton: some View {
        Button {
            if recordingService.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: recordingService.isRecording ? "stop.fill" : "record.circle")
                Text(recordingService.isRecording ? "Stop" : "Start Recording")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(recordingService.isRecording ? Color.red : Color.accent)
            )
        }
        .padding(.horizontal, 40)
    }

    private func startRecording() {
        currentAudioURL = recordingService.startRecording()
    }

    private func stopRecording() {
        guard let url = recordingService.stopRecording() else { return }

        var meeting = Meeting(
            title: "Meeting \(meetingStore.meetings.count + 1)",
            duration: recordingService.recordingDuration,
            source: .iPhone,
            status: .transcribing
        )
        meeting.audioFileName = url.lastPathComponent
        meetingStore.addMeeting(meeting)

        // Start transcription pipeline
        Task {
            do {
                let (transcript, segments) = try await transcriptionService.transcribe(audioURL: url)
                meeting.transcript = transcript
                meeting.segments = segments
                meeting.status = .ready
                meetingStore.updateMeeting(meeting)
            } catch {
                meeting.status = .failed
                meetingStore.updateMeeting(meeting)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingView()
        .environmentObject(RecordingService())
        .environmentObject(TranscriptionService())
        .environmentObject(MeetingStore())
}
