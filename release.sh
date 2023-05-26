#!/bin/bash -x

PROJECT_NAME="Get iPlayer Automator"
PROJECT_DIR=$(pwd)
INFOPLIST_FILE="Info.plist"

rm -rf Archive/*
rm -rf Product/*

carthage bootstrap --platform macOS --configuration Release --no-use-binaries

xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -configuration Release -alltargets

xcodebuild archive -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" -archivePath "Archive/$PROJECT_NAME.xcarchive"

xcodebuild -exportArchive -archivePath "Archive/$PROJECT_NAME.xcarchive" -exportPath "Product/$PROJECT_NAME" -exportOptionsPlist ExportOptions.plist

cd "Product/${PROJECT_NAME}"
CFBundleVersion=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PROJECT_NAME.app/Contents/${INFOPLIST_FILE}")
CFBundleShortVersionString=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_NAME.app/Contents/${INFOPLIST_FILE}")

ARCHIVE_NAME="$PROJECT_NAME.v${CFBundleShortVersionString}.b${CFBundleVersion}.zip"
ditto -c -k --keepParent -rsrc "$PROJECT_NAME.app" "../$ARCHIVE_NAME"
cd ..
xcrun notarytool submit "$ARCHIVE_NAME" \
                 --keychain-profile "get-iplayer-automator-notary" \
                 --wait

ditto -x -k "$ARCHIVE_NAME" .

xcrun stapler staple "$PROJECT_NAME.app"

ditto "$PROJECT_NAME.app" tmp-"$PROJECT_NAME.app"
rm -rf "$PROJECT_NAME.app"
mv tmp-"$PROJECT_NAME.app" "$PROJECT_NAME.app"

ditto -c -k --keepParent -rsrc "$PROJECT_NAME.app" "$ARCHIVE_NAME"
