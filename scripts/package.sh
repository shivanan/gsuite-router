#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-release}"
PRODUCT_NAME="GSuiteRouter"
BUILD_ROOT=".build/${CONFIGURATION}"
APP_BUNDLE="dist/${PRODUCT_NAME}.app"
BINARY_SOURCE="${BUILD_ROOT}/${PRODUCT_NAME}"
INFO_PLIST_SOURCE="AppBundle/Info.plist"
SECRETS_SOURCE="AppBundle/Secrets.plist"

if [[ ! -f "${INFO_PLIST_SOURCE}" ]]; then
  echo "missing ${INFO_PLIST_SOURCE}" >&2
  exit 1
fi

ensure_secrets_file() {
  if [[ -n "${GOOGLE_CLIENT_ID:-}" && -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
    cat > "${SECRETS_SOURCE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>GoogleClientID</key>
  <string>${GOOGLE_CLIENT_ID}</string>
  <key>GoogleClientSecret</key>
  <string>${GOOGLE_CLIENT_SECRET}</string>
EOF
    if [[ -n "${GOOGLE_DRIVE_FOLDER_ID:-}" ]]; then
      cat >> "${SECRETS_SOURCE}" <<EOF
  <key>GoogleDriveFolderID</key>
  <string>${GOOGLE_DRIVE_FOLDER_ID}</string>
EOF
    else
      cat >> "${SECRETS_SOURCE}" <<'EOF'
  <key>GoogleDriveFolderID</key>
  <string></string>
EOF
    fi
    cat >> "${SECRETS_SOURCE}" <<'EOF'
</dict>
</plist>
EOF
    echo "Generated ${SECRETS_SOURCE} from environment variables."
  fi

  if [[ ! -f "${SECRETS_SOURCE}" ]]; then
    echo "missing ${SECRETS_SOURCE}. Provide GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET env vars or copy AppBundle/Secrets.plist.template." >&2
    exit 1
  fi
}

ensure_secrets_file

echo "Building ${PRODUCT_NAME} (${CONFIGURATION})"
swift build -c "${CONFIGURATION}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY_SOURCE}" "${APP_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}"
cp "${INFO_PLIST_SOURCE}" "${APP_BUNDLE}/Contents/Info.plist"
cp "${SECRETS_SOURCE}" "${APP_BUNDLE}/Contents/Resources/Secrets.plist"
if [[ -f "AppBundle/GSuiteRouter.icns" ]]; then
  cp AppBundle/GSuiteRouter.icns "${APP_BUNDLE}/Contents/Resources/"
fi


# Optionally embed additional resources (icons, etc.) here.

plutil -replace CFBundleVersion -string "$(date +%Y%m%d%H%M%S)" "${APP_BUNDLE}/Contents/Info.plist" || true

cat <<PKGINFO > "${APP_BUNDLE}/Contents/PkgInfo"
APPLGSRT
PKGINFO

codesign --force --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "Created ${APP_BUNDLE}"
