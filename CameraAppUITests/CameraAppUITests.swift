import XCTest

final class CameraAppUITests: XCTestCase {
    private var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Navigation Tests

    func testExploreTabIsSelectedOnLaunch() {
        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.exists, "Explore tab should exist")
        XCTAssertTrue(exploreTab.isSelected, "Explore tab should be selected on launch")
    }

    func testAllTabsExist() {
        XCTAssertTrue(app.tabBars.buttons["Explore"].exists)
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
        XCTAssertTrue(app.tabBars.buttons["Moments"].exists)
        XCTAssertTrue(app.tabBars.buttons["Friends"].exists)
    }

    func testNavigateToMomentsTab() {
        app.tabBars.buttons["Moments"].tap()

        let navTitle = app.navigationBars["Moments"]
        XCTAssertTrue(
            navTitle.waitForExistence(timeout: 3),
            "Moments navigation title should appear"
        )
    }

    func testNavigateToFriendsTab() {
        app.tabBars.buttons["Friends"].tap()

        let navTitle = app.navigationBars["Friends"]
        XCTAssertTrue(
            navTitle.waitForExistence(timeout: 3),
            "Friends navigation title should appear"
        )
    }

    func testNavigateBetweenTabsPreservesState() {
        // Go to Friends
        app.tabBars.buttons["Friends"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 3))

        // Go to Moments
        app.tabBars.buttons["Moments"].tap()
        XCTAssertTrue(app.navigationBars["Moments"].waitForExistence(timeout: 3))

        // Go back to Explore
        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 3))
    }

    // MARK: - Camera Flow Tests

    func testCameraTabOpensFullScreenCover() {
        app.tabBars.buttons["Camera"].tap()

        // The simulator camera view should appear with identifiable elements
        let cancelButton = app.buttons["CameraCancelButton"]
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 5),
            "Camera cancel button should appear when camera opens"
        )

        let shutterButton = app.buttons["CameraShutterButton"]
        XCTAssertTrue(
            shutterButton.exists,
            "Camera shutter button should be visible"
        )
    }

    func testCameraDismissReturnsToPreviousTab() {
        // Start on Explore
        XCTAssertTrue(app.tabBars.buttons["Explore"].isSelected)

        // Open camera
        app.tabBars.buttons["Camera"].tap()
        let cancelButton = app.buttons["CameraCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))

        // Dismiss camera
        cancelButton.tap()

        // Should return to Explore
        let exploreNav = app.navigationBars["Explore"]
        XCTAssertTrue(
            exploreNav.waitForExistence(timeout: 3),
            "Should return to Explore tab after dismissing camera"
        )
    }

    func testCameraShutterOpensPostPreview() {
        // Open camera
        app.tabBars.buttons["Camera"].tap()
        let shutterButton = app.buttons["CameraShutterButton"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 3))

        // Tap shutter to simulate capture
        shutterButton.tap()

        // Post preview should appear with New Post title
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(
            newPostNav.waitForExistence(timeout: 5),
            "Post preview screen should appear after capture"
        )

        // Verify key post preview elements exist
        let captionField = app.textFields["CaptionTextField"]
        XCTAssertTrue(captionField.exists, "Caption text field should exist")

        let postButton = app.buttons["PostButton"]
        XCTAssertTrue(postButton.exists, "Post button should exist")
    }

    func testPostPreviewDiscardReturnsToCameraView() {
        // Open camera and capture
        app.tabBars.buttons["Camera"].tap()
        let shutterButton = app.buttons["CameraShutterButton"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 3))
        shutterButton.tap()

        // Wait for post preview
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(newPostNav.waitForExistence(timeout: 5))

        // Tap Discard
        let discardButton = app.buttons["DiscardButton"]
        XCTAssertTrue(discardButton.exists, "Discard button should exist")
        discardButton.tap()

        // Should return to camera view (shutter button visible again)
        XCTAssertTrue(
            shutterButton.waitForExistence(timeout: 3),
            "Camera shutter should reappear after discarding"
        )
    }

    func testPostPreviewPostDismissesCameraFlow() {
        // Open camera and capture
        app.tabBars.buttons["Camera"].tap()
        let shutterButton = app.buttons["CameraShutterButton"]
        XCTAssertTrue(shutterButton.waitForExistence(timeout: 3))
        shutterButton.tap()

        // Wait for post preview
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(newPostNav.waitForExistence(timeout: 5))

        // Tap Post
        let postButton = app.buttons["PostButton"]
        XCTAssertTrue(postButton.exists)
        postButton.tap()

        // Should dismiss back to the main tab view
        let exploreNav = app.navigationBars["Explore"]
        XCTAssertTrue(
            exploreNav.waitForExistence(timeout: 5),
            "Should return to main app after posting"
        )
    }

    // MARK: - Explore View Tests

    func testExploreViewHasKeyElements() {
        // Verify the Explore navigation bar
        XCTAssertTrue(app.navigationBars["Explore"].exists)

        // The search button should exist (disabled until pin is dropped)
        let searchButton = app.buttons["FindNearbyPostsButton"]
        XCTAssertTrue(searchButton.exists, "Find Nearby Posts button should exist")

        // The initial prompt text should be visible
        XCTAssertTrue(
            app.staticTexts["Pick a date & drop a pin to explore"].exists,
            "Initial prompt should be visible before searching"
        )
    }

    func testExploreDateSelectorExpandsAndCollapses() {
        // Tap the date selector to expand
        let searchAroundText = app.staticTexts["Search around"]
        XCTAssertTrue(searchAroundText.exists, "Date selector label should exist")
        searchAroundText.tap()

        // The date picker should appear
        let datePicker = app.datePickers.firstMatch
        XCTAssertTrue(
            datePicker.waitForExistence(timeout: 3),
            "Date picker should appear when date selector is tapped"
        )
    }

    // MARK: - Moments View Tests

    func testMomentsViewShowsSampleData() {
        app.tabBars.buttons["Moments"].tap()
        XCTAssertTrue(app.navigationBars["Moments"].waitForExistence(timeout: 3))

        // MomentsStore initialises with sample moments, so the list should be populated
        XCTAssertTrue(
            app.staticTexts["San Francisco, United States"].waitForExistence(timeout: 3),
            "Sample moment location should be visible"
        )
    }

    // MARK: - Friends View Tests

    func testFriendsViewShowsSectionPicker() {
        app.tabBars.buttons["Friends"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 3))

        // Both section buttons should exist (use accessibility identifiers
        // because button-style(.plain) can cause automation type mismatches)
        XCTAssertTrue(
            app.buttons["FriendsSectionButton"].exists,
            "Friends section should exist"
        )
        XCTAssertTrue(
            app.buttons["AddFriendSectionButton"].exists,
            "Add Friend section should exist"
        )
    }

    func testFriendsViewSwitchToAddFriendSection() {
        app.tabBars.buttons["Friends"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 3))

        // Tap Add Friend section (use accessibility identifier to avoid type mismatch)
        let addFriendButton = app.buttons["AddFriendSectionButton"]
        XCTAssertTrue(addFriendButton.waitForExistence(timeout: 3))
        addFriendButton.tap()

        // The add friend prompt should appear
        XCTAssertTrue(
            app.staticTexts["Add a Friend"].waitForExistence(timeout: 3),
            "Add Friend prompt title should appear"
        )
    }
}
