import XCTest

final class PostInteractionUITests: XCTestCase {
    private var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "OK", "Continue"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        try ensureSignedIn(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Group 1: Like & Pin Toggle

    func testLikeAndPinOwnPost() {
        navigateToProfileTab()
        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        assertLikeToggle()
        assertPinToggle()
    }

    func testLikeAndPinFriendPost() {
        navigateToFriendsTab()

        let friendRow = app.buttons.matching(identifier: "FriendRow").firstMatch
        XCTAssertTrue(friendRow.waitForExistence(timeout: 8), "At least one friend should exist")
        friendRow.tap()

        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        assertLikeToggle()
        assertPinToggle()
    }

    func testLikeAndPinNonFriendPost() {
        navigateToFriendsTab()
        app.buttons["Add FriendSectionButton"].tap()

        let searchField = app.textFields["Search by username or name…"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should appear")
        searchField.tap()
        searchField.typeText("carol")

        let discoverRow = app.buttons.matching(identifier: "DiscoverUserRow").firstMatch
        XCTAssertTrue(discoverRow.waitForExistence(timeout: 8), "Carol should appear in search results")
        discoverRow.tap()

        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        assertLikeToggle()
        assertPinToggle()
    }

    // MARK: - Group 2: Pin-to-Profile Propagation

    func testPinnedPostAppearsOnOwnProfile() {
        navigateToProfileTab()
        waitForPostCell(0)
        var initialCount = postCellCount()

        navigateToFriendFirstPost()

        // Ensure the post starts unpinned so we can test the pin flow
        let pinButton = app.buttons["PinButton"]
        if pinButton.label == "Unpin" {
            pinButton.tap()
            assertButtonLabel(pinButton, expected: "Pin")
            tapBackButton()
            tapBackButton()

            navigateToProfileTab()
            pullToRefresh()
            sleep(3)
            let adjustedCount = postCellCount()
            initialCount = adjustedCount

            navigateToFriendFirstPost()
        }

        app.buttons["PinButton"].tap()
        assertButtonLabel(app.buttons["PinButton"], expected: "Unpin")

        tapBackButton()
        tapBackButton()

        // Refresh profile and verify count increased
        navigateToProfileTab()
        pullToRefresh()
        sleep(3)
        let countAfterPin = postCellCount()
        XCTAssertEqual(
            countAfterPin, initialCount + 1,
            "Profile should have one more post after pinning a friend's post"
        )

        navigateToFriendFirstPost()

        let pinButtonAgain = app.buttons["PinButton"]
        if pinButtonAgain.label == "Unpin" {
            pinButtonAgain.tap()
            assertButtonLabel(pinButtonAgain, expected: "Pin")
        }

        tapBackButton()
        tapBackButton()

        // Verify profile count is restored
        navigateToProfileTab()
        pullToRefresh()
        sleep(3)
        let countAfterUnpin = postCellCount()
        XCTAssertEqual(
            countAfterUnpin, initialCount,
            "Profile should return to original count after unpinning"
        )
    }

    // MARK: - Group 3: State Persistence & Cross-Tab

    func testLikeAndPinPersistAcrossTabs() {
        navigateToFriendFirstPost()

        let actionBar = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'PostActionBar_'")
        ).firstMatch
        XCTAssertTrue(actionBar.waitForExistence(timeout: 5), "Action bar should exist")
        let targetPostId = actionBar.identifier.replacingOccurrences(of: "PostActionBar_", with: "")
        XCTAssertFalse(targetPostId.isEmpty, "Should extract a post UUID")

        ensureUnlikedAndUnpinned()

        let likeButton = app.buttons["LikeButton"]
        let pinButton = app.buttons["PinButton"]

        likeButton.tap()
        assertButtonLabel(likeButton, expected: "Unlike")
        pinButton.tap()
        assertButtonLabel(pinButton, expected: "Unpin")

        tapBackButton()
        tapBackButton()

        // Navigate to Profile tab where the pinned post should now appear
        navigateToProfileTab()
        pullToRefresh()
        sleep(3)

        // Find the same post on Profile and verify state persisted across tabs
        let found = findPostOnProfile(postId: targetPostId)
        XCTAssertTrue(found, "Post liked and pinned from Friends should appear on Profile tab")

        let likeButtonAfter = app.buttons["LikeButton"]
        let pinButtonAfter = app.buttons["PinButton"]
        assertButtonLabel(likeButtonAfter, expected: "Unlike")
        assertButtonLabel(pinButtonAfter, expected: "Unpin")

        // Clean up
        likeButtonAfter.tap()
        assertButtonLabel(likeButtonAfter, expected: "Like")
        pinButtonAfter.tap()
        assertButtonLabel(pinButtonAfter, expected: "Pin")
    }

    func testLikeAndPinReflectedInExplore() {
        searchSanFranciscoInExplore()

        let firstCell = app.buttons["ExplorePostCell_0"]
        firstCell.tap()
        waitForActionBar()

        let actionBar = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'PostActionBar_'")
        ).firstMatch
        XCTAssertTrue(actionBar.waitForExistence(timeout: 5), "Action bar should exist")
        let targetPostId = actionBar.identifier.replacingOccurrences(of: "PostActionBar_", with: "")
        XCTAssertFalse(targetPostId.isEmpty, "Should extract a post UUID")

        ensureUnlikedAndUnpinned()

        let likeButton = app.buttons["LikeButton"]
        let pinButton = app.buttons["PinButton"]
        likeButton.tap()
        assertButtonLabel(likeButton, expected: "Unlike")
        pinButton.tap()
        assertButtonLabel(pinButton, expected: "Unpin")

        tapBackButton()

        // Navigate to Profile tab where the pinned post should now appear
        navigateToProfileTab()
        pullToRefresh()
        sleep(3)

        // Find the same post on Profile and verify state persisted across tabs
        let found = findPostOnProfile(postId: targetPostId)
        XCTAssertTrue(found, "Post liked and pinned in Explore should appear on Profile tab")

        assertButtonLabel(app.buttons["LikeButton"], expected: "Unlike")
        assertButtonLabel(app.buttons["PinButton"], expected: "Unpin")

        // Clean up
        app.buttons["LikeButton"].tap()
        assertButtonLabel(app.buttons["LikeButton"], expected: "Like")
        app.buttons["PinButton"].tap()
        assertButtonLabel(app.buttons["PinButton"], expected: "Pin")
    }

