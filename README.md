# Interval Timer

A SwiftUI interval timer for iOS 17+, built for interval training: indoor cycling, spin, treadmill or outdoor runs.

## Features

- Sliders for warm-up (0–10 min), interval (15 s–10 min), rest (15 s–5 min) and number of intervals (1–30), in 15-second steps
- Total workout time calculated as you adjust
- Running screen with a phase-colored progress bar, overall workout progress and "Interval X of Y"
- Audio cues: 3-2-1 countdown before each interval, a bing at interval start and end, and a finish sound
- Selectable tones in Settings
- Cues keep playing with the screen locked and mix over your music
- Pauses automatically for phone calls and Siri
- Remembers your last settings

## Running

Open `IntervalTimer.xcodeproj` in Xcode 16 or later, choose a simulator or device, and press ⌘R.

Unit tests: `./scripts/test.sh`

## Sounds

The tones are synthesized by `scripts/generate_tones.py` (Python standard library only) into `IntervalTimer/Sounds/`. iOS doesn't let apps use the system ringtones, so the app bundles its own.
