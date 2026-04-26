#!/bin/bash -x

PROJECT_NAME="Get iPlayer Automator"
PROJECT_DIR=$(pwd)
INFOPLIST_FILE="Info.plist"
PUBLISH=0
BUMP=""

# Sparkle sign_update tool (from SPM artifacts)
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" \
    -path "*/artifacts/sparkle/Sparkle/bin/*" 2>/dev/null | head -1)
if [ -z "$SIGN_UPDATE" ]; then
    echo "ERROR: Sparkle sign_update tool not found. Build the project in Xcode first."
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --publish) PUBLISH=1 ;;
        --minor|--major)
            if [ -n "$BUMP" ]; then
                echo "ERROR: --minor and --major are mutually exclusive"
                exit 1
            fi
            BUMP="${arg#--}" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Version bump ──────────────────────────────────────────────────────────
# x.y.z scheme. --minor bumps z; --major bumps y and resets z to 0.
NEW_VERSION=""
if [ -n "$BUMP" ]; then
    CURRENT=$(awk -F' = ' '$1=="MARKETING_VERSION" {print $2}' Version.xcconfig)
    if ! [[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: MARKETING_VERSION '$CURRENT' is not in x.y.z form"
        exit 1
    fi
    IFS=. read -r X Y Z <<< "$CURRENT"
    case "$BUMP" in
        minor) Z=$((Z + 1)) ;;
        major) Y=$((Y + 1)); Z=0 ;;
    esac
    NEW_VERSION="${X}.${Y}.${Z}"
    sed -i '' -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = ${NEW_VERSION}/" Version.xcconfig
    echo "Bumped MARKETING_VERSION: ${CURRENT} → ${NEW_VERSION}"
fi

# Bump CFBundleVersion (CURRENT_PROJECT_VERSION) to a fresh build timestamp.
BUILD_STRING=$(date +'%Y%m%d%H%M')
sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${BUILD_STRING}/" Version.xcconfig

# ── Populate Binaries/ ────────────────────────────────────────────────────

make binaries

# ── Build ─────────────────────────────────────────────────────────────────

rm -rf Archive/*
rm -rf Product/*

xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -configuration Release -alltargets

xcodebuild archive -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" -archivePath "Archive/$PROJECT_NAME.xcarchive"

xcodebuild -exportArchive -allowProvisioningUpdates -archivePath "Archive/$PROJECT_NAME.xcarchive" -exportPath "Product/$PROJECT_NAME" -exportOptionsPlist ExportOptions.plist

if [ ! -d "Product/${PROJECT_NAME}/${PROJECT_NAME}.app" ]; then
    echo "ERROR: export failed; aborting"
    exit 1
fi

# Commit the bumped version on the same SHA the release tag will point at.
if [ -n "$NEW_VERSION" ]; then
    git add Version.xcconfig
    git commit -m "Bump version to ${NEW_VERSION}"
fi

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

# ── Sign the zip for Sparkle ───────────────────────────────────────────────

SIGN_OUTPUT=$("$SIGN_UPDATE" "$ARCHIVE_NAME")
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
ZIP_LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
echo "Sparkle signature: $ED_SIGNATURE  length: $ZIP_LENGTH"

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
    # GitHub replaces spaces with dots in asset filenames
    DOTTED_ARCHIVE="${ARCHIVE_NAME// /.}"
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${DOTTED_ARCHIVE}"

    gh release create "$TAG" \
        --repo "$REPO" \
        --title "$TAG: $RELEASE_TITLE" \
        --notes "$RELEASE_NOTES" \
        --draft \
        "Product/$ARCHIVE_NAME"

    # ── Update appcast on gh-pages ─────────────────────────────────────────
    git stash
    PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

    # Convert release notes to HTML for Sparkle's update alert. Lines starting
    # with "- " or "* " become <li>; blank-line-separated runs of plain text
    # become <p>. CDATA wraps the result so XML-special characters survive.
    NOTES_HTML=$(printf '%s\n' "$RELEASE_NOTES" | python3 -c '
import sys, html, re
lines = [l.rstrip() for l in sys.stdin]
out, buf, in_list = [], [], False
def flush_para():
    if buf:
        out.append("<p>" + " ".join(html.escape(b) for b in buf) + "</p>")
        buf.clear()
def close_list():
    global in_list
    if in_list:
        out.append("</ul>")
        in_list = False
for line in lines:
    m = re.match(r"^\s*[-*]\s+(.*)", line)
    if m:
        flush_para()
        if not in_list:
            out.append("<ul>")
            in_list = True
        out.append("<li>" + html.escape(m.group(1)) + "</li>")
    elif line.strip() == "":
        flush_para()
        close_list()
    else:
        close_list()
        buf.append(line)
flush_para()
close_list()
print("".join(out))
')

    NEW_ITEM="        <item>
            <title>${TAG}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <description><![CDATA[${NOTES_HTML}]]></description>
            <sparkle:minimumSystemVersion>10.14.0</sparkle:minimumSystemVersion>
            <enclosure
                url=\"${DOWNLOAD_URL}\"
                sparkle:version=\"${CFBundleVersion}\"
                sparkle:shortVersionString=\"${CFBundleShortVersionString}\"
                sparkle:edSignature=\"${ED_SIGNATURE}\"
                length=\"${ZIP_LENGTH}\"
                type=\"application/octet-stream\" />
        </item>"

    git checkout gh-pages
    for APPCAST in appcast.xml appcast_pre.xml; do
        # Insert new item after <channel> opening tags (before first <item>)
        python3 - "$APPCAST" "$NEW_ITEM" <<'PYEOF'
import sys, re
path, item = sys.argv[1], sys.argv[2]
content = open(path).read()
# Insert before the first <item>
updated = content.replace('<item>', item + '\n        <item>', 1)
open(path, 'w').write(updated)
PYEOF
    done

    git add appcast.xml appcast_pre.xml
    git commit -m "release: ${TAG}"
    git push origin gh-pages
    git checkout master
    git stash pop

    echo ""
    echo "Draft release created: https://github.com/${REPO}/releases"
    echo "Appcast updated on gh-pages."
    echo "Review and publish the draft release at the URL above."
fi
