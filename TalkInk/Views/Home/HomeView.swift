import SwiftUI

struct HomeView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var phoneSessionManager: PhoneSessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero banner
                    heroBanner

                    // Recent meetings
                    if meetingStore.meetings.isEmpty {
                        emptyState
                    } else {
                        recentMeetings
                    }
                }
                .padding()
            }
            .navigationTitle("TalkInk")
        }
    }

    private var heroBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.accent)

            Text("Your AI Meeting Assistant")
                .font(.title3.bold())

            HStack(spacing: 16) {
                StatPill(
                    icon: "doc.text",
                    value: "\(meetingStore.meetings.count)",
                    label: "Meetings"
                )
                StatPill(
                    icon: "applewatch",
                    value: phoneSessionManager.isWatchReachable ? "Connected" : "—",
                    label: "Watch"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No meetings yet")
                .font(.headline)
            Text("Tap Record to capture your first meeting,\nor start recording from your Apple Watch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var recentMeetings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(meetingStore.meetings.prefix(5)) { meeting in
                MeetingRow(meeting: meeting)
            }
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meeting.source.iconName)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(meeting.date, style: .date)
                    Text("·")
                    Text(formatDuration(meeting.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: meeting.status)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatusBadge: View {
    let status: MeetingStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(statusColor.opacity(0.2))
            )
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .recording: return .red
        case .transferring, .transcribing, .summarizing: return .orange
        case .ready: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MeetingStore())
        .environmentObject(PhoneSessionManager())
}
