# IntervalTimer

Personal-use SwiftUI interval timer. iOS 17+, Xcode 26, not on the App Store. Spec and status are in PLAN.md.

## Stack and conventions
- SwiftUI + `@Observable`. The app target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; mark pure value types and helpers `nonisolated`.
- Swift Testing (`@Test`, `#expect`) for unit tests, XCTest for UI tests. TDD for Model/Audio/Persistence logic.
- `///` doc comments on non-private API. Tabs for indentation.
- Xcode synchronized folders (objectVersion 77): new files in existing folders are picked up automatically; new targets/folders need pbxproj edits.

## Layout
- `IntervalTimer/Model`: config, schedule (phases and cues), engine (date-based, injected clock).
- `IntervalTimer/Audio`: AVAudioSession, silent-loop keepalive, tone catalog.
- `IntervalTimer/LiveActivity`: ActivityKit controller.
- `Shared/`: code compiled into both the app and the widget (activity attributes, `TimeFormat`).
- `IntervalTimerWidget/`: Live Activity UI (lock screen and Dynamic Island).
- `scripts/`: `test.sh`, `generate_tones.py` (WAV synthesis), `generate_icon.swift`.

## Commands
- Unit tests: `scripts/test.sh` (iPhone 17 simulator).
- UI tests: boot the simulator fully first and pass `-parallel-testing-enabled NO`, or xctrunner fails to launch.
- Device build: `xcodebuild -scheme IntervalTimer -destination 'generic/platform=iOS' -allowProvisioningUpdates build`
- Device install: `xcrun devicectl device install app --device "AL iPhone 14 Pro" <path to .app>`. Works over Wi-Fi. The phone must be UNLOCKED, or the developer disk image won't mount.
- Signing: paid Apple Developer account, team V76FX5NP3Z. The profile expires 2027-11.

## Gotchas
- `INFOPLIST_KEY_UIBackgroundModes` is silently ignored. Background modes and `NSSupportsLiveActivities` live in `IntervalTimer-Info.plist` (merged with the generated plist). Check the BUILT app's Info.plist with `plutil` after changing them.
- Buttons inside Form rows can lose taps on a real device (a small drag counts as a scroll). Keep primary actions outside the Form (e.g. `safeAreaInset`).
- Form rows load lazily, so UI tests can only find elements that are on screen.
- Live Activity countdowns use `Text(timerInterval:)` / `ProgressView(timerInterval:)` so the system animates them; the app only updates on phase changes.
- After a background gap, the engine skips stale cues, but the finish cue always plays.

## Verification
"Done" means verified on the phone, not just in the simulator. Background audio, interruptions (calls/Siri), and the Live Activity can only be fully checked on the device; list what I should test by hand.

## Git
- Commits use the noreply email (set in this repo's local git config). Public repo: github.com/lyverovski/IntervalTimer.
- Ask before pushing.
