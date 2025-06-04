#!/bin/bash

# Set up variables
APP_NAME="iSponsorBlockTV"
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVES_DIR="${BUILD_DIR}/archives"
IPA_DIR="${BUILD_DIR}/ipa"
ARCHIVE_PATH="${ARCHIVES_DIR}/${APP_NAME}.xcarchive"
IPA_PATH="${IPA_DIR}/${APP_NAME}.ipa"

# Clean previous builds
rm -rf "${BUILD_DIR}"
mkdir -p "${ARCHIVES_DIR}"
mkdir -p "${IPA_DIR}"

# Build archive
echo "Building archive..."
xcodebuild clean archive \
  -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  ENTITLEMENTS_REQUIRED=YES \
  EXPANDED_CODE_SIGN_IDENTITY="" \
  STRIP_SWIFT_SYMBOLS=NO \
  COPY_PHASE_STRIP=NO \
  SWIFT_OPTIMIZATION_LEVEL="-O" \
  2>&1

if [ $? -ne 0 ]; then
  echo "Archive failed"
  exit 1
fi

echo "Archive successful"

# Create IPA directory structure
mkdir -p "${IPA_DIR}/Payload"

# Copy .app from archive to Payload directory
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${IPA_DIR}/Payload/"

# Create IPA
cd "${IPA_DIR}"
zip -r "${IPA_PATH}" Payload

echo "IPA created at: ${IPA_PATH}"