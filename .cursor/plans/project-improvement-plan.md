# CameraApp — Project Improvement Plan

## Priority Roadmap

| # | Task | Status |
|---|------|--------|
| 1 | Add unit tests (CameraAppTests target) | Pending |
| 2 | Integrate SwiftLint | Pending |
| 3 | Add image caching (Kingfisher or Nuke) to replace bare AsyncImage | Pending |
| 4 | Extract ViewModels from large views (e.g. PostDetailView at 545 lines) | Pending |
| 5 | Enable strict Swift concurrency (`SWIFT_STRICT_CONCURRENCY = complete`) | Pending |
| 6 | Add code coverage reporting to CI | Pending |
| 7 | Add Fastlane for signing & deployment automation | Pending |
| 8 | Add crash reporting (Firebase Crashlytics or Sentry) | Pending |
| 9 | Add a Makefile / Justfile for common developer commands | Pending |
| 10 | Add pre-commit hooks (SwiftLint + SwiftFormat) | Pending |

## Key Gaps Today

- **No unit tests** — only UI tests exist. Pure logic in `ImagePost`, `MomentsStore`, etc. is untested.
- **No linting or formatting** — no SwiftLint, no SwiftFormat.
- **No image caching** — `AsyncImage` has no disk cache; Explore feed will be slow and re-download on every appearance.
- **No persistence layer** — SwiftData is available (iOS 17+ target).
- **No networking abstraction** — sample data only; no `APIClient` protocol.
- **No crash reporting or analytics** — essential before production.

---

## 1. Swift Code Quality

### SwiftLint

- Add SwiftLint via SPM plugin or Homebrew build phase.
- Add a `.swiftlint.yml` at the project root to customize rules.
- Run in CI before the build step.

### SwiftFormat

- Use SwiftFormat to auto-fix style (indentation, spacing, braces).
- Run as a pre-commit hook so diffs stay clean.

### Strict Concurrency

- Enable `SWIFT_STRICT_CONCURRENCY = complete` in build settings.
- Mark classes that update UI state as `@MainActor` (e.g. `CameraModel`).
- Audit `DispatchQueue.global` usage — prefer Swift concurrency (`Task`, actors).
- Watch for retained `CheckedContinuation` — if the delegate never fires, it leaks.

### Architecture

- **Extract ViewModels**: Views over ~200 lines should have a separate `@Observable` ViewModel.
  - `PostDetailView` (545 lines) mixes gesture logic, animation state, and action handling — split it.
- **Protocol-oriented DI**: Extract protocols for services (e.g. `CameraServiceProtocol`) so they can be mocked in tests and previews.
- **One file, one concern**: Keep models, views, and business logic in separate files.

---

## 2. Testing Strategy

### Unit Tests (High Priority — Currently Missing)

Add a `CameraAppTests` target in `project.yml`. Focus first on pure logic:

- `ImagePost.distanceFormatted` — boundary at 1000m
- `ImagePost.timeAgoFormatted` — various time intervals
- `ImagePost.offsetFromQuery(_:)` — all branches (< 60s, < 3600s, < 86400s, before/after)
- `MomentsStore.addMoment(...)` — verify array mutation
- `ImagePost.sampleUserPosts(for:isFriend:)` — scope filtering logic

Example pattern:

```swift
@Test func distanceFormatted_underOneKm() {
    let post = makePost(distanceMeters: 500)
    #expect(post.distanceFormatted == "500 m away")
}
```

### UI Tests (Already Good)

- Continue using `.accessibilityIdentifier(...)` on all interactive elements.
- Keep UI tests focused on user flows, not implementation details.
- Use `waitForExistence(timeout:)` rather than fixed sleeps.

### Coverage

- Add `-enableCodeCoverage YES` to the `xcodebuild` CI step.
- Upload results to Codecov or similar.
- Aim for >80% on model/store logic; UI coverage via UI tests.

---

## 3. CI/CD Improvements

### GitHub Actions Enhancements

Current workflow is functional. Recommended additions:

