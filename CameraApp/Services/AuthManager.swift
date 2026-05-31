import Foundation
import Observation
import OSLog
import Supabase

/// Manages authentication state using Supabase Auth (GoTrue).
///
/// Inject into the SwiftUI environment at the app root and observe
/// `isAuthenticated` to gate UI on sign-in status.
@Observable
final class AuthManager {
    // MARK: - State

    /// The currently authenticated Supabase Auth user, if any.
    private(set) var currentUser: Supabase.User?

    /// The current session, if any.
    private(set) var currentSession: Session?

    /// The app-level profile for the signed-in user, loaded from the `profiles` table.
    private(set) var currentProfile: User?

    /// `true` until the initial session check completes (prevents auth-screen flash).
    private(set) var isInitializing = true

    /// `true` while an auth operation (sign in/up/out) is in progress.
    private(set) var isLoading = false

    /// The last auth error message, if any. Views may clear this.
    var errorMessage: String?

    /// Convenience: `true` when a valid session exists.
    var isAuthenticated: Bool {
        currentSession != nil
    }

    /// The authenticated user's UUID, if signed in.
    var userId: UUID? {
        currentUser?.id
    }

    // MARK: - Private

    private var authStateTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.jazzrihal.pinstoria", category: "Auth")

    // MARK: - Input Validation

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func signInValidationError(email: String, password: String) -> String? {
        let email = normalizedEmail(email)
        guard isValidEmail(email) else {
            return "Enter a valid email address."
        }
        guard !password.isEmpty else {
            return "Enter your password."
        }
        return nil
    }

    static func signUpValidationError(email: String, password: String, username: String) -> String? {
        if let signInError = signInValidationError(email: email, password: password) {
            return signInError
        }
        guard password.count >= 8 else {
            return "Password must be at least 8 characters."
        }

        let username = normalizedUsername(username)
        let pattern = #"^[A-Za-z0-9._-]{3,30}$"#
        guard username.range(of: pattern, options: .regularExpression) != nil else {
            return "Username must be 3-30 characters and use only letters, numbers, '.', '_' or '-'."
        }
        return nil
    }

    static func userFacingAuthErrorMessage(for error: Error) -> String {
        let description = error.localizedDescription.lowercased()
        if description.contains("network") || description.contains("offline") {
            return "Check your connection and try again."
        }
        return "We couldn't complete that request. Please try again."
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Profile Loading

    /// Fetches the `profiles` row for the given user ID and stores it on `currentProfile`.
    private func loadProfile(for userId: UUID) async {
        do {
            let profile: PublicSchema.ProfilesSelect = try await SupabaseManager.client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            currentProfile = User(from: profile)
        } catch {
            logger.error("Failed to load profile: \(String(describing: error), privacy: .private)")
            currentProfile = nil
        }
    }

    // MARK: - Lifecycle

    init() {
        listenForAuthChanges()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Initial Session Validation

    /// Validates a restored session by refreshing with the server.
    /// - Network errors are tolerated (offline users keep their session).
    /// - Auth errors (deleted user, revoked token) clear the session.
    private func handleInitialSession(_ session: Session?) async {
        if let session, !session.isExpired {
            do {
                let refreshed = try await SupabaseManager.client
                    .auth.refreshSession()
                currentSession = refreshed
                currentUser = refreshed.user
                await loadProfile(for: refreshed.user.id)
            } catch is URLError {
                // Network error — keep cached session for offline use.
                currentSession = session
                currentUser = session.user
                await loadProfile(for: session.user.id)
            } catch {
                // Auth error — user deleted or token revoked.
                logger.error("Session invalid: \(String(describing: error), privacy: .private)")
                try? await SupabaseManager.client.auth
                    .signOut(scope: .local)
                currentSession = nil
                currentUser = nil
                currentProfile = nil
            }
        } else {
            // No cached session or it's expired — clear state.
            if session != nil {
                try? await SupabaseManager.client.auth
                    .signOut(scope: .local)
            }
            currentSession = nil
            currentUser = nil
            currentProfile = nil
        }
        isInitializing = false
    }

    // MARK: - Auth State Listener

    /// Subscribes to Supabase auth state changes.
    /// The first event emitted is `.initialSession`, which restores any
    /// persisted session — no separate restore call needed.
    private func listenForAuthChanges() {
        authStateTask = Task { [weak self] in
            for await (event, session) in SupabaseManager.client.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession:
                    await handleInitialSession(session)
                case .signedIn, .tokenRefreshed:
                    currentSession = session
                    currentUser = session?.user
                    if let uid = session?.user.id {
                        await loadProfile(for: uid)
                    }
                case .signedOut:
                    currentSession = nil
                    currentUser = nil
                    currentProfile = nil
                default:
                    break
                }
            }
        }
    }

    // MARK: - Sign Up

    /// Create a new account with email, password, and a username.
    ///
    /// The username is passed as user metadata so the server-side trigger
    /// can populate the `profiles` row (which requires a non-null username).
    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let email = Self.normalizedEmail(email)
        let username = Self.normalizedUsername(username)
        if let validationError = Self.signUpValidationError(email: email, password: password, username: username) {
            errorMessage = validationError
            return
        }

        do {
            let response = try await SupabaseManager.client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "username": .string(username),
                    "display_name": .string(username),
                ]
            )
            currentSession = response.session
            currentUser = response.session?.user
        } catch {
            logger.error("Sign-up failed: \(String(describing: error), privacy: .private)")
            errorMessage = Self.userFacingAuthErrorMessage(for: error)
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password.
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let email = Self.normalizedEmail(email)
        if let validationError = Self.signInValidationError(email: email, password: password) {
            errorMessage = validationError
            return
        }

        do {
            let session = try await SupabaseManager.client.auth.signIn(
                email: email,
                password: password
            )
            currentSession = session
            currentUser = session.user
        } catch {
            logger.error("Sign-in failed: \(String(describing: error), privacy: .private)")
            errorMessage = Self.userFacingAuthErrorMessage(for: error)
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user.
    func signOut() async {
        do {
            try await SupabaseManager.client.auth.signOut()
            currentSession = nil
            currentUser = nil
            currentProfile = nil
        } catch {
            logger.error("Sign-out failed: \(String(describing: error), privacy: .private)")
            errorMessage = "We couldn't sign you out. Please try again."
        }
    }
}
