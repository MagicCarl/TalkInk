import SwiftUI

struct TranscriptDetailView: View {
    let meetingID: UUID
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var pipeline: MeetingPipeline

    @State private var selectedTab = 0
    @State private var isRegenerating = false

    /// Live meeting from the store — updates as pipeline processes.
    private var meeting: Meeting {
        meetingStore.meetings.first(where: { $0.id == meetingID })
            ?? Meeting(id: meetingID, title: "Meeting", status: .failed)
    }

    /// Whether this meeting has AI-generated notes with real content.
    private var hasAINotes: Bool {
        meeting.isAIGenerated == true
            && meeting.overview != nil
            && !(meeting.topics ?? []).isEmpty
    }

    // Color palette for topic cards
    private static let topicColors: [(icon: Color, bg: Color)] = [
        (.blue, Color.blue.opacity(0.08)),
        (.purple, Color.purple.opacity(0.08)),
        (.orange, Color.orange.opacity(0.08)),
        (.teal, Color.teal.opacity(0.08)),
        (.pink, Color.pink.opacity(0.08)),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("View", selection: $selectedTab) {
                Text("Notes").tag(0)
                Text("Transcript").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            ScrollView {
                switch selectedTab {
                case 0: notesView
                case 1: transcriptView
                default: EmptyView()
                }
            }
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: shareText) {
                        Label("Share Notes", systemImage: "square.and.arrow.up")
                    }
                    if hasAINotes {
                        Button {
                            regenerateNotes()
                        } label: {
                            Label("Regenerate Notes", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRegenerating)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Notes View

    private var notesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            meetingHeader

            if meeting.status == .summarizing || isRegenerating {
                // Generating notes
                processingState(label: "Generating notes...")
            } else if meeting.status == .transcribing {
                processingState(label: "Transcribing audio...")
            } else if meeting.status == .ready && hasAINotes {
                // AI-generated notes — full structured layout
                aiNotesContent
            } else if meeting.status == .ready {
                // No AI notes — show transcript excerpt + regenerate option
                noAINotesView
            } else if meeting.status == .failed {
                failedState
            } else {
                processingState(label: meeting.status.label)
            }
        }
        .padding()
    }

    // MARK: - AI Notes Content

    private var aiNotesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overview
            if let overview = meeting.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)

