import SwiftUI

struct TranscriptsListView: View {
    @EnvironmentObject var meetingStore: MeetingStore

    var body: some View {
        NavigationStack {
            Group {
                if meetingStore.meetings.isEmpty {
                    emptyState
                } else {
                    meetingList
                }
            }
            .navigationTitle("Notes")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Notes Yet")
                .font(.headline)
            Text("Record a meeting and your transcripts\nwill appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var meetingList: some View {
        List {
            ForEach(meetingStore.meetings) { meeting in
                NavigationLink(destination: TranscriptDetailView(meetingID: meeting.id)) {
                    MeetingRow(meeting: meeting)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteMeetings)
        }
        .listStyle(.plain)
    }

    private func deleteMeetings(at offsets: IndexSet) {
        for index in offsets {
            meetingStore.deleteMeeting(meetingStore.meetings[index])
        }
    }
}

#Preview {
    TranscriptsListView()
        .environmentObject(MeetingStore())
}
