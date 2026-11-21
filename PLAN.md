# IntervalTimer Plan

## Spec (agreed decisions)
- Sliders in 15s steps: warm-up 0–600s, work 15–600s, rest 15–300s. Interval count 1–30.
- Total time = warm-up + n×work + (n−1)×rest, shown as mm:ss. The workout ends on the last work interval; there is no cool-down.
- If warm-up is 0: a 15s "Get Ready" lead-in with the countdown, NOT counted in the total time.
- Cues: a soft 3-2-1 beep before every work interval (not before rest), a bing at the start and end of each work interval, and a tada at the finish. Tones are selectable in Settings.
- Cues play in the background and mix over music with no ducking.
- Running screen: phase timer, phase-colored gradient bar, "Interval X of Y", Pause/Resume/Stop.
- Phone calls and Siri auto-pause the workout.
- Remembers the last settings. Follows system light/dark mode.
- Live Activity on the lock screen and Dynamic Island, with no buttons.
- Out of scope: haptics, HealthKit, Apple Watch, keeping the screen awake, App Store release.

## Status
- [x] Core app: setup, running screen, settings, persistence
- [x] Background cues (verified on device)
- [x] App icon (stopwatch, white face)
- [x] Live Activity (verified on device)
- [x] Published to GitHub

## Ideas / backlog
_(none yet)_
