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

    /// The last non-error auth message, if any. Views may clear this.
    var infoMessage: String?

    /// Convenience: `true` when a valid session exists.
    var isAuthenticated: Bool {
        currentSession != nil
    }

    /// The authenticated user's UUID, if signed in.
    var userId: UUID? {
        currentUser?.id
    }

    // MARK: - Private

    private static let signUpConfirmationMessage =
        "Account request received. Check your email for a confirmation link, " +
        "then confirm your email before signing in."

    private var authStateTask: Task<Void, Never>?

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
            print("[AuthManager] Failed to load profile: \(error)")
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
                print("[AuthManager] Session invalid: \(error)")
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
    @discardableResult
    func signUp(email: String, password: String, username: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

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
            infoMessage = Self.signUpConfirmationMessage
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password.
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
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
            currentProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
