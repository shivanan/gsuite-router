#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-release}"
PRODUCT_NAME="GSuiteRouter"
BUILD_ROOT=".build/${CONFIGURATION}"
APP_BUNDLE="dist/${PRODUCT_NAME}.app"
BINARY_SOURCE="${BUILD_ROOT}/${PRODUCT_NAME}"
INFO_PLIST_SOURCE="AppBundle/Info.plist"

if [[ ! -f "${INFO_PLIST_SOURCE}" ]]; then
  echo "missing ${INFO_PLIST_SOURCE}" >&2
  exit 1
fi

echo "Building ${PRODUCT_NAME} (${CONFIGURATION})"
swift build -c "${CONFIGURATION}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY_SOURCE}" "${APP_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}"
cp "${INFO_PLIST_SOURCE}" "${APP_BUNDLE}/Contents/Info.plist"

# Optionally embed additional resources (icons, etc.) here.

plutil -replace CFBundleVersion -string "$(date +%Y%m%d%H%M%S)" "${APP_BUNDLE}/Contents/Info.plist" || true

cat <<PKGINFO > "${APP_BUNDLE}/Contents/PkgInfo"
APPLGSRT
PKGINFO

codesign --force --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "Created ${APP_BUNDLE}"
