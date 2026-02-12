import XCTest

final class CameraAppUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        try ensureSignedIn(app: app)

        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should be visible after launch")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchDarkMode() throws {
        let app = XCUIApplication()
        app.launch()
        try ensureSignedIn(app: app)

        XCTAssertTrue(app.tabBars.firstMatch.exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen - Dark Mode"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
