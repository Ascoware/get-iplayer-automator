# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Get iPlayer Automator is a macOS native app that provides a GUI around the `get_iplayer` Perl CLI tool for downloading BBC iPlayer and ITV content. It launches external processes (`get_iplayer`, `yt-dlp`, `ffmpeg`, `AtomicParsley`) and provides queue management, PVR/series-link recording, and automatic import into TV.app or Music.app.

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
make binaries     # Full build: Perl, dylibs, utils, yt-dlp (~30 min)
make gip          # Re-fetch get_iplayer only (fast)
make install-perl # Rebuild Perl + dylibs
make install-utils # Rebuild AtomicParsley + ffmpeg
make yt-dlp       # Download yt-dlp standalone binary
```

### Release
```sh
./bump_build.sh   # Increment build number
./release.sh      # xcodebuild archive → notarize → staple → zip
```

## Architecture

### Hybrid Objective-C / Swift
The project mixes Objective-C (AppController, legacy controllers) and Swift (models, download logic, metadata extraction). The bridging header is `Get iPlayer Automator/Get iPlayer Automator-Bridging-Header.h`.

### Core Data Flow
1. **Search / Listings** — `GiASearch.swift` queries BBC; `GetITVListings.swift` fetches ITV. Results populate `Programme` objects.
2. **Download Queue** — Managed by `AppController.m` (~89KB, the central coordinator). Downloads are enqueued and run sequentially or in parallel via `BBCDownload.swift` and `ITVDownload.swift`.
3. **Process Execution** — `Download.swift` is the base class. It launches `Foundation.Process` instances wrapping `get_iplayer` (BBC) or `yt-dlp` (ITV), then calls `AtomicParsley`/`ffmpeg` for metadata tagging and format conversion.
4. **UI Updates** — Async results propagate via `NotificationCenter`. Table views use KVC/NSArrayController bindings.
5. **Post-processing** — Completed downloads are tagged with metadata and added to TV.app (TV) or Music.app (radio).

### Key Source Files
| File | Role |
|------|------|
| `AppController.m` | Central coordinator: queue, PVR, cache, iTunes integration |
| `Programme.swift` | Model for a BBC or ITV programme (pid, type, status, paths) |
| `Download.swift` | Base class: process launch, stdout/stderr capture, AtomicParsley tagging |
| `BBCDownload.swift` | BBC-specific: assembles `get_iplayer` arguments, handles subtitles |
| `ITVDownload.swift` | ITV-specific: assembles `yt-dlp` arguments, parses ITV Hub metadata |
| `GetiPlayerArguments.swift` | Builds CLI argument arrays for `get_iplayer` |
| `GetITVListings.swift` | Fetches and caches ITV programme listings |
| `ITVMetadataExtractor.swift` | Parses ITV Hub HTML for show details |
| `GetCurrentWebpage.swift` | Reads frontmost Safari/Chrome tab URL for "Add from browser" |
| `GetiPlayerProxy.swift` | Proxy configuration passed to download processes |

### Programme Types
`Programme.swift` defines three types: `.tv` (BBC TV), `.radio` (BBC Radio), `.itv` (ITV/STV). Type determines which download class is used and which app receives the finished file.

### get_iplayer Integration
A custom patch (`get_iplayer_custom.patch`) modifies the upstream Perl script to:
- Use `|` as the field separator in output (instead of spaces) so the app can parse it reliably
- Add `itv` as a recognised programme type
- Confirm log file writes

### Dependencies (Swift Package Manager)
- **Sparkle** — auto-update (AppCast at `https://ascoware.github.io/get-iplayer-automator/appcast.xml`)
- **CocoaLumberjack / CocoaLumberjackSwift** — logging
- **Kanna** — HTML parsing (ITV/STV metadata)
- **SwiftyJSON** — JSON handling

## Tests

No automated test suite exists. CI (`.github/workflows/objective-c-xcode.yml`) runs `bump_build.sh` + `release.sh` on push/PR to master.
