import Foundation
import Combine

/// Persists meetings to disk as JSON.
final class MeetingStore: ObservableObject {
    @Published var meetings: [Meeting] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("meetings.json")
        loadMeetings()
    }

    func addMeeting(_ meeting: Meeting) {
        meetings.insert(meeting, at: 0)
        saveMeetings()
    }

    func updateMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
            saveMeetings()
        }
    }

    func deleteMeeting(_ meeting: Meeting) {
        meetings.removeAll { $0.id == meeting.id }

        // Clean up audio file
        if let fileName = meeting.audioFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioURL = docs.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: audioURL)
        }

        saveMeetings()
    }

    func deleteAllMeetings() {
        for meeting in meetings {
            if let fileName = meeting.audioFileName {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let audioURL = docs.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        meetings.removeAll()
        saveMeetings()
    }

    private func saveMeetings() {
        do {
            let data = try JSONEncoder().encode(meetings)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save meetings: \(error)")
        }
    }

    private func loadMeetings() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            meetings = try JSONDecoder().decode([Meeting].self, from: data)
        } catch {
            print("Failed to load meetings: \(error)")
        }
    }
}
