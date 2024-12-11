#!/bin/bash
set -e

DISPLAY_NAME="KinegramEmrtdConnectorObjC"
BUILD_SCHEME="KinegramEmrtdConnectorObjC"
BUILD_OUTPUT="Distribution"
WORKSPACE_PATH="sdk_builder/KinegramEmrtdConnectorObjC.xcworkspace"
SIGN_ID="Apple Distribution: OVD Kinegram AG (EFFLVPGMFM)"

echo ""
echo "build_sdk.sh"
echo "PWD ${PWD}"
echo "SDK Display Name ${DISPLAY_NAME}"
echo "Build Scheme ${BUILD_SCHEME}"
echo "Workspace path ${WORKSPACE_PATH}"
echo "Build output path ${BUILD_OUTPUT}"
echo ""

mkdir -p ${BUILD_OUTPUT}
ARCHIVE_PATH_IOS="${BUILD_OUTPUT}/ios.xcarchive"
ARCHIVE_PATH_SIMULATOR="${BUILD_OUTPUT}/ios_simulator.xcarchive"
TARGET_FRAMEWORK_PATH="${BUILD_OUTPUT}/${DISPLAY_NAME}.xcframework"

# Delete old versions before
rm -rf $TARGET_FRAMEWORK_PATH $ARCHIVE_PATH_IOS $ARCHIVE_PATH_SIMULATOR

# Build ios.xcarchive
echo "Build ios.xcarchive"
xcodebuild archive \
  -scheme $BUILD_SCHEME \
  -workspace $WORKSPACE_PATH \
  -archivePath $ARCHIVE_PATH_IOS \
  -scmProvider xcode \
  -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Build ios_simulator.xcarchive
echo "Build ios_simulator.xcarchive"
xcodebuild archive \
  -scheme $BUILD_SCHEME \
  -workspace $WORKSPACE_PATH \
  -archivePath $ARCHIVE_PATH_SIMULATOR \
  -scmProvider xcode \
  -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Build .xcframework
echo "Build .xcframework"
xcodebuild -create-xcframework \
  -framework $ARCHIVE_PATH_IOS/Products/Library/Frameworks/${DISPLAY_NAME}.framework \
  -framework $ARCHIVE_PATH_SIMULATOR/Products/Library/Frameworks/${DISPLAY_NAME}.framework \
  -output $TARGET_FRAMEWORK_PATH
  
echo "Signing the framework..."
# Remove old signature (if existing).
rm -rf "$TARGET_FRAMEWORK_PATH/_CodeSignature"
codesign --timestamp -s "$SIGN_ID" "$TARGET_FRAMEWORK_PATH"

# delete archives after framework creation
rm -rf $ARCHIVE_PATH_IOS $ARCHIVE_PATH_SIMULATOR
