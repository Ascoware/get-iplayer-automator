## What is it?
The goal of Get iPlayer Automator is to allow iTunes and your Mac to become the hub for your British Television experience regardless of where in the world you are. Get iPlayer Automator allows you to download and watch BBC and ITV shows on your Mac. Series-Link/PVR functionality ensures you will never miss your favourite shows. Programmes are fully tagged and added to iTunes automatically upon completion. It is simple and easy to use, and runs on any machine running Mac OS X 10.9 or later. And since the shows are in iTunes, it is extremely easy to transfer them to your iPod, iPhone, or Apple TV allowing you to enjoy your shows on the go or on your television.

The current release is 1.11.1. [Download it here.](https://github.com/Ascoware/get-iplayer-automator/releases)


### What if I find a bug?
[Start here.](https://github.com/Ascoware/get-iplayer-automator/wiki/Reporting-Issues)

#### Version history

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
