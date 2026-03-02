# Glint (macOS)

Native macOS helper that intercepts `.docx` and `.xlsx` files, uploads them to Google Drive/Docs, and stamps those files with metadata that points back to the corresponding Google document.

## Features

- OAuth 2.0 authentication with Google via `ASWebAuthenticationSession` and secure token persistence in the Keychain.
- Automatic upload + conversion of Word/Excel files into Google Docs/Sheets via the Drive v3 API.
- No stub files: routed documents keep their original filename, timestamp, and location. The app stores a JSON blob in an extended attribute so future opens jump straight to Google Docs without another upload.
- Drag-and-drop support for both the app window and the Dock icon, plus Finder double-click handling.
- Multi-account aware UI so you can connect several Google accounts, pick one per upload, and sign out individually.
- Optional per-account Drive folders, so each account can route uploads into its own named directory.

## Project Layout

```
├── AppBundle/Info.plist         # Bundle metadata & document/URL type declarations
├── AppBundle/Secrets.plist.template  # Template for baking OAuth keys into the app
├── scripts/package.sh           # Helper to build + wrap the .app bundle
├── Sources/Glint
│   ├── App                      # App delegate + SwiftUI UI layer
│   ├── Authentication           # GoogleAuthenticator + token models
│   ├── Drive                    # DriveUploader and upload plumbing
│   ├── FileRouting              # FileRouter orchestrating conversion + metadata
│   └── Utilities                # Config, Keychain, metadata helpers
└── .env.example                 # Template for required environment variables
```

## Prerequisites

1. Create an OAuth Client ID in Google Cloud Console (Desktop app type).
2. Populate `AppBundle/Secrets.plist` with your OAuth credentials. The file is git-ignored; start from `AppBundle/Secrets.plist.template` or let the packaging script generate it for you (see below). When running a dev build via `swift run`, you can still fall back to environment variables (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, optional `GOOGLE_DRIVE_FOLDER_ID`) if the secrets file is missing.

The app automatically launches your default browser for OAuth and listens on `http://127.0.0.1:<random-port>/oauth2redirect`, so no custom redirect registration is needed.

## Building & Running

### SwiftPM build for iterative testing

```
# From the repo root
cp AppBundle/Secrets.plist.template AppBundle/Secrets.plist   # edit locally with real values
swift run
```

This launches the Cocoa app directly (SwiftPM spawns an `.app` bundle automatically when you run the executable). Once authenticated, double-clicking a `.docx`/`.xlsx` file and choosing Glint as the handler will trigger the routing flow.

### Create a distributable `.app`

```
GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com \
GOOGLE_CLIENT_SECRET=secret \
CONFIGURATION=release ./scripts/package.sh
open dist/Glint.app
```

`package.sh` now requires the OAuth secrets (either pre-populated `AppBundle/Secrets.plist` or exported env vars). It emits a Secrets.plist, copies it into `Contents/Resources`, wraps the compiled binary inside `dist/Glint.app`, and performs an ad-hoc codesign. You can then drag the app into `/Applications` and set it as the default handler for `.docx`/`.xlsx`.

### Xcode project

Prefer Xcode? Open `Glint.xcodeproj` and select the Glint scheme. The project points at the same `Sources/Glint` tree and uses `AppBundle/Info.plist`, so you get full IDE support, debugging, and signing customization. Before you hit Run:

1. Copy the template: `cp AppBundle/Secrets.plist.template AppBundle/Secrets.plist`.
2. Fill in the real `GoogleClientID`, `GoogleClientSecret`, and optional Drive folder ID.

Because the secrets file lives inside `AppBundle/` (and is git-ignored), both SwiftPM and Xcode builds automatically bake it into the bundle, so you don’t have to set scheme environment variables unless you prefer that workflow.

## Software Updates via Sparkle 2

Glint embeds Sparkle 2 (`SPUStandardUpdaterController`) and exposes **Glint ▸ Check for Updates…** in the app menu. Automatic checks are enabled through `SUEnableAutomaticChecks` in `AppBundle/Info.plist`, and the default feed URL is `https://updates.glint.statictype.org/appcast.xml`. Point that URL at any HTTPS endpoint that serves a Sparkle-compatible RSS feed.

If you deploy releases with Next.js, copy `docs/NextJSAppcastRouteExample.ts` into `app/api/appcast/route.ts` of your web project. Your CI system can rewrite the `releases` array during publish (version, short version, signature from `generate_appcast`, ZIP length, etc.) and push the binary to a CDN. Sparkle will download the enclosure, verify the EdDSA signature, and prompt the user to update.

## OAuth Scopes Used

- `https://www.googleapis.com/auth/drive.file` – upload and manage files the app creates
- `https://www.googleapis.com/auth/userinfo.email` – display the signed-in account

## Notes & Next Steps

- Secrets are baked into `Secrets.plist` during packaging. If you need additional protection, consider deploying them from MDM or a secure endpoint at first launch instead.
- Drive uploads convert to Google-native formats (`application/vnd.google-apps.document|spreadsheet`). If you need to keep the binary copy, extend `DriveUploader` to toggle conversion or maintain two versions.
- Extended attributes stay with files on APFS/HFS+ but may be stripped by some syncing tools; consider adding a fallback shortcut export for those cases.
- Add an app icon (`Assets.car`) and embed it under `AppBundle/` for a polished build.
- Consider surfacing metadata management (e.g., “Clear Routing Info”) for power users.