    // MARK: - Group 4: Owner Edit/Delete

    func testOwnerSeesPostOptionsMenu() {
        navigateToProfileTab()
        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        let optionsButton = app.buttons["PostOptionsMenuButton"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5), "Owner should see post options menu")
        optionsButton.tap()

        XCTAssertTrue(app.buttons["EditPostMenuAction"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["DeletePostMenuAction"].waitForExistence(timeout: 3))
    }

    func testEditPostShowsLockedMetadataAndSaves() {
        navigateToProfileTab()
        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        app.buttons["PostOptionsMenuButton"].tap()
        app.buttons["EditPostMenuAction"].tap()

        XCTAssertTrue(app.navigationBars["Edit Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ImmutablePostMetadataNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.buttons["PostWithoutEditingButton"].exists,
            "Quick create-only action should be hidden in edit mode"
        )
        XCTAssertFalse(
            app.buttons["SaveWithoutUploadingButton"].exists,
            "Draft create-only action should be hidden in edit mode"
        )

        let captionField = app.textFields["CaptionTextField"].firstMatch
        let captionTextView = app.textViews["CaptionTextField"].firstMatch
        if captionField.waitForExistence(timeout: 2) {
            captionField.tap()
            captionField.typeText(" Updated")
        } else {
            XCTAssertTrue(captionTextView.waitForExistence(timeout: 5))
            captionTextView.tap()
            captionTextView.typeText(" Updated")
        }

        let publicScope = app.buttons["ScopeOption_Public"]
        if publicScope.exists {
            publicScope.tap()
        }

        let saveButton = app.buttons["SavePostChangesButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
    }

    func testDeletePostShowsConfirmationAlert() {
        navigateToProfileTab()
        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        app.buttons["PostOptionsMenuButton"].tap()
        app.buttons["DeletePostMenuAction"].tap()

        let deleteAlert = app.alerts["Delete Post?"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5), "Delete confirmation should appear")
        deleteAlert.buttons["Cancel"].tap()
    }

    // MARK: - Group 5: Non-owner Menu Visibility

    func testNonOwnerDoesNotSeePostOptionsFromFriendProfile() throws {
        navigateToFriendsTab()

        let friendRow = app.buttons.matching(identifier: "FriendRow").firstMatch
        if !friendRow.waitForExistence(timeout: 8) {
            throw XCTSkip("No seeded friend rows available in this environment.")
        }
        friendRow.tap()

        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        assertOwnerMenuHidden()
    }

    func testNonOwnerDoesNotSeePostOptionsFromFriendsFeed() {
        navigateToFriendsTab()
        app.buttons["FeedSectionButton"].tap()

        let feedCell = app.buttons["FeedPostCell_0"]
        XCTAssertTrue(feedCell.waitForExistence(timeout: 10), "Friends feed should show at least one post")
        feedCell.tap()
        waitForActionBar()

        assertOwnerMenuHidden()
    }

    func testNonOwnerDoesNotSeePostOptionsFromDiscoveredProfile() {
        navigateToFriendsTab()
        app.buttons["AddFriendSectionButton"].tap()

        let searchField = app.textFields["Search by username or name…"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should appear")
        searchField.tap()
        searchField.typeText("carol")

        let discoverRow = app.buttons.matching(identifier: "DiscoverUserRow").firstMatch
        XCTAssertTrue(discoverRow.waitForExistence(timeout: 8), "At least one discovered user should exist")
        discoverRow.tap()

        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()

        assertOwnerMenuHidden()
    }
}

private extension PostInteractionUITests {
    // MARK: - Navigation Helpers

    func navigateToProfileTab() {
        app.tabBars.buttons["Profile"].tap()
        sleep(2)
    }

    func navigateToFriendsTab() {
        app.tabBars.buttons["Friends"].tap()
        XCTAssertTrue(
            app.navigationBars["Friends"].waitForExistence(timeout: 5),
            "Friends tab should appear"
        )
    }

    func tapBackButton() {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists, backButton.isHittable {
            backButton.tap()
        }
    }

    func pullToRefresh() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown()
        }
    }
}

