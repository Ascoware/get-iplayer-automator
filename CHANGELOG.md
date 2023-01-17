# Changelog

## Updated certificates, new log, and STV  (15/01/2023)
- Fixed bug where empty rows in the download queue stopped all downloading
- Updated root certificates, which may or may not reduce connection errors when fetching program listings
- Introduced new logging code. The log window will now highlight warnings and errors in color.
- Individual, non-DRM programs can now be downloaded from stv.tv using 'Use Current Webpage'. 

---

## Disabled ITV download and caching (18/11/2022)
- itv: Due to ITV changing itv.com to itvx.com I'm turning off the ability to cache ITV show listings or use 'get current website' on ITV Hub program pages. Watch the discussion pages on GitHub to find out when it will be restored.
---

## Bulk queuing of programs (02/11/2022)
- Add support for getting all programs from a web page. The main way to use this feature is to open your web browser to a page like https://www.bbc.co.uk/programmes/m0015fn5/episodes/player, which has all episodes for a show -- in this case,  Bridge of Lies. Then, click 'Use Current Webpage'. Get iPlayer Automator will retrieve all of the program IDs and add them to the download queue. It will then attempt to fill in the metadata for the entries.
- Note: due to a limitation in get_iplayer it will not filter out shows already in the download history. But this just means that if you have downloaded any of the shows already, those downloads will fail and it will move on to the next in the queue.
---

## Restored ITV program tagging code (10/10/2022)
**Note:** This is the last release that will support macOS 10.x. 11.0 will be the new minimum version

- itv: Put back Atomic Parsley tagging. yt-dlp's isn't as good
- itv: Use correct date formatter for display time
- general: safely remove finished shows from queues
- general: remove column sorting in download queue so you can control the queue yourself
- general: better pixel alignment in main window

