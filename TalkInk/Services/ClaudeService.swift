import Foundation

/// Direct URLSession client for the Claude Messages API.
/// Sends transcripts and returns structured meeting notes organized by topic
/// (like Otter.ai, Fireflies, and tl;dv).
enum ClaudeService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let apiVersion = "2023-06-01"

    /// Structured notes returned from Claude, organized by topic.
    struct MeetingNotes {
        let title: String
        let overview: String
        let topics: [Topic]
        let decisions: [String]
        let actionItems: [String]
    }

    struct Topic {
        let heading: String
        let bulletPoints: [String]
    }

    enum ClaudeError: LocalizedError {
        case noAPIKey
        case networkError(Error)
        case invalidResponse(Int)
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No Anthropic API key configured. Add one in Settings."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse(let code):
                return "API returned status \(code)."
            case .parseError(let detail):
                return "Failed to parse AI response: \(detail)"
            }
        }
    }

    /// Summarize a transcript using Claude, returning topic-organized notes.
    static func summarize(transcript: String) async throws -> MeetingNotes {
        guard let apiKey = KeychainHelper.read(key: "anthropic_api_key"),
              !apiKey.isEmpty else {
            throw ClaudeError.noAPIKey
        }

        // Truncate very long transcripts to stay within token limits
        let maxChars = 12000
        let trimmedTranscript = transcript.count > maxChars
            ? String(transcript.prefix(maxChars)) + "\n[transcript truncated]"
            : transcript

        let systemPrompt = """
            You are a professional meeting notes assistant. Your job is to transform \
            a raw transcript into well-organized, scannable meeting notes — similar \
            to what Otter.ai, Fireflies, or tl;dv produce. \
            \
            Your notes must be COMPLETELY DIFFERENT from the transcript. Never copy \
            sentences verbatim. Rewrite everything in clear, concise language. \
            Organize by topic, not chronologically. \
            \
            Return ONLY valid JSON with no markdown formatting, no code fences.
            """

        let userPrompt = """
            Here is the transcript:

            \(trimmedTranscript)

            ---

            Produce meeting notes as JSON with this exact structure:

            {
              "title": "Short title, 3-6 words",
              "overview": "A 2-4 sentence executive summary. Paraphrase — do NOT copy from transcript. Explain what was discussed and any conclusions reached.",
              "topics": [
                {
                  "heading": "Topic Name",
                  "bulletPoints": [
                    "Key detail or insight about this topic",
                    "Another important point"
                  ]
                }
              ],
              "decisions": [
                "Specific decision that was made or agreed upon"
              ],
              "actionItems": [
                "Task description — include who is responsible if mentioned"
              ]
            }

            Rules:
            - overview: 2-4 sentences. Must sound completely different from the transcript. Write a fresh summary a busy person can read in 10 seconds.
            - topics: Group the discussion into 2-5 distinct topics. Each topic gets a short heading and 2-4 bullet points capturing the key details. This is the MAIN section — it should cover the substance of the meeting.
            - decisions: Any decisions, agreements, or conclusions reached. If none, use an empty array.
            - actionItems: Specific next steps or tasks. Include the person responsible and deadline if mentioned. If none, use an empty array.
            - IMPORTANT: The notes must be useful WITHOUT reading the transcript. Someone reading just these notes should understand what happened in the meeting.
            """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse(0)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[Claude] API error \(httpResponse.statusCode): \(errorBody)")
            throw ClaudeError.invalidResponse(httpResponse.statusCode)
        }

        return try parseResponse(data)
    }

    /// Parse the Claude API response and extract JSON meeting notes.
    private static func parseResponse(_ data: Data) throws -> MeetingNotes {
        // Parse the Messages API envelope
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = envelope["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeError.parseError("unexpected API response structure")
        }

        // Extract JSON from the response text
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonStart = cleaned.firstIndex(of: "{"),
              let jsonEnd = cleaned.lastIndex(of: "}") else {
            throw ClaudeError.parseError("no JSON object found in response")
        }
        let jsonString = String(cleaned[jsonStart...jsonEnd])

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ClaudeError.parseError("invalid JSON: \(jsonString.prefix(200))")
        }

        let title = json["title"] as? String ?? "Meeting Notes"
        let overview = json["overview"] as? String ?? json["summary"] as? String ?? ""
        let decisions = json["decisions"] as? [String] ?? []
        let actionItems = json["actionItems"] as? [String] ?? []

        // Parse topics array
        var topics: [Topic] = []
        if let topicsArray = json["topics"] as? [[String: Any]] {
            for topicDict in topicsArray {
                let heading = topicDict["heading"] as? String ?? "Discussion"
                let bullets = topicDict["bulletPoints"] as? [String] ?? []
                topics.append(Topic(heading: heading, bulletPoints: bullets))
            }
        }

        // Fallback: if no topics but has keyPoints, convert them
        if topics.isEmpty {
            if let keyPoints = json["keyPoints"] as? [String], !keyPoints.isEmpty {
                topics.append(Topic(heading: "Key Points", bulletPoints: keyPoints))
            }
        }

        return MeetingNotes(
            title: title,
            overview: overview,
            topics: topics,
            decisions: decisions,
            actionItems: actionItems
        )
    }
}