1. **Cache Homebrew & DerivedData** — use `actions/cache` to speed up builds.
2. **Add a SwiftLint step** before building to catch style issues early.
3. **Enable code coverage** — add `-enableCodeCoverage YES` and upload to Codecov.
4. **Replace xcpretty with xcbeautify** — actively maintained, better output formatting.
5. **Add parallel testing** — `-parallel-testing-enabled YES` to speed up test suite.
6. **Add test timeouts** — `-test-timeouts-enabled YES` to catch hung tests.
7. **Add Danger** — automated PR reviews (missing tests, large diffs, TODOs).

### Fastlane

Adopt Fastlane for deployment automation:

- `match` — manage code signing across team members.
- `scan` — run tests with richer output.
- `pilot` — automate TestFlight uploads.
- `deliver` — automate App Store submissions.
- `snapshot` — automated screenshot generation.

### Makefile / Justfile

Create a `Makefile` at the project root with standard commands:

- `make generate` — run `xcodegen generate`
- `make lint` — run `swiftlint lint --strict`
- `make format` — run `swiftformat .`
- `make test` — run `xcodebuild test ...`
- `make clean` — remove `DerivedData` and `build/`

---

## 4. Networking & Data Layer

### Image Caching (High Priority)

`AsyncImage` has no disk cache — images re-download on every view appearance. Replace with:

- **Kingfisher** — full-featured, SwiftUI `KFImage` drop-in, disk + memory cache.
- **Nuke** — lightweight, modern Swift concurrency, `LazyImage` view.

Apply in: `PostDetailView`, `PostCard`, `ExploreView`, `FriendProfileView`.

### Networking Layer

When moving beyond sample data, create a structured API client:

```swift
protocol APIClient: Sendable {
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}
```

- Use `URLSession` with async/await.
- Or adopt **Alamofire** for interceptors, retry, and certificate pinning.

### Persistence

- **SwiftData** — available on iOS 17+ (your minimum target). Use for moments, posts, and user data.
- **Keychain** — for auth tokens and sensitive data. Use **KeychainAccess** wrapper.
- **UserDefaults** — only for simple preferences (e.g. onboarding completed flag).

### Secrets Management

- Use `.xcconfig` files for API keys, loaded via build settings.
- Never hardcode secrets in Swift source files.
- In CI, pass secrets via GitHub Actions secrets and environment variables.

---

## 5. SwiftUI Best Practices

### Previews

- Add `#Preview` to **every** view, not just `PostDetailView`.
- Include multiple configurations: light/dark mode, different data states, Dynamic Type sizes.
- Use mock data and protocol-based DI to avoid real service dependencies in previews.

### Accessibility

- Continue using `.accessibilityIdentifier(...)` on all interactive elements (already done well).
- Add `.accessibilityLabel(...)` and `.accessibilityHint(...)` for VoiceOver support.
- Test with Accessibility Inspector in Xcode.

### Performance

- Profile gesture-heavy views (PostDetailView) with Instruments > SwiftUI template.
- Avoid creating `DateFormatter` / `RelativeDateTimeFormatter` on every call — cache them as static properties.
- Use `LazyVStack` / `LazyHGrid` for scrollable lists of posts.
- Prefer `@Observable` (iOS 17+) over `@ObservableObject` for fine-grained updates (already doing this).

### Patterns

- Keep views under ~200 lines. Extract sub-views and ViewModels.
- Use `ViewModifier` for reusable styling (e.g. card styles, shimmer loading).
- Prefer `environment(...)` for dependency injection (already doing this with stores).

### Haptics

- Good use of `UIImpactFeedbackGenerator` in PostDetailView.
- Consider `UISelectionFeedbackGenerator` for tab switches and picker changes.

---

## 6. Production Readiness

### Crash Reporting

- **Firebase Crashlytics** or **Sentry** — real-time crash reports with symbolicated stack traces, breadcrumbs, and user context.

### Analytics

- **Firebase Analytics**, **Mixpanel**, or **PostHog** for understanding user behavior.

### Security

- `.gitignore` already includes `.env` — good.
- Use environment variables in CI and `.xcconfig` files rather than hardcoded strings.
- Be aware of App Transport Security (ATS) exceptions when integrating third-party SDKs.
