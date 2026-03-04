import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var recordingService: RecordingService
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var pipeline: MeetingPipeline

    @State private var currentMeetingID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if !pipeline.permissionsGranted {
                    permissionPrompt
                } else {
                    // Waveform visualization
                    waveformCircle

                    // Duration or processing state
                    if recordingService.isRecording {
                        // TimelineView updates every second independent of main thread
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            if let start = recordingService.recordingStartDate {
                                Text(formatDuration(context.date.timeIntervalSince(start)))
                                    .font(.system(size: 48, weight: .light, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                        }

                        audioLevelBar
                    } else if let id = currentMeetingID,
                              let meeting = meetingStore.meetings.first(where: { $0.id == id }),
                              meeting.status != .ready && meeting.status != .failed {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(meeting.status.label)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Ready to Record")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    // Record button
                    recordButton

                    Text(recordingService.isRecording ? "Recording from iPhone mic..." : "Tap to start recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Record")
        }
    }

    // MARK: - Permission Prompt

    private var permissionPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Permissions Required")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(icon: "mic.fill", label: "Microphone", status: pipeline.micPermission)
                permissionRow(icon: "waveform", label: "Speech Recognition", status: pipeline.speechPermission)
            }

            Text("TalkInk needs microphone access to record and speech recognition to transcribe your meetings. All processing happens on-device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Access") {
                Task { await pipeline.checkPermissions() }
            }
            .buttonStyle(.borderedProminent)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption)
        }
        .padding()
    }

    private func permissionRow(icon: String, label: String, status: MeetingPipeline.PermissionStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.subheadline)
            Spacer()
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .unknown:
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Recording UI

    private var waveformCircle: some View {
        ZStack {
            Circle()
                .stroke(recordingService.isRecording ? Color.red.opacity(0.3) : Color.accentColor.opacity(0.2), lineWidth: 3)
                .frame(width: 200, height: 200)
                .scaleEffect(recordingService.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recordingService.isRecording)

            Circle()
                .fill(recordingService.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.1))
                .frame(width: 180, height: 180)

            Image(systemName: recordingService.isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(recordingService.isRecording ? .red : Color.accentColor)
                .symbolEffect(.variableColor, isActive: recordingService.isRecording)
        }
    }

    private var audioLevelBar: some View {
        let normalized = max(0, min(1, (recordingService.audioLevel + 50) / 50))
        return GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.red.opacity(0.3))
                .frame(width: geo.size.width, height: 8)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: geo.size.width * CGFloat(normalized), height: 8)
                        .animation(.linear(duration: 0.1), value: normalized)
                }
        }
        .frame(height: 8)
        .padding(.horizontal, 40)
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
                Capsule().fill(recordingService.isRecording ? Color.red : Color.accentColor)
            )
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    private func startRecording() {
        currentMeetingID = nil
        _ = recordingService.startRecording()
    }

    private func stopRecording() {
        // Capture duration BEFORE stopRecording() zeroes it
        let recordedDuration = recordingService.recordingDuration
        guard let url = recordingService.stopRecording() else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, h:mm a"

        var meeting = Meeting(
            title: "Meeting - \(dateFormatter.string(from: Date()))",
            duration: recordedDuration,
            source: .iPhone,
            status: .transcribing
        )
        meeting.audioFileName = url.lastPathComponent
        meetingStore.addMeeting(meeting)
        currentMeetingID = meeting.id

        Task {
            await pipeline.processAudio(meetingID: meeting.id, audioURL: url)
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
        .environmentObject(MeetingStore())
        .environmentObject(MeetingPipeline(
            transcriptionService: TranscriptionService(),
            summaryService: AISummaryService(),
            meetingStore: MeetingStore()
        ))
}
