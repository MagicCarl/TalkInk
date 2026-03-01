import Foundation

/// Generates structured meeting notes from a transcript using AI.
/// Currently uses on-device heuristics. Will integrate Claude API for richer summaries.
final class AISummaryService: ObservableObject, @unchecked Sendable {
    @Published var isSummarizing = false

    /// Generate summary, key points, and action items from a transcript.
    func generateNotes(from transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [ActionItem]) {
        DispatchQueue.main.async { [self] in isSummarizing = true }
        defer { DispatchQueue.main.async { [self] in isSummarizing = false } }

        // TODO: Replace with Claude API call for production-quality summarization.
        // For now, use basic on-device extraction as a placeholder.
        let summary = extractSummary(from: transcript)
        let keyPoints = extractKeyPoints(from: transcript)
        let actionItems = extractActionItems(from: transcript)

        return (summary, keyPoints, actionItems)
    }

    // MARK: - Placeholder heuristics (to be replaced by AI)

    private func extractSummary(from transcript: String) -> String {
        let sentences = transcript.components(separatedBy: ". ")
        let firstFew = sentences.prefix(3).joined(separator: ". ")
        return firstFew.isEmpty ? "Meeting recorded and transcribed." : firstFew + "."
    }

    private func extractKeyPoints(from transcript: String) -> [String] {
        let sentences = transcript.components(separatedBy: ". ")
        // Pick sentences that seem important (longer ones, or ones with key words)
        let keywords = ["decided", "agreed", "important", "need to", "should", "must", "deadline", "goal", "plan", "next step"]
        var points: [String] = []

        for sentence in sentences {
            let lower = sentence.lowercased()
            if keywords.contains(where: { lower.contains($0) }) {
                points.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return points.isEmpty ? ["Review full transcript for details."] : Array(points.prefix(5))
    }

    private func extractActionItems(from transcript: String) -> [ActionItem] {
        let sentences = transcript.components(separatedBy: ". ")
        let actionKeywords = ["need to", "should", "will do", "action item", "follow up", "todo", "to do", "must"]
        var items: [ActionItem] = []

        for sentence in sentences {
            let lower = sentence.lowercased()
            if actionKeywords.contains(where: { lower.contains($0) }) {
                items.append(ActionItem(text: sentence.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }

        return items
    }
}
