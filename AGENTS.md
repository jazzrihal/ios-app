# AGENTS.md

## Cursor Cloud specific instructions

### Product

**Pinstoria** — location-based photo-sharing iOS app (SwiftUI). Talks directly to Supabase; backend schema/tests are in the sibling repo `ios-app-backend` (`repos/ios-app-backend` in this workspace). See that repo’s `AGENTS.md` for Supabase startup (full vs trimmed stack).

### Linux cloud VM vs macOS

| Capability | Linux VM | macOS |
|------------|----------|-------|
| `make format-check` | Yes (SwiftFormat binary) | Yes |
| `make lint`, `make build`, `make run`, `make test*` | No — requires Xcode + Simulator | Yes |

CI on `macos-15` (`.github/workflows/ci.yml`): **lint/format → one build-for-testing → unit tests + UI smoke tests without rebuilding** (two XCTest UI cases: sign-in + Explore tab + tab bar; not the full `CameraAppUITests` / `PostInteractionUITests` suites). UI smoke tests use a hosted Supabase test project via `CI_SUPABASE_URL` and `CI_SUPABASE_ANON_KEY` GitHub Actions variables, then run `supabase db reset --db-url "$CI_SUPABASE_DB_URL"` from the checked-out `ios-app-backend` repo so backend migrations and `seed.sql` are the source of truth. Cloud Agents on Linux should **push a branch and rely on these checks**; run `make test` on macOS before large UI changes.

On Linux: backend hello-world (auth + RPC) in `ios-app-backend`; `make format-check` here; app Simulator runs require macOS or CI.

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

### CI helpers (macOS / GitHub Actions)

- `scripts/ci-resolve-simulator.sh` — picks an available iPhone simulator (`DEVICE` overrides).
- `scripts/ci-write-secrets.sh placeholder` — dummy `Secrets.plist` for build/unit tests.
- `scripts/ci-write-secrets.sh local` — requires `API_URL` and `ANON_KEY` from `supabase status -o env` (UI tests).
- `scripts/ci-write-secrets.sh hosted` — requires `CI_SUPABASE_URL` and `CI_SUPABASE_ANON_KEY` from GitHub Actions secrets (UI smoke tests).

### Gotchas

- SwiftLint on Linux may crash (SourceKitten); run `make lint` on macOS or in CI.
- Pre-commit hook expects Homebrew tools (`scripts/install-hooks.sh`).
- Simulator uses local networking for `http://127.0.0.1:54321` (see `project.yml`); physical devices need a reachable host IP, not localhost.
- CI UI smoke tests assume the hosted Supabase project is dedicated to CI because `supabase db reset --db-url` is destructive.