I maintain this project entirely in my spare time because I use it every day and want it to be as useful as possible. I don't ask for payment but if you'd like to buy me a hot chocolate (not a coffee fan, thanks) you can do so [here.](https://ko-fi.com/scottkovatch)
---

## Fix ITV regression (27/06/2022)
- Fix a bug introduced in 1.24.0 in tagging ITV shows
---

## Update to get_iplayer 3.30 (22/06/2022)
- Updated to get_iplayer 3.30, which fixes problems downloading full HD TV
- Column widths and order should now be saved when you quit the app and restored when you restart it.
- When launching TV.app or Music.app to add shows, the first program added would be lost from the library when you quit the app. To work around this, GiA will now launch TV or Music, wait 2 seconds, and then add the show.
- Brave is now a supported browser. Thanks to Brett Hazen for the contribution!
- yt-dlp now handles metadata tagging and downloading of thumbnails for ITV shows
---

## New ITV engine (29/03/2022)
- ITV: yt-dlp is now used as the engine for ITV downloads. A Python 3 runtime is now embedded into the app, so there's no need to install Python or rely on Apple's pre-installed Python.
- ITV: Listings are now fetched on a separate thread so no more spinning beachball on cache refresh.
- ITV: fixed a bug in getting a thumbnail for a show
  
---

## Hotfix for BBC formats (16/02/2022)
- bbc: Fixed a sloppy error on my part with the naming of BBC download quality. (#385, #386) Thanks to sleaux-meaux for the fix.
---

## Update to get_iplayer 3.29 (15/02/2022)
**Important**: This release of Get iPlayer Automator incorporates v3.29 of get_iplayer. Due to changes in get_iplayer's options, your settings for BBC downloads will likely change. The BBC now supports up to 1080p video on most newer shows, compared to a maximum of 720p in previous versions. With this release you can now download those higher-resolution videos, but you will need to opt-in by updating your BBC download format settings. 1080p increases the size of a video by about 50%. For example, a 30 minute episode of 720p video is 1GB, but that same program is now about 1.5 GB at 1080p. This is a pretty significant increase in file size, so to avoid surprises the "Best" setting is now mapped to "720p".

- Also fixed an issue with ITV caching where program pages were not being parsed properly, which caused shows to be attached to the wrong series.
---

## React to more ITV Hub changes (07/02/2022)
- itv: Fix parsing episodes from show pages on ITV Hub. Those pages also changed slightly, and the assumption that episode and series URLs had the same base is no longer valid.

---

## v1.21.14 (07/02/2022)
- itv: Fix parsing of itv.com/hub/shows, which broke with an ITV Hub revamp (#377)
---

## Fix ITV user agent string (24/01/2022)
- itv: Use a fixed User-Agent string for ITV downloads (#371)
- subtitles: Always delete the raw subtitle files.
- general: Add support for Brave (another Chrome variant)

---

## Signing certificate update (29/07/2021)
- Releases of Get iPlayer Automator are now signed with a certificate from my personal Apple developer account. This should fix the alert of 'Apple cannot verify this application' when opening the application.
---

## Fix ITV regressions (06/05/2021)
- Reverted out the previous changes to the crypto support and path so everything continues to run on a system-provided python.
---

## Fix for latest ITV changes (05/05/2021)
- ITV: Use patched version of youtube-dl built by @sleaux-meaux to work around new ITV protections (#336, #333, #331)`
- ITV: Replace PyCrypto with PyCryptodome
- general: Catch empty PIDs before attempting to get metadata (#338)
- ITV: Add /usr/local//bin to the search path. This will find user-installed python versions.
- ITV: If show isn't cached don't start an info request with get_iplayer

---

## Bug fixes (23/04/2021)
- ITV: Put "series: season #" in the cache so auto-record can find it later. (#328)
- BBC: Use JSON parser to find the content type and other basic metadata
- ITV: capture show PID in the metadata extractor, not getCurrentWebpage
- ITV: Fill in ITV as the TV network.
- ITV: Remove duplicate fields for airing date and date string
- ITV: Don't append "Season 0"
- general: Support Vivaldi and other WebKit browsers more efficiently

v1.21.8 was not released due to minor health issues on my part.
---

## More bug fixing (31/03/2021)
- general: Fix condition that bails on updating cache if nothing is to be cached
- ITV: Restored old naming of downloaded files by using showName correctly

---

## Fix object unarchiving (23/03/2021)
- general: Fix reading of history, PVR and download queue to handle old object format (#311)
- general: Fix Log window menu item
---

## Bug fixes, and more handling of old prefs (23/03/2021)
- ITV: Don't overwrite a episode number parsed from metadata (#314)
- ITV: Correctly identify download failing due to 403 error
- BBC: Support parsing of program pages from a series page (#315)
- general: Don't delete data files if there is an error parsing (#311)

---

## Last minute bug fix  (16/03/2021)
Sorry for the quick series of updates, but there was a crash in 'Get Current Webpage' discovered right after I released the previous update.

- BBC: Fix parsing of show, series, and episode info in extended metadata
- ITV: Fix cache size doubling when updating multiple times in one launch
- general: Fix regression in Get Current Webpage; crashing when front page isn't a BBC or ITV show.
- BBC: fixed parsing of output for '--info' so it gets the display name, and series and episode names separately.
- BBC: fixed likely bug in processing download output.

---

## Improved ITV metadata parsing and memory usage (16/03/2021)
- ITV: Fix season number parsing on program pages
- ITV: Handle case of multiple seasons on a single program page
- ITV: Show info caching is much much faster
- ITV: Add "Season #" to the series name, like get_iplayer does for BBC
- general: Lots of dead code removal and memory cleanup

---

## Fix regression in queue editing (01/03/2021)
- Program ID, Series, and Episode fields are again editable in the download queue. (#307)
---

## Better ITV tagging, newer ffmpeg (28/02/2021)
- Replaced get_iplayer's ffmpeg with a new copy that supports streaming (#305). Note that due to a bug in youtube-dl on Apple Silicon you won't see progress for ITV downloads.
- Fixed tagging of ITV files so the episode name appears instead of 'series name - date'.
- Separated Series and Episode columns in main window. This also led to some dead code removal.
---

## get_iplayer 3.27, code cleanup, fix memory leaks (27/02/2021)
- Update get_iplayer to v3.27 (hopefully fixes #305)
- Fix memory leak that could cause multiple ITV downloads to fail. (#301, #304)
- Rewrote output parsing to make code more readable
- Episode name and number now parsed and tagged correctly for ITV programs.
---

## Removed cache reload on auto-restart (06/02/2021)
(#303) Fixed logic around auto-restart so that the cache only reloads when specifying a start time, not when auto-restarting after failure - this time for sure!
---

## ITV metadata update, auto-retry fix (03/01/2021)
- (#300) Metadata for ITV movies changed, so cache generation had to update to match.
- (#303) I _think_ I fixed the bug where the caches would start updating spontaneously when stopping downloads. Please let me know in the bug if you are still seeing it.
---

## youtube-dl 2020.12.12 and ITV improvements (31/12/2020)
- Updated embedded version of youtube-dl to 2020.12.12, which improves ITV downloads (#297, #298, #299) 
- Improved error handling for ITV shows. This should fix the problem of downloads stalling out.

---

## Apple Silicon support, resizable main window (06/12/2020)
- (#296) Rebuilt main application to include an Apple Silicon binary. This does not affect Intel hardware in any way.
-- Note that binaries included with get_iplayer are still Intel-only.
- (#293) Made main screen resizable, which means it also supports full-screen mode.

---

## Fix ITV download tagging (18/10/2020)
#292 - ITV changed the metadata JSON on show pages, which caused GiA to stop finding the thumbnail and description.


---

## Support Microsoft Edge (06/09/2020)
- GiA now supports Microsoft Edge as a browser for "Use Current Webpage".