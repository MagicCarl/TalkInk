import SwiftUI

struct TranscriptDetailView: View {
    let meeting: Meeting

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Summary").tag(0)
                Text("Transcript").tag(1)
                Text("Actions").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                switch selectedTab {
                case 0: summaryView
                case 1: transcriptView
                case 2: actionsView
                default: EmptyView()
                }
            }
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meeting info
            HStack(spacing: 12) {
                Image(systemName: meeting.source.iconName)
                    .foregroundStyle(.accent)
                Text(meeting.date, style: .date)
                Text("·")
                Text(meeting.date, style: .time)
                Spacer()
                StatusBadge(status: meeting.status)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Divider()

            if let summary = meeting.summary {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Summary", systemImage: "text.alignleft")
                        .font(.headline)
                    Text(summary)
                        .font(.body)
                }
            }

            if let keyPoints = meeting.keyPoints, !keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Key Points", systemImage: "list.bullet")
                        .font(.headline)

                    ForEach(keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.accent)
                                .padding(.top, 6)
                            Text(point)
                                .font(.body)
                        }
                    }
                }
            }

            if meeting.summary == nil && meeting.keyPoints == nil {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("AI notes will appear here once processing completes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .padding()
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let transcript = meeting.transcript {
                Text(transcript)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(meeting.status.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .padding()
    }

    private var actionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let actionItems = meeting.actionItems, !actionItems.isEmpty {
                ForEach(actionItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                        Text(item.text)
                            .font(.body)
                            .strikethrough(item.isCompleted)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No action items detected.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .padding()
    }

    private var shareText: String {
        var text = "# \(meeting.title)\n\(meeting.date.formatted())\n\n"
        if let summary = meeting.summary {
            text += "## Summary\n\(summary)\n\n"
        }
        if let keyPoints = meeting.keyPoints {
            text += "## Key Points\n"
            for point in keyPoints {
                text += "- \(point)\n"
            }
            text += "\n"
        }
        if let transcript = meeting.transcript {
            text += "## Full Transcript\n\(transcript)\n"
        }
        return text
    }
}
