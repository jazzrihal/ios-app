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

        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(password)

        let signInButton = app.buttons["AuthActionButton"]
        signInButton.tap()

        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 15),
            "Tab bar should appear after sign in"
        )
    }
}
