import Foundation
import Combine

/// Persists meetings to disk as JSON.
final class MeetingStore: ObservableObject, @unchecked Sendable {
    @Published var meetings: [Meeting] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("meetings.json")
        loadMeetings()
    }

    func addMeeting(_ meeting: Meeting) {
        onMain { [self] in
            meetings.insert(meeting, at: 0)
            saveMeetings()
        }
    }

    func updateMeeting(_ meeting: Meeting) {
        onMain { [self] in
            if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
                meetings[index] = meeting
                saveMeetings()
            }
        }
    }

    func deleteMeeting(_ meeting: Meeting) {
        onMain { [self] in
            meetings.removeAll { $0.id == meeting.id }

            // Clean up audio file
            if let fileName = meeting.audioFileName {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let audioURL = docs.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: audioURL)
            }

            saveMeetings()
        }
    }

    func deleteAllMeetings() {
        onMain { [self] in
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
    }

    private func onMain(_ work: @escaping @Sendable () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
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
