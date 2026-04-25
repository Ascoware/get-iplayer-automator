# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Get iPlayer Automator is a macOS native app that provides a GUI around the `get_iplayer` Perl CLI tool for downloading BBC iPlayer and STV content. It launches external processes (`get_iplayer`, `yt-dlp`, `ffmpeg`, `AtomicParsley`) and provides queue management, PVR/series-link recording, and automatic import into TV.app or Music.app.

## Building

### App (Xcode)
Open `Get iPlayer Automator.xcodeproj` and build with Xcode, or:
```sh
xcodebuild -project "Get iPlayer Automator.xcodeproj" \
           -scheme "Get iPlayer Automator" \
           -configuration Debug build
```

Dependencies are managed via Swift Package Manager and resolved automatically by Xcode.

### Bundled Binaries (Makefile)
The `Binaries/` directory is not tracked in git — it is generated at release time. The Makefile delegates to the sibling repo `../get_iplayer_macos`.

```sh
make              # Full build: Perl, dylibs, utils, yt-dlp (~30 min)
make gip          # Re-fetch get_iplayer only (fast)
make install-perl # Rebuild Perl + dylibs
make install-utils # Rebuild AtomicParsley + ffmpeg
make yt-dlp       # Download yt-dlp standalone binary
```

### Release
```sh
./release.sh                   # bump build number → archive → notarize → staple → zip
./release.sh --minor           # also bump MARKETING_VERSION patch (z) component
./release.sh --major           # also bump middle (y) component, reset z to 0
./release.sh --publish         # create draft GitHub release + update appcast
```
Marketing version and build number live in `Version.xcconfig` (shared by the app and Safari extension via `baseConfigurationReference`).

## Architecture

### Hybrid Objective-C / Swift
The project mixes Objective-C (AppController, legacy controllers) and Swift (models, download logic, metadata extraction). The bridging header is `Get iPlayer Automator/Get iPlayer Automator-Bridging-Header.h`.

### Core Data Flow
1. **Search / Listings** — `GiASearch.swift` queries BBC. Results populate `Programme` objects.
2. **Download Queue** — Managed by `AppController.m` (~89KB, the central coordinator). Downloads are enqueued and run sequentially or in parallel via `BBCDownload.swift` and `STVDownload.swift`.
3. **Process Execution** — `Download.swift` is the base class. It launches `Foundation.Process` instances wrapping `get_iplayer` (BBC) or `yt-dlp` (STV), then calls `AtomicParsley`/`ffmpeg` for metadata tagging and format conversion.
4. **UI Updates** — Async results propagate via `NotificationCenter`. Table views use KVC/NSArrayController bindings.
5. **Post-processing** — Completed downloads are tagged with metadata and added to TV.app (TV) or Music.app (radio).

### Key Source Files
| File | Role |
|------|------|
| `AppController.m` | Central coordinator: queue, PVR, cache, iTunes integration |
| `Programme.swift` | Model for a BBC or STV programme (pid, type, status, paths) |
| `Download.swift` | Base class: process launch, stdout/stderr capture, AtomicParsley tagging |
| `BBCDownload.swift` | BBC-specific: assembles `get_iplayer` arguments, handles subtitles |
| `STVDownload.swift` | STV-specific: assembles `yt-dlp` arguments |
| `GetiPlayerArguments.swift` | Builds CLI argument arrays for `get_iplayer` |
| `GetCurrentWebpage.swift` | Reads frontmost Safari/Chrome tab URL for "Add from browser" |
| `GetiPlayerProxy.swift` | Proxy configuration passed to download processes |

### Programme Types
`Programme.swift` defines three types: `.tv` (BBC TV), `.radio` (BBC Radio), `.stv` (STV). Type determines which download class is used and which app receives the finished file.

### get_iplayer Integration
A custom patch (`get_iplayer_custom.patch`) modifies the upstream Perl script to:
- Use `|` as the field separator in output (instead of spaces) so the app can parse it reliably
- Confirm log file writes

### Dependencies (Swift Package Manager)
- **Sparkle** — auto-update (AppCast at `https://ascoware.github.io/get-iplayer-automator/appcast.xml`)
- **CocoaLumberjack / CocoaLumberjackSwift** — logging
- **Kanna** — HTML parsing (STV metadata)
- **SwiftyJSON** — JSON handling

## Tests

No automated test suite exists. There is no CI — releases are built locally via `./release.sh`.
