---
name: generate-supabase-types
description: Generate Swift types from the Supabase backend and import them into the iOS project. Use when the user asks to generate backend types, import Supabase types, refresh types, sync types, update database types, or regenerate the types file.
---

# Generate Supabase Types

Regenerate `CameraApp/Models/SupabaseTypes.swift` from the local Supabase database schema in the neighbouring `ios-app-backend` project.

## Prerequisites

The local Supabase instance must be running in `ios-app-backend`. If `make types` fails, prompt the user to start it with `make start` in that directory.

## Workflow

The backend directory is the sibling `ios-app-backend` folder, i.e. `../ios-app-backend` relative to the workspace root.

Run these steps sequentially:

1. **Generate types in the backend project**

Run `make types` using the Shell tool with `working_directory` set to the absolute path of `ios-app-backend`. This produces a `types.swift` file in that directory via `supabase gen types --lang=swift --local`.

2. **Replace the current types file**

Copy the generated file over the existing one:

```bash
cp <backend-dir>/types.swift CameraApp/Models/SupabaseTypes.swift
```

3. **Clean up the generated file**

Remove `types.swift` from the backend directory. This is not editing the backend project — it is cleaning up the build artifact we just created. The backend repo should be left exactly as it was before.

```bash
rm <backend-dir>/types.swift
```

4. **Confirm to the user** that `SupabaseTypes.swift` has been updated.

## Important

- Do **not** edit any source files inside `ios-app-backend`. Only run `make types` there and copy the output.
- Do **not** hand-edit `SupabaseTypes.swift`. It is always overwritten wholesale from the generated output.
- If the types command fails with a connection error, the local Supabase instance likely isn't running.
