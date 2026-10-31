#!/bin/sh
# Runs unit tests on the simulator and prints only errors and the summary.
cd "$(dirname "$0")/.." || exit 1
xcodebuild test -project IntervalTimer.xcodeproj -scheme IntervalTimer \
	-destination 'platform=iOS Simulator,name=iPhone 17' \
	-only-testing:IntervalTimerTests "$@" 2>&1 \
	| grep -E '^/.*(error|warning):|✘|Test run|passed after|failed after|TEST (SUCCEEDED|FAILED)|BUILD FAILED' \
	| grep -v 'appintentsmetadataprocessor'
