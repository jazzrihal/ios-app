import XCTest

extension XCTestCase {
    // Seeded test credentials — defined once, shared by all UI test classes.
    static let testUserEmail = "alice@test.com"
    static let testUserPassword = "password123"

    /// Signs in through the AuthView UI if no session is restored.
    func ensureSignedIn(app: XCUIApplication) throws {
        // Session may be restored from Keychain -- check for tab bar first
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 8) {
            return // Already signed in from a prior test
        }

        let email = Self.testUserEmail
        let password = Self.testUserPassword

        // Auth screen should be visible -- sign in
        let emailField = app.textFields["Email"]
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 5),
            "Auth screen should appear"
        )

        typeText(email, into: emailField)

        let passwordField = app.secureTextFields["Password"]
        typeText(password, into: passwordField)

        let signInButton = app.buttons["AuthActionButton"]
        tapElement(signInButton)

        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 45),
            "Tab bar should appear after sign in"
        )
    }

    func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func typeText(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Text input should exist")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        element.typeText(text)
    }
}
