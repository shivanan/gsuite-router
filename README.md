# GSuite Router (macOS)

Native macOS helper that intercepts `.docx` and `.xlsx` files, uploads them to Google Drive/Docs, and replaces the local files with lightweight `.gdoc` shortcuts that point back to Google Docs.

## Features

- OAuth 2.0 authentication with Google via `ASWebAuthenticationSession` and secure token persistence in the Keychain.
- Automatic upload + conversion of Word/Excel files into Google Docs/Sheets via the Drive v3 API.
- Local hygiene: moves the original file to the Trash, then creates a `*.gdoc` JSON shortcut storing the canonical web link.
- Opening a `*.gdoc` file rehydrates the stored link and launches it in the default browser.
- Simple SwiftUI-based status window showing auth state and last routing activity, plus a manual “Choose Files…” workflow.
- Connect multiple Google accounts, pick which one to use per upload, and sign out of each individually.
- The original Office payload is cached under `~/.gsuiterouter/originals/<hash>` so future restore tooling can rebuild the binary file without bloating the `.gdoc` marker.
- Shortcut files inherit the original document’s creation/modification timestamps and other common file attributes so Finder sorting stays intact.
- Built-in menu item installs a Finder Quick Action (“Restore Original”) that invokes the CLI restore helper without extra setup.

## Project Layout

```
├── AppBundle/Info.plist         # Bundle metadata & document/URL type declarations
├── scripts/package.sh           # Helper to build + wrap the .app bundle
├── Sources/GSuiteRouter
│   ├── App                      # App delegate + SwiftUI UI layer
│   ├── Authentication           # GoogleAuthenticator + token models
│   ├── Drive                    # DriveUploader and upload plumbing
│   ├── FileRouting              # FileRouter orchestrating conversion + shortcuts
│   └── Utilities                # Config, Keychain, file helpers
└── .env.example                 # Template for required environment variables
```

## Prerequisites

1. Create an OAuth Client ID in Google Cloud Console (Desktop app type).
2. Copy `.env.example` to `.env` (or export the vars in your shell) and fill in:

```
GOOGLE_CLIENT_ID=XXX.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=secret-from-console
# Optional: limit uploads to a Drive folder
GOOGLE_DRIVE_FOLDER_ID=drive-folder-id
```

The app automatically launches your default browser for OAuth and listens on `http://127.0.0.1:<random-port>/oauth2redirect`, so no custom redirect registration is needed. Make sure the environment variables are present whenever you run or package the app (e.g. `env $(cat .env | xargs) swift run`).

## Building & Running

### SwiftPM build for iterative testing

```
# From the repo root
swift run
```

This launches the Cocoa app directly (SwiftPM spawns an `.app` bundle automatically when you run the executable). Once authenticated, double-clicking a `.docx`/`.xlsx` file and choosing GSuite Router as the handler will trigger the routing flow.

### CLI restore helper

```
swift run -- --restore /path/to/file.gdoc
```

The `--restore` flag reconstructs the original Office document beside the `.gdoc` shortcut (using the cached copy in `~/.gsuiterouter/originals`). You can pass multiple `.gdoc` paths, making it easy to wire into Automator or Shortcuts.

### Create a distributable `.app`

```
CONFIGURATION=release ./scripts/package.sh
open dist/GSuiteRouter.app
```

The script wraps the compiled binary inside `dist/GSuiteRouter.app`, injects `AppBundle/Info.plist`, and performs an ad-hoc codesign. You can then drag the app into `/Applications` and set it as the default handler for `.docx`/`.xlsx`/`.gdoc` via Finder’s “Get Info” panel.

## OAuth Scopes Used

- `https://www.googleapis.com/auth/drive.file` – upload and manage files the app creates
- `https://www.googleapis.com/auth/userinfo.email` – display the signed-in account

## Notes & Next Steps

- The current build assumes manual command-line configuration. Consider moving secrets into the macOS Keychain or a compiled config plist for production.
- Drive uploads convert to Google-native formats (`application/vnd.google-apps.document|spreadsheet`). If you need to keep the binary copy, extend `DriveUploader` to toggle conversion.
- To support `.pptx`, add another `ConversionTarget` case plus UTI registrations in `AppBundle/Info.plist`.
- Add an app icon (`Assets.car`) and embed it under `AppBundle/` for a polished build.
- Consider monitoring the Trash operation for failures (e.g., lack of permissions) and surface better error UI.
