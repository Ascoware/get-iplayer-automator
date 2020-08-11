## What is it?
The goal of Get iPlayer Automator is to allow iTunes and your Mac to become the hub for your British Television experience regardless of where in the world you are. Get iPlayer Automator allows you to download and watch BBC and ITV shows on your Mac. Series-Link/PVR functionality ensures you will never miss your favourite shows. Programmes are fully tagged and added to iTunes automatically upon completion. It is simple and easy to use, and runs on any machine running Mac OS X 10.9 or later. And since the shows are in iTunes, it is extremely easy to transfer them to your iPod, iPhone, or Apple TV allowing you to enjoy your shows on the go or on your television.

The current release is 1.16.1. [Download it here.](https://github.com/Ascoware/get-iplayer-automator/releases)


### What if I find a bug?
[Start here.](https://github.com/Ascoware/get-iplayer-automator/wiki/Reporting-Issues)

#### Version history

##### 1.19.0
Fixed detection of radio/BBC Sounds programs when using 'Use Current Webpage' (#263)
Merged get_iplayer 3.26
Merged youtube-dl 2010.07.28

##### v1.18.2
Fixed crash due to ffmpeg and related binaries being moved to a new location
Actually update to get_iplayer 3.25

##### v1.18.1
Update to get_iplayer 3.25. This should address errors when downloading subtitles. (#272, #278)
Get iPlayer Automator now includes its own perl environment to ensure consistency across platforms.
(note: version 1.18 was never released.)

##### v1.17
 Updated get_iplayer to 3.23 to address 403 errors for HLS streams
Removed "Get lower quality HLS audio" as it's now ignored by get_iplayer
Removed unnecessary recoding of DASH streams (#256)
Set MOJO_INSECURE option that may fix 500 errors when downloading (#233, #254)

##### 1.16.1
Get iPlayer Automator is now ready for use on macOS Catalina (10.15)! TV programs will be added to TV.app, and radio programs will be added to Music.app. Due to a bug in macOS shows tagged as podcasts will open in Music.app but can't be played. Also, because it was ported from iOS, Podcasts.app is not scriptable and cannot accept externally created m4a files. As a result, if you use the "Tag radio programmes as podcasts" your only option right now is to use QuickTime Player.app, or turn off this checkbox and play them through Music.app. We hope this bug is fixed in a future version of macOS.

##### 1.16
Updated to get_iplayer 3.22. See the release notes for more information.
Most notably, BBC program metadata caching will work after the 19-August bbc.co.uk iPlayer web site changes.

##### 1.15.2
Proxy server support for ITV downloads

##### 1.15.1
Updated the channel names used for new program filtering to match what's in get_iplayer.
Fixed memory leak when caching ITV programs
If ITV caching fails for some reason (ITV down, bad network, etc.) app is no longer stuck. (#210)

##### 1.15.0
Updated to get_iplayer 3.20. See the release notes for more information.
If you have Safari selected as your browser for "Get Current Webpage", Safari Technology Preview.app will be checked as well, if it is running.

##### 1.14.3
Movies shown on ITV and other one-off programs weren't being cached, and therefore not downloadable. This is fixed. (#220)

##### 1.14.2
Fixed a regression that caused BBC subtitles to not be downloaded, due to a change in get_iplayer's subtitle command semantics. (#219)
Added support for embedding subtitles in ITV downloads, already supported in youtube-dl! (#216 )

##### 1.14.1
Preemptive fix for #218, by guarding against corrupted archives.

##### 1.14
Happy New Year! Thanks for your continued support in 2019.
Starting with this release, the minor version will now increment whenever get_iplayer is updated. The bug fix version will reflect Get iPlayer Automator-only changes.
Merged in get_iplayer 3.18, which necessitated some option changes. "Get higher-quality audio" is now the default, so if you want lower-bitrate audio the option is now "Get lower quality HLS audio". If you had the old option unchecked, it is now checked in this version for consistency. The new default value for this option is unchecked. For more information see https://github.com/get-iplayer/get_iplayer/wiki/release310to319#release318
Timeout for getting ITV listings is now 30 seconds. This feature still needs some tweaking, but the application won't hang anymore if ITV Hub is unavailable, or your network connection is having problems.

##### 1.13.19
Small fix to add support for using Get Current Webpage with BBC Sounds pages.

##### 1.13.18
Added option for embedding subtitles into BBC videos (#192, #213)
If subtitle downloading is selected, they are embedded into the converted MP4 by default. If you don't want that, and want a standalone subtitle file, uncheck the "Embed Subtitles in Download" option.
This option works only for BBC shows. ITV support will be added in a future release.
Made sure certificates were set for all invocations of get_iplayer. This will fix showing the extended metadata for a program.

##### 1.13.17
Updated the root certificates used by Mozilla::CA. This should address the 500 errors when starting a BBC download.
This will most likely NOT fix 403 errors if you are using a VPN outside of the UK as that is the BBC blocking your connection.

##### 1.13.16
BBC changed their page structure for radio and TV programs, so the Get Current Webpage scraping changed slightly to handle it.

##### 1.13.15
Updated Perl support libraries to match get_iplayer distribution
Fixed: Get Current Webpage will work with Chrome if the page source can't be accessed. (#201)
Minimum macOS version is now 10.10, to match get_iplayer.

##### 1.13.14
BBC Radio show pages have a new URL format. GiA now recognizes the new URL and will parse out the program ID. (#199)
Rewrote 'Get Current Webpage' functionality in Swift, and cleaned out code for non-existent BBC pages. Now,only the frontmost window and tab will be checked for an ITV or BBC program page. No more checking random open web pages. (#123)
Added necessary Info.plist entries so that Get Current Webpage and adding to iTunes works on macOS Mojave again.

##### 1.13.13
Updated to get_iplayer 3.17. No major functionality changes, but there are more clarifying messages about 403 errors while downloading.
Removed Growl. All of its functionality is available in macOS 10.9, so no need to have the extra library.
Made some cleanup changes that won't affect the behavior, but will get the app ready for macOS Mojave.
BBC is getting more aggressive about VPN blocking! Keep that in mind before filing new bugs.

##### 1.13.12
Picked up get_iplayer 3.16
Fixed search result parsing (#191)

##### 1.13.11
New version of get_iplayer (3.15)
Updated perl library dependencies
Updated ITV caching to match new format

##### 1.13.10
Includes newest version of youtube-dl to address #189

##### 1.13.9
Auto-record now shows the date of broadcast for found programs. (#174)
Behind-the-scenes cleanup.

##### 1.13.8
Removed 'Ignore DASH' flag for real

##### 1.13.7
Removed the 'Ignore DASH streams' option, as it's no longer necessary with get_iplayer fixes. The option is completely ignored now, so don't worry if you had it set.
Fixed fetching of metadata when using 'Get Current Webpage' for un-cached shows. (#182)

##### 1.13.6
Updated to latest youtube-dl (2018.06.04)
Fixed handling of DASH output which separates audio and video.

##### 1.13.5
Updated to get_iplayer 3.14. This has some implications for your downloads, as 50 FPS streams are now the default. I added a checkbox to force 25 FPS streams, which will result in a smaller download. This setting is off by default.
There are now only 4 levels of download: Best, Better, Good, Worst. I did not attempt to map the old values into the new ones, so check your settings to make sure they are what you want.

##### 1.13.4
Updated to latest youtube-dl to handle ITV errors (#168, #170)
Added option to tag audio downloads as podcasts. This means that when the audio is added to iTunes, it will now appear in the Podcasts section with the series thumbnail. (#153)

##### 1.13.3
"Force get_iplayer to download HLS" is now "Force get_iplayer to ignore DASH". This means HLS or HVF streams can be fetched. (#163, #165)
Let youtube-dl determine the extension of the download. If it is FLV, use ffmpeg to copy into an MP4 instead of letting youtube-dl re-encode the video. (#161, #164)
Updated PyCrypto to hopefully avoid crashes (#162)
Updated youtube-dl (4/8/18 release)
Verbose mode now dumps everything from youtube-dl.

##### 1.13.2
ITV downloads now try for the best MP4 available, and if that fails, they fall back to the best available, which is FLV. The resulting download is converted to MP4 if needed.
The upshot of this is that Lethal Weapon and other shows should now download even if the web page for the show on ITV Hub says 'not available on your platform.'

##### 1.13.1
Fixed startup of youtube-dl so it can find PyCrypto, and added important file identifying the package. (#151)
Fixed handling of ttml files when used as the subtitle format on ITV shows. Call ttml2srt when that happens. (#155)

##### 1.13
Better handling of ITV shows that don't use a 3-part program ID (#150)
Added PyCrypto so youtube-dl can do its own MP4 downloads. As a bonus, youtube-dl can now resume cancelled or interrupted ITV downloads! (#148)

##### 1.12.2
ITV downloads now always use XBMC naming to avoid conflicts for downloaded shows. (#143)
Better parsing of show metadata for season, episode, and episode title

##### 1.12.1
Fixed #142: Requesting subtitles for ITV shows that don't have them stalled the download queue.
Fixed #145: Fixed parsing of youtube-dl output so the duration is now available. Also added amount downloaded/duration to progress.
Fixed #144(?): Added necessary perl libraries for SSL connections when caching BBC shows.

##### 1.12.0
youtube-dl is now the engine for getting ITV shows, subtitles and thumbnails. (#132, #136)
Upgraded to get_iplayer 3.13 to address BBC TV and radio cache issues (#139)
Fixed NSAlerts trying to present on a non-main thread (#131)
Back to "ITV Player", though at some point it needs to be named just ITV. (#135)

##### 1.11.3
Fixed #138: ITV Cache was being corrupted due to bad inherited code.
Fixed #139: Cache searching works again for BBC and ITV.
NOTE: BBC Radio programs cannot be cached right now due to a change on BBC's part. This will require a change to get_iplayer.

##### 1.11.2
- Included an official 3.4.2 build of ffmpeg that works on OS X 10.9 and later (#133)
- Fixed up the proxy settings for ITV and metadata downloads when using GiA’s proxy setting (#134)
- Minor tweaks to ffmpeg arguments for compatibility with other tools.

##### 1.11.1
- WebVTT subtitles are now converted to SubRip via ffmpeg. (#130)
- Used a better combination of arguments for downloading ITV streams. (#129)

##### 1.11.0
- Caching of ITV listings now works again. You can also select programs from a search and add them to the queue. (#121, #122, #126)
- ITV downloads are now implemented by fetching the m3u8 playlist and handing it off to ffmpeg to stream and save the file. No more "Show not available" for ITV programs! (#95)
- ITV subtitle files are now in WebVTT format. They are just downloaded and left alone next to the video file.

##### 1.10.2
- Fixed #121 - ITV shows can now be downloaded if you select Get Current Webpage with an ITV Hub show's episode page frontmost in your browser.

##### 1.10.1
- Fix for #118. I'm not entirely sure what has changed on ITV's end, but I can at least guard against it.

##### 1.10.0
- Fix for #104: restoring the queue was failing and deleting the file
- Implemented #90: Put the last broadcast date in the search results and queue.

##### 1.9.15
- Fixed #110: "Use Current Webpage" should now work again for https-prefixed URLs

##### 1.9.14
- Updated get_iplayer to 3.12
- Added option to force HLS format downloads for BBC. This is off by default, but if you aren't happy with the speed of DASH download and conversion, give it a try.
- WARNING: This will likely be the last version of Get iPlayer Automator that supports macOS 10.7 or 10.8. I want to start moving parts of the application to Swift, and that requires macOS 10.9.

##### 1.9.13
- Fixed #88, #85: No need for a --version tag if not explicitly requested
- Fixed #84: Restored use of tvbest, tvbetter, etc.
- Note that if get_iplayer picks a DASH format stream (dvfhd, dvfvhigh, etc.) we have to convert it with ffmpeg's libx264 to produce a video that is playable in iTunes/Quicktime Player. Even though it uses the ultrafast preset, it will take some time, especially at HD resolution. Suggestions for speeding this up are welcome.
- Rewrote the log window code to use a monospace font and not re-scroll the window to the bottom when trying to read messages earlier in the log.

##### 1.9.12
- v1.9.11 was never released.
- #81, #80: Reverted ffmpeg to previous version (sorry about that!!). I will look into a better source for getting newer versions of ffmpeg.

##### 1.9.10
- Fixed #79 -- force all BBC downloads to use HLS mode.
- Fixed #74 -- not all ITV episodes have a transmission time.

##### 1.9.9
- Integrated the rest of get_iplayer 3.06. In non-verbose mode, get_iplayer now generates less information about a download in progress, but Get iPlayer Automator will present what it can from the progress string. Verbose mode will report the amount of data retrieved as it did before.
GiP 3.06 introduces the ability to get higher-quality (320k) audio for BBC shows. This is on by default, but can be disabled via a checkbox in the BBC section of the 'Download Formats' preferences.
- Fixed a long-standing issue where ITV shows didn't have a release date when added to iTunes.
- Removed the now-invalid message about attempting to open iTunes in 32-bit mode. You can get a message telling you that the show wasn't added, but usually this is because iTunes is doing something else when the download finishes, and can't respond to the AppleEvent. Workaround is to drag the file from the Finder to the iTunes library window.

##### 1.9.8
- Fix for BBC program caching from get_iplayer 3.06 (#70)
- Fix for bug in earlier version where proxy host information was being set up incorrectly. (#68)

##### 1.9.7
- Fixed bug in synchronization of multiple ITV downloads with subtitles.

##### 1.9.6
- Updated the about box to point to this web site for more information.

##### 1.9.5
- More ITV download fixes
- Undid the XBMC naming change
- Self-updating is back! From this version on, you will automatically be notified of updates when they are available.

##### 1.9.4
- More bug fixes

##### 1.9.3
- Addressed some issues related to the change in ITV downloads.

##### 1.9.2
- Incorporated get_iplayer 3.02
-- This means the option for using the show thumbnail instead of the series thumbnail can be removed, as this is now the default behavior.
- Fixed slow caching by including needed Perl libraries
- Rewrote downloading of ITV program metadata to use built-in macOS networking code
- Removed the 'provided' proxy option, as the tom-tech.com backend that it relied upon no longer exists.

##### 1.9b6:
- Turned on update checking. This is almost ready to go.
- Fixed a few more places where it didn't detect the end of the download.

##### 1.9b5:
- Fixed lowest quality recording names.
- Added option to retrieve 50 FPS shows, if available.
- Fixed detecting completed download when no tagging has happened.

##### 1.9b4:
- Changed some framework loading options for compatibility with Gatekeeper on 10.9.

##### 1.9b3:
- Changed UI and options to use "Best", "Better", "Very Good", and so on for BBC TV and radio downloads. These map to the corresponding options in get_iplayer, and allow get_iplayer to pick the best available show formats.
- The formerly alternative 'ITV quick caching' is now the default method for getting ITV listings.
- Recordings are now saved without underscores in the names. App now uses the --whitespace option from get_iplayer.
- Deployment target/minimum version restored to 10.7.

##### 1.9b2:
- Restored searching of ITV archives
- Fixed bug with generation of Application Support folder.

##### 1.9b1:
- Integrated get_iplayer 3.01
