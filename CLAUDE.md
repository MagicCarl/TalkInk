# TalkInk

AI-powered meeting recorder for Apple Watch + iPhone. Record from your wrist, get organized notes on your phone.

## Tech Stack
- **Language**: Swift 6.0, SwiftUI
- **Targets**: iOS 17+ (iPhone), watchOS 10+ (Apple Watch)
- **Frameworks**: AVFoundation (recording), Speech (transcription), WatchConnectivity (sync)
- **Project Generation**: XcodeGen (`project.yml`)
- **AI**: Claude API for meeting summarization (future), on-device heuristics (current)

## Project Structure
```
TalkInk/
  App/                # App entry point (TalkInkApp.swift, ContentView.swift)
  Views/
    Home/             # Dashboard with recent meetings, Watch status
    Recording/        # iPhone mic recording UI
    Transcripts/      # Meeting notes list + detail (summary/transcript/actions)
    Settings/         # Watch connection, transcription engine, data management
  Services/
    RecordingService.swift       # iPhone AVAudioRecorder
    TranscriptionService.swift   # Apple Speech framework (on-device)
    AISummaryService.swift       # AI-powered note generation
    MeetingStore.swift           # Local persistence (JSON on disk)
    PhoneSessionManager.swift    # WatchConnectivity (iPhone side)
  Resources/          # Info.plist, entitlements, asset catalog
TalkInkWatch/
  App/                # Watch app entry point
  Views/              # Watch recording UI
  Services/
    WatchRecordingService.swift  # AVAudioRecorder + ExtendedRuntimeSession
    WatchSessionManager.swift    # WatchConnectivity (Watch side, file transfer)
  Resources/          # Watch Info.plist, entitlements, assets
Shared/
  Meeting.swift       # Core data model (Meeting, TranscriptSegment, ActionItem)
```

## Key Architecture
- **Watch Recording**: AVAudioRecorder + WKExtendedRuntimeSession keeps mic active when wrist drops. Records M4A at 16kHz mono.
- **Audio Transfer**: WatchConnectivity `transferFile()` sends audio from Watch → iPhone over Bluetooth.
- **Transcription**: Apple Speech framework with `requiresOnDeviceRecognition = true`. No data leaves device.
- **AI Notes**: Transcript → Claude API → structured summary + key points + action items.
- **Persistence**: MeetingStore saves to Documents/meetings.json.

## Pipeline Flow
```
Watch mic → M4A file → WatchConnectivity → iPhone
iPhone mic → M4A file → local
  → Speech framework (on-device transcription)
  → AI summary service (key points, action items)
  → MeetingStore (persist)
  → UI (summary/transcript/actions tabs)
```

## Commands
```bash
xcodegen generate     # Regenerate .xcodeproj from project.yml
```
Open TalkInk.xcodeproj in Xcode to build and run.

## Business Model
- One-time purchase (no subscription)
- All transcription is on-device (no server costs)
- AI summarization: on-device heuristics (free) or optional Claude API

## Status / TODO
- [x] Project structure and XcodeGen config
- [x] Shared data models (Meeting, TranscriptSegment, ActionItem)
- [x] iOS app: Home dashboard
- [x] iOS app: iPhone recording view
- [x] iOS app: Transcripts list + detail view (summary/transcript/actions)
- [x] iOS app: Settings view
- [x] iOS services: RecordingService, TranscriptionService, MeetingStore
- [x] iOS services: PhoneSessionManager (WatchConnectivity)
- [x] Watch app: Recording view
- [x] Watch services: WatchRecordingService + ExtendedRuntimeSession
- [x] Watch services: WatchSessionManager (file transfer to iPhone)
- [ ] App icon design
- [ ] Generate Xcode project and verify build
- [ ] Wire up Watch → iPhone audio transfer → auto-transcribe pipeline
- [ ] Claude API integration for AI summarization
- [ ] Speaker diarization (who said what)
- [ ] Calendar integration (EventKit)
- [ ] Meeting title auto-generation from transcript
- [ ] Export formats (PDF, Markdown, plain text)
- [ ] Watch complication (quick-start recording)
- [ ] Search across all transcripts
- [ ] UI polish: animations, onboarding, dark/light theme
- [ ] App Store submission
