import SwiftUI

struct WatchRecordingView: View {
    @EnvironmentObject var recordingService: WatchRecordingService
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        VStack(spacing: 16) {
            if recordingService.isRecording {
                // Recording state: show duration + stop button
                Text(formatDuration(recordingService.duration))
                    .font(.system(.title2, design: .monospaced))

                Button {
                    stopAndTransfer()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if sessionManager.isTransferring {
                // Transferring state
                ProgressView()
                    .scaleEffect(1.2)
                Text("Sending to iPhone...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Idle state: show record button
                Text("Tap to Record")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    recordingService.startRecording()
                } label: {
                    Image(systemName: "record.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
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
