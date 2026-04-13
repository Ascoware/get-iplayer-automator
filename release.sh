#!/bin/bash -x

PROJECT_NAME="Get iPlayer Automator"
PROJECT_DIR=$(pwd)
INFOPLIST_FILE="Info.plist"
PUBLISH=0

for arg in "$@"; do
    case "$arg" in
        --publish) PUBLISH=1 ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

rm -rf Archive/*
rm -rf Product/*

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

# ── Optional publish step ──────────────────────────────────────────────────

if [ "$PUBLISH" -eq 1 ]; then
    TAG="v${CFBundleShortVersionString}"
    REPO="Ascoware/get-iplayer-automator"

    echo ""
    echo "Publishing ${TAG} to ${REPO}"
    echo ""

    # Release title
    printf "Release title (short description of major change): "
    read -r RELEASE_TITLE

    # Release notes — read until Ctrl-D
    echo "Release notes (bullet points, Ctrl-D when done):"
    RELEASE_NOTES=$(cat)

    # Tag and push
    cd "$PROJECT_DIR"
    git tag "$TAG"
    git push origin "$TAG"

    # Create draft release and upload zip
    gh release create "$TAG" \
        --repo "$REPO" \
        --title "$TAG: $RELEASE_TITLE" \
        --notes "$RELEASE_NOTES" \
        --draft \
        "Product/$ARCHIVE_NAME"

    echo ""
    echo "Draft release created: https://github.com/${REPO}/releases"
    echo "Review and publish it at the URL above."
fi
