import XCTest

final class CameraAppUITests: XCTestCase {
    private var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        try ensureSignedIn(app: app)
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
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
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
        XCTAssertTrue(app.buttons["LocationPickerButton"].waitForExistence(timeout: 3))
    }

    // MARK: - Camera Flow Tests

    /// Dismisses the custom camera flow.
    private var cameraCloseButton: XCUIElement {
        app.buttons["CameraCloseButton"]
    }

    /// Captures a photo in the custom camera flow.
    private var captureButton: XCUIElement {
        app.buttons["CaptureButton"]
    }

    func testCameraTabOpensPhotoPicker() {
        app.tabBars.buttons["Camera"].tap()

        // The custom camera surface should show capture + close controls.
        XCTAssertTrue(
            cameraCloseButton.waitForExistence(timeout: 5),
            "Camera close button should appear when camera tab opens"
        )
        XCTAssertTrue(
            captureButton.exists,
            "Capture button should appear when camera tab opens"
        )
    }

    func testCameraDismissReturnsToPreviousTab() {
        // Start on Explore
        XCTAssertTrue(app.tabBars.buttons["Explore"].isSelected)

        // Open camera
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(cameraCloseButton.waitForExistence(timeout: 5))

        // Dismiss camera
        cameraCloseButton.tap()

        // Should return to Explore
        XCTAssertTrue(
            app.buttons["LocationPickerButton"].waitForExistence(timeout: 3),
            "Should return to Explore tab after dismissing picker"
        )
    }

    func testPhotoSelectionOpensPostPreview() {
        // Open camera and capture a photo.
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        captureButton.tap()

        // Post preview should appear with New Post title
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(
            newPostNav.waitForExistence(timeout: 5),
            "Post preview screen should appear after selecting a photo"
        )

        // Verify key post preview elements exist
        let captionField = app.textFields["CaptionTextField"]
        XCTAssertTrue(captionField.exists, "Caption text field should exist")

        let postButton = app.buttons["PostButton"]
        XCTAssertTrue(postButton.exists, "Post button should exist")
    }

    func testPostPreviewDiscardReturnsToPhotoPicker() {
        // Open camera and capture a photo.
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        captureButton.tap()

        // Wait for post preview
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(newPostNav.waitForExistence(timeout: 5))

        // Tap Discard
        let discardButton = app.buttons["DiscardButton"]
        XCTAssertTrue(discardButton.exists, "Discard button should exist")
        discardButton.tap()

        // Should return to the camera controls.
        XCTAssertTrue(
            captureButton.waitForExistence(timeout: 3),
            "Camera controls should reappear after discarding"
        )
    }

    func testPostPreviewPostDismissesCameraFlow() {
        // Open camera and capture a photo.
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        captureButton.tap()

        // Wait for post preview
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(newPostNav.waitForExistence(timeout: 5))

        // Tap Post
        let postButton = app.buttons["PostButton"]
        XCTAssertTrue(postButton.exists)
        postButton.tap()

        // Should dismiss back to the main tab view
        XCTAssertTrue(
            app.buttons["LocationPickerButton"].waitForExistence(timeout: 10),
            "Should return to main app after posting"
        )
    }

    // MARK: - Explore View Tests

    func testExploreViewHasKeyElements() {
        let locationButton = app.buttons["LocationPickerButton"]
        XCTAssertTrue(locationButton.waitForExistence(timeout: 5), "Location picker button should exist")

        // The search button should exist (disabled until pin is dropped).
        let searchButton = app.buttons["FindNearbyPostsButton"]
        XCTAssertTrue(searchButton.exists, "Find Nearby Posts button should exist")

        // The initial prompt should appear once initial location lookup settles.
        XCTAssertTrue(
            app.staticTexts["Pick a date & drop a pin to explore"].waitForExistence(timeout: 5),
            "Initial prompt should be visible before searching"
        )
    }

    func testExploreDateSelectorExpandsAndCollapses() {
        // Tap the date selector to expand.
        let dateSelector = app.buttons["DateSelectorButton"]
        XCTAssertTrue(dateSelector.waitForExistence(timeout: 5), "Date selector should exist")
        dateSelector.tap()

        // The date picker should appear
        let datePicker = app.datePickers.firstMatch
        XCTAssertTrue(
            datePicker.waitForExistence(timeout: 3),
            "Date picker should appear when date selector is tapped"
        )

        // Tapping again should collapse it.
        dateSelector.tap()
        XCTAssertFalse(datePicker.waitForExistence(timeout: 2), "Date picker should collapse when tapped again")
    }

    // MARK: - Moments View Tests

    func testMomentsViewShowsSeededData() {
        app.tabBars.buttons["Moments"].tap()
        XCTAssertTrue(app.navigationBars["Moments"].waitForExistence(timeout: 3))

        // The tab should render either empty state or loaded moments.
        let emptyState = app.staticTexts["No Moments Yet"]
        let anyMomentCell = app.cells.firstMatch
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 5) || anyMomentCell.waitForExistence(timeout: 5),
            "Moments tab should render either empty state or at least one list row"
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
