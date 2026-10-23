# Trailhead

A native, offline iPad practice app for Noah and a parent. Built with SwiftUI and PencilKit; iPadOS 17 or later. No backend, subscriptions, analytics, AI services, or API keys.

## Run

Open `Trailhead.xcodeproj` in Xcode, choose the **Trailhead** scheme and an iPad simulator, then Run. The checked-in project is ready to open; XcodeGen is only required when changing `project.yml`.

To install on Noah's iPad, connect and unlock it, accept the Trust prompt, enable Developer Mode if requested, choose the physical iPad in Xcode's run destination menu, and press Run. Automatic signing is configured for Ryan Hayden's paid personal development team (`R53X844C48`). Xcode handles provisioning using the signed-in developer account. Simulator builds do not require signing. This avoids free Personal Team seven-day provisioning; paid development builds still need renewal when their signing assets expire.

The device build was signed and verified on October 23, 2026, and installed on Ryan's iPad Air (5th generation). Its current development provisioning profile expires March 9, 2027. Rebuild and install over the existing app before expiry to renew it and retain local progress.

Start with **Parent** and create a six-digit PIN. There is no default PIN. Set placement and the daily rhythm in **Learning plan**, then switch to **Noah**. The two profiles share one iPad's local storage; they are not cloud accounts. The parent profile locks when the app becomes inactive.

## Included

- A daily mission with 10-minute targets for each subject, accumulated across visits. Parent-adjustable 30–60 minute total target; an optional recovery target is 10 minutes total. No penalties for missed days.
- Math addition/multiplication operands 0–12; nonnegative subtraction and exact division through corresponding 12-times facts. Individual fact histories, small developing sets, delayed review, separate accuracy and response-time records.
- Eight original starter spelling lessons across grades 3–6. Spoken prompts, explicit pattern explanations, study/hide/recall, disabled autocorrect, and word histories. The parent selects a starter lesson or creates a custom lesson with 4–24 practice words, a teaching pattern, and a transfer word for the quiz.
- Apple Pencil or finger handwriting on ruled sheets: gray models to trace first, followed by blank lines for independent copying. Short letter groups repeat for two tracing passes. Longer words/passages wrap to fit the page, with extra blank lines below. Includes print and script models, spelling words, five KJV Proverbs passages, saved samples and persistent draft ink. Weekly handwriting quizzes remain untraced.
- One resumable checkpoint per ISO calendar week (Monday–Sunday): eight math facts, five spelling words including a transfer word, and one copied passage. Available any day; Friday is suggested. Each answer locks when saved. Old drafts are preserved in the parent view when a new week starts.
- Parent handwriting rubric: formation, size, spacing, alignment, each scored 1–4. Math and spelling use percent correct; handwriting uses points out of 16. The overall percentage equally weights the three subjects, rounded down. No overall grade until handwriting is reviewed. Rubric scores and parent feedback can be revised.
- Quiz results update skill histories. Active quiz work contributes to the corresponding subject's daily practice target.
- Supplies earned for answers and mission/checkpoint completion; four persistent camp upgrades to purchase. Rewards never depend on quiz grade.
- Parent progress dashboard, quiz answer inspection, writing portfolio, and CSV report export.

## Current limits

This is a functional first version, not a full spelling curriculum or a validated handwriting assessment. Cursive models are a system script font, without instructional stroke-order animations. Parent review controls placement and progression. Handwriting is not machine-graded; spelling recall uses the keyboard, separate from handwriting. No paper-transfer assessment is included.

Practice time runs only in the foreground on a practice or active quiz screen and pauses after 20 seconds without input. Brief pauses within that window count. Menus and finished quiz results do not count. Response-time indicators include thinking and breaks while a question stays open; interpret these alongside accuracy rather than as a standardized assessment.

The game loop is an initial camp-building reward system. There is no 3D adventure, enemy combat, or ongoing world expansion yet. There are no notifications, remote parent access, sync, or account recovery.

## Data

Progress is written atomically to `Application Support/Trailhead/progress.json` inside the app sandbox. Pencil drawings are sibling `.pencil` files. The PIN is salted and hashed in the device Keychain, never stored in progress exports. An unreadable progress file is preserved and subsequent writes are blocked to avoid replacing it with empty data.

CSV export contains practice totals and quiz grades; it is **not a complete backup** and does not include handwriting. Deleting the app can remove its local progress. Keep an iPad backup for recovery. No health information is collected or required.

## TestFlight

The App Store Connect record is **Noah's Trailhead**, app ID `6826335583`, bundle ID `com.hayden.trailhead`, under Ryan Hayden's personal team. Version and build numbers are set in `project.yml`; increment the build number before each new upload and regenerate the Xcode project.

`TestFlightExport.plist` uploads only for internal TestFlight testing, not public App Store distribution. Build and upload using the signed-in Xcode developer account:

```sh
xcodebuild -project Trailhead.xcodeproj -scheme Trailhead -configuration Release -destination 'generic/platform=iOS' -archivePath artifacts/Trailhead-TestFlight.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath artifacts/Trailhead-TestFlight.xcarchive -exportOptionsPlist TestFlightExport.plist -exportPath artifacts/TestFlight -allowProvisioningUpdates
```

Apple processes uploaded builds before they appear for testing. TestFlight builds expire 90 days after upload; upload a fresh build to continue testing. Install updates over the existing app to retain local progress.

## Development and verification

```sh
xcodegen generate
xcodebuild -project Trailhead.xcodeproj -scheme Trailhead -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=27.0' test CODE_SIGNING_ALLOWED=NO
```

Unit tests cover arithmetic validity, mastery/error transitions, limited introduction of new facts, persistence, corrupt-file preservation, daily rewards, quiz resumption and submission, grading, and purchase guards. UI tests exercise the two profiles, math, spelling, handwriting screens, parent settings, and incorrect PIN rejection. UI tests use a simulator-only test PIN; it is not an app default.

`swift test --scratch-path .build/core` runs the ten learning/persistence tests directly on macOS without simulator instrumentation. The iPad simulator build and launch succeed, but the automated UI suite could not run in this environment because Xcode cannot attach its simulator instrumentation service (`DTServiceHubClient failed to bless service hub`). The UI tests remain in the project for a full Xcode installation.

Simulator screenshots are saved in `artifacts`. Apple Pencil feel, palm rejection, audio with the intended voice, and font legibility should also be checked on the actual iPad before Noah starts using it regularly. Debug builds accept `--preview-noah` and `--preview-screen=Math` (or another Noah navigation label) for developer screenshots. Parent access always requires its PIN.

The icon is drawn from code: `swift scripts/make-icon.swift` regenerates it. No third-party dependencies are required.
