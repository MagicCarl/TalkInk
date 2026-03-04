import Foundation
import FoundationModels

/// On-device AI summarization using Apple Foundation Models (iOS 26+).
/// No API key needed — runs entirely on-device.
@available(iOS 26, *)
enum OnDeviceAIService {

    // MARK: - Structured output types

    @Generable(description: "Structured meeting notes from a transcript")
    struct MeetingNotes {
        @Guide(description: "Short title, 3-6 words summarizing the meeting")
        var title: String

        @Guide(description: "2-4 sentence executive summary paraphrasing the discussion and conclusions")
        var overview: String

        @Guide(description: "Discussion organized into 2-5 distinct topics")
        var topics: [Topic]

        @Guide(description: "Specific decisions, agreements, or conclusions reached")
        var decisions: [String]

        @Guide(description: "Specific next steps or tasks, including who is responsible if mentioned")
        var actionItems: [String]
    }

    @Generable(description: "A discussion topic with key points")
    struct Topic {
        @Guide(description: "Short topic heading, 2-5 words")
        var heading: String

        @Guide(description: "2-4 bullet points capturing key details about this topic")
        var bulletPoints: [String]
    }

    // MARK: - Errors

    enum AIError: LocalizedError {
        case modelUnavailable(String)
        case generationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelUnavailable(let reason):
                return "On-device AI unavailable: \(reason)"
            case .generationFailed(let error):
                return "AI generation failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Availability check

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: - Summarize

    static func summarize(transcript: String) async throws -> MeetingNotes {
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            let reason: String
            switch model.availability {
            case .available:
                reason = "unknown"
            case .unavailable(let r):
                reason = "\(r)"
            }
            throw AIError.modelUnavailable(reason)
        }

        // Truncate very long transcripts to stay within on-device limits
        let maxChars = 8000
        let trimmed = transcript.count > maxChars
            ? String(transcript.prefix(maxChars)) + "\n[transcript truncated]"
            : transcript

        let instructions = """
            You are a professional meeting notes assistant. Transform the raw \
            transcript into well-organized, scannable meeting notes. \
            Your notes must be COMPLETELY DIFFERENT from the transcript. \
            Never copy sentences verbatim. Rewrite everything in clear, \
            concise language. Organize by topic, not chronologically. \
            Someone reading just these notes should understand what happened.
            """

        let prompt = """
            Here is the transcript of a meeting:

            \(trimmed)

            ---

            Create structured meeting notes from this transcript. \
            Write a short title, a concise 2-4 sentence overview, \
            group the discussion into 2-5 topics with bullet points, \
            list any decisions made, and extract action items.
            """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: MeetingNotes.self
            )
            return response.content
        } catch {
            throw AIError.generationFailed(error)
        }
    }
}
