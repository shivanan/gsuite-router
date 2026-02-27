# GSuite Router (macOS)

Native macOS helper that intercepts `.docx` and `.xlsx` files, uploads them to Google Drive/Docs, and stamps those files with metadata that points back to the corresponding Google document.

## Features

- OAuth 2.0 authentication with Google via `ASWebAuthenticationSession` and secure token persistence in the Keychain.
- Automatic upload + conversion of Word/Excel files into Google Docs/Sheets via the Drive v3 API.
- No stub files: routed documents keep their original filename, timestamp, and location. The app stores a JSON blob in an extended attribute so future opens jump straight to Google Docs without another upload.
- Drag-and-drop support for both the app window and the Dock icon, plus Finder double-click handling.
- Multi-account aware UI so you can connect several Google accounts, pick one per upload, and sign out individually.

## Project Layout

```
├── AppBundle/Info.plist         # Bundle metadata & document/URL type declarations
├── scripts/package.sh           # Helper to build + wrap the .app bundle
├── Sources/GSuiteRouter
│   ├── App                      # App delegate + SwiftUI UI layer
│   ├── Authentication           # GoogleAuthenticator + token models
│   ├── Drive                    # DriveUploader and upload plumbing
│   ├── FileRouting              # FileRouter orchestrating conversion + metadata
│   └── Utilities                # Config, Keychain, metadata helpers
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

### Create a distributable `.app`

```
CONFIGURATION=release ./scripts/package.sh
open dist/GSuiteRouter.app
```

The script wraps the compiled binary inside `dist/GSuiteRouter.app`, injects `AppBundle/Info.plist`, and performs an ad-hoc codesign. You can then drag the app into `/Applications` and set it as the default handler for `.docx`/`.xlsx` via Finder’s “Get Info” panel.

## OAuth Scopes Used

- `https://www.googleapis.com/auth/drive.file` – upload and manage files the app creates
- `https://www.googleapis.com/auth/userinfo.email` – display the signed-in account

## Notes & Next Steps

- The current build assumes manual command-line configuration. Consider moving secrets into the macOS Keychain or a compiled config plist for production.
- Drive uploads convert to Google-native formats (`application/vnd.google-apps.document|spreadsheet`). If you need to keep the binary copy, extend `DriveUploader` to toggle conversion or maintain two versions.
- Extended attributes stay with files on APFS/HFS+ but may be stripped by some syncing tools; consider adding a fallback shortcut export for those cases.
- Add an app icon (`Assets.car`) and embed it under `AppBundle/` for a polished build.
- Consider surfacing metadata management (e.g., “Clear Routing Info”) for power users.