                    Text(overview)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.primary)
                }
            }

            // Topics
            if let topics = meeting.topics, !topics.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { idx, topic in
                        topicCard(topic, colorIndex: idx)
                    }
                }
            }

            // Decisions
            if let decisions = meeting.decisions, !decisions.isEmpty {
                decisionsCard(decisions)
            }

            // Action Items
            if let actionItems = meeting.actionItems, !actionItems.isEmpty {
                actionItemsCard(actionItems)
            }
        }
    }

    // MARK: - No AI Notes View

    private var noAINotesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show a brief transcript excerpt so the page isn't empty
            if let transcript = meeting.transcript, !transcript.isEmpty {
                let excerpt = String(transcript.prefix(300))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript Preview")
                        .font(.headline)

                    Text(excerpt + (transcript.count > 300 ? "..." : ""))
                        .font(.subheadline)
                        .lineSpacing(4)
                        .foregroundStyle(.secondary)
                }
            }

            // Regenerate prompt — compact
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                    Text("AI notes not yet generated for this recording.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    regenerateNotes()
                } label: {
                    HStack(spacing: 6) {
                        if isRegenerating {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isRegenerating ? "Generating..." : "Generate Notes")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isRegenerating)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Still show any keyword-extracted items
            if let decisions = meeting.decisions, !decisions.isEmpty {
                decisionsCard(decisions)
            }
            if let actionItems = meeting.actionItems, !actionItems.isEmpty {
                actionItemsCard(actionItems)
            }
        }
    }

    // MARK: - Meeting Header

    private var meetingHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: meeting.source.iconName)
                .foregroundStyle(Color.accentColor)
                .font(.caption)
            Text(meeting.date, format: .dateTime.month().day().year())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(meeting.date, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
            if meeting.duration > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(formatDuration(meeting.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Topic Card

    private func topicCard(_ topic: DiscussionTopic, colorIndex: Int) -> some View {
        let colors = Self.topicColors[colorIndex % Self.topicColors.count]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.icon)
                    .frame(width: 4, height: 16)
                Text(topic.heading)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(topic.bulletPoints.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(colors.icon.opacity(0.6))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(bullet)
                            .font(.subheadline)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Decisions Card

    private func decisionsCard(_ decisions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Decisions")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
            .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(decisions.enumerated()), id: \.offset) { _, decision in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(decision)
                            .font(.subheadline)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Items Card

    private func actionItemsCard(_ actionItems: [ActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("Action Items")
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "checklist")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("\(actionItems.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
            .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(actionItems) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .orange)
                            .font(.body)

                        Text(item.text)
                            .font(.subheadline)
                            .strikethrough(item.isCompleted)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - States

    private func processingState(label: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var failedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Processing failed. Try recording again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let transcript = meeting.transcript, !transcript.isEmpty {
                // Header
                HStack {
                    Text("FULL TRANSCRIPT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                    let wordCount = transcript.split(separator: " ").count
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                let paragraphs = buildTimestampedParagraphs(
                    transcript: transcript,
                    segments: meeting.segments
                )
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, para in
                    HStack(alignment: .top, spacing: 10) {
                        // Timestamp badge
                        if let ts = para.timestamp {
                            Text(formatTimestamp(ts))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .frame(width: 44, alignment: .center)
                        } else {
                            Spacer()
                                .frame(width: 44)
                        }

                        // Accent line
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 2)

                        // Text block
                        Text(para.text)
                            .font(.subheadline)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .padding(.vertical, 4)
                    }

                    // Divider between paragraphs (not after last)
                    if idx < paragraphs.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
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

    // MARK: - Actions

    private func regenerateNotes() {
        isRegenerating = true
        Task {
            await pipeline.regenerateNotes(meetingID: meetingID)
            isRegenerating = false
        }
    }

    // MARK: - Helpers

    private struct TimestampedParagraph {
        let text: String
        let timestamp: TimeInterval?
    }

    private func buildTimestampedParagraphs(
        transcript: String,
        segments: [TranscriptSegment]?
    ) -> [TimestampedParagraph] {
        var rawParagraphs = transcript.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if rawParagraphs.count <= 1 {
            rawParagraphs = splitIntoSentenceGroups(transcript, groupSize: 3)
        }

        guard let segments, !segments.isEmpty else {
            return rawParagraphs.map { TimestampedParagraph(text: $0, timestamp: nil) }
        }

        var result: [TimestampedParagraph] = []
        var segIdx = 0

        for para in rawParagraphs {
            let paraWords = para.lowercased().split(separator: " ").prefix(3)
            var matchedTimestamp: TimeInterval? = nil

            for i in segIdx..<segments.count {
                let segWord = segments[i].text.lowercased()
                    .trimmingCharacters(in: .punctuationCharacters)
                if let firstWord = paraWords.first,
                   segWord == String(firstWord).trimmingCharacters(in: .punctuationCharacters) {
                    matchedTimestamp = segments[i].timestamp
                    segIdx = i + 1
                    break
                }
            }

            if matchedTimestamp == nil, !result.isEmpty {
                let chunkDuration: TimeInterval = 55
                matchedTimestamp = chunkDuration * Double(result.count)
            } else if matchedTimestamp == nil {
                matchedTimestamp = 0
            }

            result.append(TimestampedParagraph(text: para, timestamp: matchedTimestamp))
        }

        return result
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func splitIntoSentenceGroups(_ text: String, groupSize: Int) -> [String] {
        let pattern = #"(?<=[.!?])\s+"#
        let sentences: [String]
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..., in: text)
            var results: [String] = []
            var lastEnd = text.startIndex
            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let matchRange = match.flatMap({ Range($0.range, in: text) }) else { return }
                let sentence = String(text[lastEnd..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { results.append(sentence) }
                lastEnd = matchRange.upperBound
            }
            let remaining = String(text[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty { results.append(remaining) }
            sentences = results
        } else {
            sentences = text.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        guard sentences.count > groupSize else { return [text] }

        let effectiveSentences: [String]
        if sentences.count <= 2 {
            let words = text.split(separator: " ")
            let wordsPerChunk = 30
            var chunks: [String] = []
            for i in stride(from: 0, to: words.count, by: wordsPerChunk) {
                let end = min(i + wordsPerChunk, words.count)
                chunks.append(words[i..<end].joined(separator: " "))
            }
            effectiveSentences = chunks
        } else {
            effectiveSentences = sentences
        }

        var groups: [String] = []
        for i in stride(from: 0, to: effectiveSentences.count, by: groupSize) {
            let end = min(i + groupSize, effectiveSentences.count)
            let chunk = effectiveSentences[i..<end].joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { groups.append(chunk) }
        }
        return groups.isEmpty ? [text] : groups
    }

    // MARK: - Share Text

    private var shareText: String {
        var text = "# \(meeting.title)\n\(meeting.date.formatted())\n\n"

        if let overview = meeting.overview ?? meeting.summary {
            text += "## Overview\n\(overview)\n\n"
        }
        if let topics = meeting.topics, !topics.isEmpty {
            for topic in topics {
                text += "### \(topic.heading)\n"
                for bullet in topic.bulletPoints {
                    text += "- \(bullet)\n"
                }
                text += "\n"
            }
        }
        if let decisions = meeting.decisions, !decisions.isEmpty {
            text += "## Decisions\n"
            for d in decisions {
                text += "- \(d)\n"
            }
            text += "\n"
        }
        if let actionItems = meeting.actionItems, !actionItems.isEmpty {
            text += "## Action Items\n"
            for item in actionItems {
                text += "- [ ] \(item.text)\n"
            }
            text += "\n"
        }
        if let transcript = meeting.transcript {
            text += "---\n\n## Full Transcript\n\(transcript)\n"
        }
        return text
    }
}
