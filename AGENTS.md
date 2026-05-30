# AGENTS.md

## Cursor Cloud specific instructions

### Product

**Pinstoria** — location-based photo-sharing iOS app (SwiftUI). Talks directly to Supabase; backend schema/tests are in the sibling repo `ios-app-backend`.

### Linux cloud VM vs macOS

| Capability | Linux VM | macOS |
|------------|----------|-------|
| `make format-check` | Yes (SwiftFormat) | Yes |
| `make lint`, `make build`, `make run`, `make test*` | No — requires Xcode + Simulator | Yes |

CI lint/format runs on `macos-15` (`.github/workflows/ci.yml`).

### Backend dependency

For `make run` and UI tests, start Supabase in `ios-app-backend` and configure secrets:

```bash
cd ../ios-app-backend && supabase status -o env
cp Secrets.example.plist CameraApp/Secrets.plist
# SUPABASE_URL=http://127.0.0.1:54321
# SUPABASE_ANON_KEY=<ANON_KEY from supabase status -o env>
```

Unit tests (`make test-unit`) use mocks and do not need Supabase.

### macOS setup

`make setup` — installs swiftlint, swiftformat, xcodegen via Homebrew, git hooks, and runs `xcodegen generate`.

After adding/moving `.swift` files: `make generate` (see `.cursor/rules/xcodegen.mdc`).

### Gotchas

- SwiftLint on Linux may crash (SourceKitten); run `make lint` on macOS or in CI.
- Pre-commit hook expects Homebrew tools (`scripts/install-hooks.sh`).
