import Foundation
import Observation
import Supabase

/// Manages authentication state using Supabase Auth (GoTrue).
///
/// Inject into the SwiftUI environment at the app root and observe
/// `isAuthenticated` to gate UI on sign-in status.
@Observable
final class AuthManager {
    // MARK: - State

    /// The currently authenticated user, if any.
    private(set) var currentUser: Supabase.User?

    /// The current session, if any.
    private(set) var currentSession: Session?

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

    // MARK: - Lifecycle

    init() {
        listenForAuthChanges()
    }

    deinit {
        authStateTask?.cancel()
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
                    if let session, session.isExpired {
                        // Session exists but is expired — a background refresh
                        // will fire `.tokenRefreshed` or `.signedOut` next.
                        currentSession = nil
                        currentUser = nil
                    } else {
                        currentSession = session
                        currentUser = session?.user
                    }
                    isInitializing = false
                case .signedIn, .tokenRefreshed:
                    currentSession = session
                    currentUser = session?.user
                case .signedOut:
                    currentSession = nil
                    currentUser = nil
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign In

    /// Sign in with email and password.
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await SupabaseManager.client.auth.signIn(
                email: email,
                password: password
            )
            currentSession = session
            currentUser = session.user
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    /// Sign out the current user.
    func signOut() async {
        do {
            try await SupabaseManager.client.auth.signOut()
            currentSession = nil
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