private extension PostInteractionUITests {
    // MARK: - Post Grid Helpers

    func waitForPostCell(_ index: Int) {
        let cell = app.buttons["PostCell_\(index)"]
        XCTAssertTrue(
            cell.waitForExistence(timeout: 10),
            "PostCell_\(index) should appear"
        )
    }

    func postCellCount() -> Int {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'PostCell_'")
        ).count
    }

    func waitForActionBar() {
        let actionBar = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'PostActionBar_'")
        ).firstMatch
        XCTAssertTrue(
            actionBar.waitForExistence(timeout: 5),
            "Post action bar should appear"
        )
    }

    func assertOwnerMenuHidden() {
        let optionsButton = app.buttons["PostOptionsMenuButton"]
        XCTAssertFalse(
            optionsButton.waitForExistence(timeout: 2),
            "Non-owner should not see post options menu"
        )
    }

    /// Opens PostCells on the Profile grid until finding one whose action bar
    /// matches the given post UUID. Returns true and leaves the post open.
    func findPostOnProfile(postId: String) -> Bool {
        let cellCount = postCellCount()
        for i in 0 ..< cellCount {
            let cell = app.buttons["PostCell_\(i)"]
            guard cell.waitForExistence(timeout: 3) else { continue }
            cell.tap()

            let targetBar = app.otherElements["PostActionBar_\(postId)"]
            if targetBar.waitForExistence(timeout: 3) {
                return true
            }
            tapBackButton()
            sleep(1)
        }
        return false
    }

    func navigateToFriendFirstPost() {
        navigateToFriendsTab()
        let friendRow = app.buttons.matching(identifier: "FriendRow").firstMatch
        XCTAssertTrue(friendRow.waitForExistence(timeout: 8), "At least one friend should exist")
        friendRow.tap()

        waitForPostCell(0)
        app.buttons["PostCell_0"].tap()
        waitForActionBar()
    }
}

