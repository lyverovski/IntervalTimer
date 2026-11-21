import XCTest

final class WorkoutFlowUITests: XCTestCase {
	private var app: XCUIApplication!

	override func setUpWithError() throws {
		continueAfterFailure = false
		app = XCUIApplication()
		app.launch()
	}

	private func attachScreenshot(named name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}

	func testShouldStartPauseResumeAndStopWorkout() throws {
		app.buttons["Start"].tap()
		XCTAssertTrue(app.staticTexts["WARM-UP"].waitForExistence(timeout: 2))
		XCTAssertTrue(app.staticTexts["Up next: Interval 1 of 8"].exists)
		sleep(2)
		attachScreenshot(named: "running")

		app.buttons["Pause"].tap()
		XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
		attachScreenshot(named: "paused")
		app.buttons["Resume"].tap()
		XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2))

		app.buttons["Stop"].tap()
		app.buttons["End Workout"].tap()
		XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 2))
	}

	func testShouldStartWhenTappingAnywhereOnStartButton() throws {
		let start = app.buttons["Start"]
		XCTAssertTrue(start.waitForExistence(timeout: 2))
		// Near the left edge of the capsule, away from the label text.
		start.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
		XCTAssertTrue(app.staticTexts["WARM-UP"].waitForExistence(timeout: 2))
	}

	func testShouldShowLiveActivityAfterLeavingApp() throws {
		app.buttons["Start"].tap()
		XCTAssertTrue(app.staticTexts["WARM-UP"].waitForExistence(timeout: 2))
		XCUIDevice.shared.press(.home)
		sleep(3)
		let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
		let island = XCTAttachment(screenshot: springboard.screenshot())
		island.name = "dynamic-island"
		island.lifetime = .keepAlways
		add(island)
		app.activate()
		// Wait out the return-to-foreground animation, or the tap is dropped.
		XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
		XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
		sleep(1)
		app.buttons["Stop"].tap()
		XCTAssertTrue(app.buttons["End Workout"].waitForExistence(timeout: 5))
		app.buttons["End Workout"].tap()
		XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
	}

	func testShouldShowToneChoicesInSettings() throws {
		app.navigationBars.buttons.element(boundBy: 0).tap()
		// Form rows are created lazily, so check a tone in the first (visible) section.
		XCTAssertTrue(app.buttons["Soft Beep"].waitForExistence(timeout: 2))
		attachScreenshot(named: "settings")
		app.buttons["Done"].tap()
		XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 2))
	}
}
