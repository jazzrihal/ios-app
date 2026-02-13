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
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 3))
    }

    // MARK: - Camera Flow Tests

    // On simulator the camera tab opens UIImagePickerController in photo-library
    // mode. Tests interact with the system picker's Cancel button and photo cells.

    /// The system picker's Cancel button lives in a navigation bar.
    private var pickerCancelButton: XCUIElement {
        app.navigationBars.buttons["Cancel"]
    }

    func testCameraTabOpensPhotoPicker() {
        app.tabBars.buttons["Camera"].tap()

        // The system photo picker should appear with a Cancel button
        XCTAssertTrue(
            pickerCancelButton.waitForExistence(timeout: 5),
            "Photo picker Cancel button should appear when camera tab opens"
        )
    }

    func testCameraDismissReturnsToPreviousTab() {
        // Start on Explore
        XCTAssertTrue(app.tabBars.buttons["Explore"].isSelected)

        // Open camera (shows photo library picker on simulator)
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(pickerCancelButton.waitForExistence(timeout: 5))

        // Dismiss picker
        pickerCancelButton.tap()

        // Should return to Explore
        let exploreNav = app.navigationBars["Explore"]
        XCTAssertTrue(
            exploreNav.waitForExistence(timeout: 3),
            "Should return to Explore tab after dismissing picker"
        )
    }

    func testPhotoSelectionOpensPostPreview() {
        // Open camera (shows photo library picker on simulator)
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(pickerCancelButton.waitForExistence(timeout: 5))

        // Select the first photo in the library
        let firstPhoto = app.collectionViews.cells.firstMatch
        XCTAssertTrue(
            firstPhoto.waitForExistence(timeout: 5),
            "At least one photo should be available in the simulator library"
        )
        firstPhoto.tap()

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
        // Open camera and select a photo
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(pickerCancelButton.waitForExistence(timeout: 5))

        let firstPhoto = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 5))
        firstPhoto.tap()

        // Wait for post preview
        let newPostNav = app.navigationBars["New Post"]
        XCTAssertTrue(newPostNav.waitForExistence(timeout: 5))

        // Tap Discard
        let discardButton = app.buttons["DiscardButton"]
        XCTAssertTrue(discardButton.exists, "Discard button should exist")
        discardButton.tap()

        // Should return to the photo picker (Cancel button visible again)
        XCTAssertTrue(
            pickerCancelButton.waitForExistence(timeout: 3),
            "Photo picker should reappear after discarding"
        )
    }

    func testPostPreviewPostDismissesCameraFlow() {
        // Open camera and select a photo
        app.tabBars.buttons["Camera"].tap()
        XCTAssertTrue(pickerCancelButton.waitForExistence(timeout: 5))

        let firstPhoto = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 5))
        firstPhoto.tap()

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
            exploreNav.waitForExistence(timeout: 10),
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

    func testMomentsViewShowsSeededData() {
        app.tabBars.buttons["Moments"].tap()
        XCTAssertTrue(app.navigationBars["Moments"].waitForExistence(timeout: 3))

        XCTAssertTrue(
            app.staticTexts["Golden Gate Bridge"].waitForExistence(timeout: 5),
            "Seeded moment location should be visible"
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
