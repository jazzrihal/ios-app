# Pinstoria iOS

SwiftUI iOS client for Pinstoria, a location-based photo-sharing app. The app talks directly to Supabase; backend migrations, seed data, storage setup, and pgTAP tests are in the sibling `ios-app-backend` repo.

## Requirements

- macOS with Xcode 16+ and an iOS Simulator for build, run, and tests
- Homebrew for `swiftlint`, `swiftformat`, and `xcodegen`
- Local or hosted Supabase credentials in `CameraApp/Secrets.plist`

Linux cloud agents can run `make format-check` when SwiftFormat is installed, but Xcode, Simulator, and reliable SwiftLint validation require macOS or CI.

## Setup

```bash
make setup
cp Secrets.example.plist CameraApp/Secrets.plist
```

Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `CameraApp/Secrets.plist`. For local development, start the backend in `../ios-app-backend`, run `make reset`, then read values with `supabase status -o env`.

## Common commands

```bash
make generate       # regenerate CameraApp.xcodeproj from project.yml
make format         # apply SwiftFormat
make format-check   # check formatting
make lint           # strict SwiftLint
make quality        # format, then lint
make build          # build for the configured Simulator
make test-unit      # unit tests only
make test           # unit + UI tests
make run            # build, install, and launch in Simulator
```

Before committing frontend changes, run:

```bash
make format-check && make lint
```

On Linux, run `make format-check` if SwiftFormat is installed and rely on macOS/CI for `make lint`.

## Project notes

- `CameraApp.xcodeproj` is generated from `project.yml`; run `make generate` after adding, removing, moving, or renaming Swift files.
- `CameraApp/Models/SupabaseTypes.swift` is generated from the backend schema; do not edit it by hand.
- UI tests use seeded users from the backend: `alice@test.com`, `bob@test.com`, and `carol@test.com` with password `password123`.
