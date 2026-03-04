import Foundation

/// A single recorded meeting with its audio, transcript, and AI-generated notes.
struct Meeting: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    var source: RecordingSource
    var status: MeetingStatus

    // Audio
    var audioFileName: String?

    // Transcript
    var transcript: String?
    var segments: [TranscriptSegment]?

    // AI-generated notes (structured by topic like Otter/Fireflies/tl;dv)
    var overview: String?
    var topics: [DiscussionTopic]?
    var decisions: [String]?
    var actionItems: [ActionItem]?
    var isAIGenerated: Bool?

    // Legacy fields kept for backward compatibility with existing data
    var summary: String?
    var keyPoints: [String]?
    var keywords: [String]?

    init(
        id: UUID = UUID(),
        title: String = "New Meeting",
        date: Date = Date(),
        duration: TimeInterval = 0,
        source: RecordingSource = .iPhone,
        status: MeetingStatus = .recording
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.source = source
        self.status = status
    }
}

/// A discussion topic with a heading and bullet-point details.
/// Mirrors how Fireflies/tl;dv group notes by subject.
struct DiscussionTopic: Identifiable, Codable {
    let id: UUID
    var heading: String
    var bulletPoints: [String]

    init(id: UUID = UUID(), heading: String, bulletPoints: [String]) {
        self.id = id
        self.heading = heading
        self.bulletPoints = bulletPoints
    }
}

enum RecordingSource: String, Codable {
    case iPhone = "iPhone"
    case appleWatch = "Apple Watch"

    var iconName: String {
        switch self {
        case .iPhone: return "iphone"
        case .appleWatch: return "applewatch"
        }
    }
}

enum MeetingStatus: String, Codable {
    case recording
    case transferring
    case transcribing
    case summarizing
    case ready
    case failed

    var label: String {
        switch self {
        case .recording: return "Recording..."
        case .transferring: return "Transferring..."
        case .transcribing: return "Transcribing..."
        case .summarizing: return "Generating notes..."
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }
}

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    var timestamp: TimeInterval
    var text: String
    var speaker: String?

    init(id: UUID = UUID(), timestamp: TimeInterval, text: String, speaker: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.speaker = speaker
    }
}

struct ActionItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var isCompleted: Bool

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }
}