private extension PostInteractionUITests {
    // MARK: - Like & Pin Assertion Helpers

    func assertLikeToggle() {
        let likeButton = app.buttons["LikeButton"]
        XCTAssertTrue(likeButton.waitForExistence(timeout: 3), "LikeButton should exist")

        let wasLiked = likeButton.label == "Unlike"

        likeButton.tap()
        assertButtonLabel(likeButton, expected: wasLiked ? "Like" : "Unlike")

        likeButton.tap()
        assertButtonLabel(likeButton, expected: wasLiked ? "Unlike" : "Like")
    }

    func assertPinToggle() {
        let pinButton = app.buttons["PinButton"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3), "PinButton should exist")

        let wasPinned = pinButton.label == "Unpin"

        pinButton.tap()
        assertButtonLabel(pinButton, expected: wasPinned ? "Pin" : "Unpin")

        pinButton.tap()
        assertButtonLabel(pinButton, expected: wasPinned ? "Unpin" : "Pin")
    }

    /// Resets a post's like and pin state to un-liked and un-pinned before
    /// tests that require a known starting state.
    func ensureUnlikedAndUnpinned() {
        let likeButton = app.buttons["LikeButton"]
        if likeButton.waitForExistence(timeout: 3), likeButton.label == "Unlike" {
            likeButton.tap()
            assertButtonLabel(likeButton, expected: "Like")
        }
        let pinButton = app.buttons["PinButton"]
        if pinButton.waitForExistence(timeout: 3), pinButton.label == "Unpin" {
            pinButton.tap()
            assertButtonLabel(pinButton, expected: "Pin")
        }
    }

    func assertButtonLabel(_ button: XCUIElement, expected: String) {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(
            result, .completed,
            "Button label should be '\(expected)' but was '\(button.label)'"
        )
    }
}

private extension PostInteractionUITests {
    // MARK: - Explore Search Helper

    func searchSanFranciscoInExplore() {
        let exploreTab = app.tabBars.buttons["Explore"]
        exploreTab.tap()
        sleep(2)

        XCTAssertTrue(exploreTab.isSelected, "Explore tab should be selected after tapping")

        // Expand the map by tapping the location header
        let locationHeader = app.buttons["LocationPickerButton"]
        XCTAssertTrue(locationHeader.waitForExistence(timeout: 5), "Location picker button should exist")
        XCTAssertTrue(locationHeader.isHittable, "Location picker button should be hittable")
        locationHeader.tap()
        sleep(1)

        // Type in the place search field
        let placeSearchField = app.textFields["Search for a place…"]
        XCTAssertTrue(
            placeSearchField.waitForExistence(timeout: 5),
            "Place search field should appear after expanding map"
        )
        placeSearchField.tap()
        placeSearchField.typeText("San Francisco")
        sleep(2)

        // Tap the first search completion result
        let firstCompletion = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'San Francisco'")
        ).firstMatch
        XCTAssertTrue(
            firstCompletion.waitForExistence(timeout: 8),
            "San Francisco search completion should appear"
        )
        firstCompletion.tap()
        sleep(2)

        // Tap the search button
        let searchButton = app.buttons["FindNearbyPostsButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "Search button should exist")
        searchButton.tap()

        // Wait for results to load
        let firstResult = app.buttons["ExplorePostCell_0"]
        XCTAssertTrue(
            firstResult.waitForExistence(timeout: 15),
            "Explore search results should appear"
        )
    }
}
