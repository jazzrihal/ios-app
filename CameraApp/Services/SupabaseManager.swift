import Foundation
import Supabase

/// Central access point for the Supabase client.
///
/// Configure your project URL and anon key before first use:
/// 1. Copy `Secrets.example.plist` → `CameraApp/Secrets.plist`  (git-ignored)
/// 2. Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY`
///
/// Or set them directly as environment constants below during development.
enum SupabaseManager {
    // MARK: - Configuration

    /// Replace with your Supabase project URL, or load from Secrets.plist / environment.
    private static let projectURL: URL = {
        guard let urlString = configValue(for: "SUPABASE_URL"),
              let url = URL(string: urlString)
        else {
            fatalError("Missing SUPABASE_URL – see SupabaseManager.swift for setup instructions.")
        }
        return url
    }()

    /// Replace with your Supabase anon (public) key.
    private static let anonKey: String = {
        guard let key = configValue(for: "SUPABASE_ANON_KEY"), !key.isEmpty else {
            fatalError("Missing SUPABASE_ANON_KEY – see SupabaseManager.swift for setup instructions.")
        }
        return key
    }()

    // MARK: - Client

    /// Shared Supabase client instance used throughout the app.
    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey,
        options: .init(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    // MARK: - Storage Helpers

    /// Returns the public URL for an image stored in the `post-images` bucket.
    ///
    /// - Parameter path: The storage path (e.g. `"{userId}/{postId}.jpg"`).
    /// - Returns: A fully-qualified public URL.
    static func imageURL(for path: String) -> URL {
        // swiftlint:disable:next force_try
        try! client.storage.from("post-images").getPublicURL(path: path)
    }

    // MARK: - Config Helpers

    /// Reads a value from `Secrets.plist` bundled in the app.
    private static func configValue(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict[key] as? String
        else {
            return nil
        }
        return value
    }
}
