# AGENTS.md

## Cursor Cloud specific instructions

### Product

**Pinstoria** — location-based photo-sharing iOS app (SwiftUI). Talks directly to Supabase; backend schema/tests are in the sibling repo `ios-app-backend` (`repos/ios-app-backend` in this workspace). See that repo’s `AGENTS.md` for Supabase startup (full vs trimmed stack).

### Linux cloud VM vs macOS

| Capability | Linux VM | macOS |
|------------|----------|-------|
| `make format-check` | Yes (SwiftFormat binary) | Yes |
| `make lint`, `make build`, `make run`, `make test*` | No — requires Xcode + Simulator | Yes |

CI lint/format runs on `macos-15` (`.github/workflows/ci.yml`). On Linux, backend hello-world (auth + RPC) is validated in `ios-app-backend`; the app itself cannot be launched here.

### Backend dependency

Required for `make run` and UI tests; not for `make test-unit` (mocks).

1. Start Supabase in `ios-app-backend` (see its `AGENTS.md`).
2. Create git-ignored `CameraApp/Secrets.plist`:

```bash
cd ../ios-app-backend && supabase status -o env
cd ../ios-app
cp Secrets.example.plist CameraApp/Secrets.plist
# SUPABASE_URL=http://127.0.0.1:54321
# SUPABASE_ANON_KEY=<ANON_KEY from supabase status -o env>
```

**UI / E2E sign-in:** `alice@test.com` / `password123` (`CameraAppUITests/XCTestCase+Auth.swift`).

### macOS setup

`make setup` — installs swiftlint, swiftformat, xcodegen via Homebrew, git hooks, and runs `xcodegen generate`.

After adding/moving `.swift` files: `make generate` (see `.cursor/rules/xcodegen.mdc`).

### Gotchas

- SwiftLint on Linux may crash (SourceKitten); run `make lint` on macOS or in CI.
- Pre-commit hook expects Homebrew tools (`scripts/install-hooks.sh`).
- Simulator uses local networking for `http://127.0.0.1:54321` (see `project.yml`); physical devices need a reachable host IP, not localhost.
