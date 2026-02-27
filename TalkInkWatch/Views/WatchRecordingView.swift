import SwiftUI

struct WatchRecordingView: View {
    @EnvironmentObject var recordingService: WatchRecordingService
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        VStack(spacing: 12) {
            // Status icon
            Image(systemName: recordingService.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(recordingService.isRecording ? .red : Color.accentColor)
                .symbolEffect(.variableColor, isActive: recordingService.isRecording)

            // Duration or status
            if recordingService.isRecording {
                Text(formatDuration(recordingService.duration))
                    .font(.system(.title3, design: .monospaced))
            } else if sessionManager.isTransferring {
                ProgressView()
                Text("Sending...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to Record")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Record/Stop button
            Button {
                if recordingService.isRecording {
                    stopAndTransfer()
                } else {
                    recordingService.startRecording()
                }
            } label: {
                Image(systemName: recordingService.isRecording ? "stop.fill" : "record.circle.fill")
                    .font(.title2)
                    .foregroundStyle(recordingService.isRecording ? .red : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(sessionManager.isTransferring)
        }
        .navigationTitle("TalkInk")
    }

    private func stopAndTransfer() {
        guard let url = recordingService.stopRecording() else { return }
        sessionManager.transferAudio(url: url)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
