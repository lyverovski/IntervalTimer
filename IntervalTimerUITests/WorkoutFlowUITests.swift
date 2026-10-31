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

	func testShouldShowToneChoicesInSettings() throws {
		app.navigationBars.buttons.element(boundBy: 0).tap()
		// Form rows are created lazily, so check a tone in the first (visible) section.
		XCTAssertTrue(app.buttons["Soft Beep"].waitForExistence(timeout: 2))
		attachScreenshot(named: "settings")
		app.buttons["Done"].tap()
		XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 2))
	}
}
