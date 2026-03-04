import SwiftUI
import AVFoundation

struct WatchRecordingView: View {
    @EnvironmentObject var recordingService: WatchRecordingService
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        VStack(spacing: 16) {
            if recordingService.isRecording {
                // Use TimelineView so the elapsed time updates every second
                // even when the app returns from background (no Timer needed).
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let start = recordingService.recordingStartDate {
                        Text(formatDuration(context.date.timeIntervalSince(start)))
                            .font(.system(.title2, design: .monospaced))
                    }
                }

                Button {
                    stopAndTransfer()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if sessionManager.isTransferring {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Sending to iPhone...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if recordingService.micPermissionDenied {
                Image(systemName: "mic.slash.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text("Microphone access\ndenied in Settings")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap to Record")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    requestMicAndRecord()
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

    private func requestMicAndRecord() {
        let status = AVAudioApplication.shared.recordPermission
        if status == .undetermined {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        recordingService.startRecording()
                    } else {
                        recordingService.micPermissionDenied = true
                    }
                }
            }
        } else {
            recordingService.startRecording()
        }
    }

    private func stopAndTransfer() {
        guard let url = recordingService.stopRecording() else { return }
        sessionManager.transferAudio(url: url)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
