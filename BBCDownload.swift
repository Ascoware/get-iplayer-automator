//  Converted to Swift 5.7 by Swiftify v5.7.28606 - https://swiftify.com/
//
//  BBCDownload.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 11/9/22.
//

import Foundation
import CocoaLumberjackSwift

@objc class BBCDownload: Download {
    var reasonForFailure: String?


    // MARK: Overridden Methods
    required init(programme: Programme, tvFormatList: [TVFormat], radioFormatList: [RadioFormat], proxy: HTTPProxy?) {
        super.init()
        reasonForFailure = nil
        self.proxy = proxy
        show = programme
        defaultsPrefix = "BBC_"
        downloadPath = UserDefaults.standard.string(forKey: "DownloadPath") ?? ""
        DDLogInfo("Downloading \(show.showName)")

        //Initialize Formats
        var formatArg = "--quality="
        var formatStrings: [String] = []

        if show.radio {
            formatStrings = radioFormatList.compactMap { radioFormats[$0.format] as? String }
        } else {
            formatStrings = tvFormatList.compactMap { tvFormats[$0.format] as? String }
        }

        let commaSeparatedFormats = formatStrings.joined(separator: ",")

        formatArg += commaSeparatedFormats

        //Set Proxy Arguments
        var proxyArg: String? = nil
        var partialProxyArg: String? = nil
        if let proxy {
            proxyArg = "-p\(proxy.url)"
            if UserDefaults.standard.bool(forKey: "AlwaysUseProxy") {
                partialProxyArg = "--partial-proxy"
            }
        }
        //Initialize the rest of the arguments
        let noWarningArg = GetiPlayerArguments.sharedController().noWarningArg
        let noPurgeArg = "--nopurge"
        let atomicParsleyPath = URL(fileURLWithPath: AppController.shared().extraBinariesPath).appendingPathComponent("AtomicParsley").path
        let atomicParsleyArg = "--atomicparsley=\(atomicParsleyPath)"
        let ffmpegArg = "--ffmpeg=\(URL(fileURLWithPath: AppController.shared().extraBinariesPath).appendingPathComponent("ffmpeg").path)"
        let downloadPathArg = "--output=\(downloadPath)"
        let subDirArg = "--subdir"
        let progressArg = "--logprogress"

        let getArg = "--pid"
        let searchArg = show.pid
        let whitespaceArg = "--whitespace"

        //AudioDescribed & Signed
        var needVersions = false

        var nonDefaultVersions: [String] = []

        if UserDefaults.standard.bool(forKey: "AudioDescribedNew") {
            nonDefaultVersions.append("audiodescribed")
            needVersions = true
        }
        if UserDefaults.standard.bool(forKey: "SignedNew") {
            nonDefaultVersions.append("signed")
            needVersions = true
        }

        //We don't want this to refresh now!
        let cacheExpiryArg = GetiPlayerArguments.sharedController().cacheExpiryArg
        let profileDirArg = GetiPlayerArguments.sharedController().profileDirArg

        //Add Arguments that can't be NULL
        var args = [AppController.shared().getiPlayerPath, profileDirArg, noWarningArg, noPurgeArg, atomicParsleyArg, cacheExpiryArg, downloadPathArg, subDirArg, progressArg, formatArg, getArg, searchArg, whitespaceArg, "--attempts=5", "--thumbsize=640", ffmpegArg, "--log-progress"]

        if let proxyArg {
            args.append(proxyArg)
        }

        if let partialProxyArg {
            args.append(partialProxyArg)
        }

        // Only add a --versions parameter for audio described or signed. Otherwise, let get_iplayer figure it out.
        if needVersions {
            nonDefaultVersions.append("default")
            var versionArg = "--versions="
            versionArg += nonDefaultVersions.joined(separator: ",")
            args.append(versionArg)
        }

        //Verbose?
        if UserDefaults.standard.bool(forKey: "Verbose") {
            args.append("--verbose")
        }

        if UserDefaults.standard.bool(forKey: "DownloadSubtitles") {
            args.append("--subtitles")
            if UserDefaults.standard.bool(forKey: "EmbedSubtitles") {
                args.append("--subs-embed")
            }
        }

        //Naming Convention
        if !UserDefaults.standard.bool(forKey: "XBMC_naming") {
            args.append("--file-prefix=<name> - <episode> ((<modeshort>))")
        } else {
            args.append("--file-prefix=<nameshort><.senum><.episodeshort>")
            args.append("--subdir-format=<nameshort>")
        }

        // 50 FPS frames?
        if UserDefaults.standard.bool(forKey: "Use25FPSStreams") {
            args.append("--tv-lower-bitrate")
        }

        //Tagging
        if !UserDefaults.standard.bool(forKey: "TagShows") {
            args.append("--no-tag")
        }

        for arg in args {
            DDLogVerbose("\(arg)")
        }

        if UserDefaults.standard.bool(forKey: "TagRadioAsPodcast") {
            args.append("--tag-podcast-radio")
            show.podcast = true
        }

        task = Process()
        pipe = Pipe()
        errorPipe = Pipe()

        task?.arguments = args
        task?.launchPath = AppController.shared().perlBinaryPath
        task?.standardOutput = pipe
        task?.standardError = errorPipe

        var envVariableDictionary = [String: String]()
        envVariableDictionary["HOME"] = (("~") as NSString).expandingTildeInPath
        envVariableDictionary["PERL_UNICODE"] = "AS"
        envVariableDictionary["PATH"] = AppController.shared().perlEnvironmentPath
        task?.environment = envVariableDictionary


        let fh = pipe?.fileHandleForReading
        let errorFh = errorPipe?.fileHandleForReading

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadDataNotification(_:)),
            name: FileHandle.readCompletionNotification,
            object: fh)
        fh?.readInBackgroundAndNotify()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadDataNotification(_:)),
            name: FileHandle.readCompletionNotification,
            object: errorFh)
        errorFh?.readInBackgroundAndNotify()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadFinished(_:)),
            name: Process.didTerminateNotification,
            object: task)

        task?.launch()

        //Prepare UI
        setCurrentProgress("Starting download...")
        show.status = "Starting.."
    }

    override var description: String {
        return "BBC Download (ID=\(show.pid))"
    }

    // MARK: Task Control

    @objc func downloadDataNotification(_ n: Notification?) {
        if let data = n?.userInfo?[NSFileHandleNotificationDataItem] as? Data,
           let s = String(data: data, encoding: .utf8) {
            processGetiPlayerOutput(s)
        }

        let fh = n?.object as? FileHandle
        fh?.readInBackgroundAndNotify()
    }

    @objc func downloadFinished(_ notification: Notification?) {
        if runDownloads.boolValue {
            complete()
        }

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.post(name: NSNotification.Name("DownloadFinished"), object: show)

        task = nil
        pipe = nil
        errorPipe = nil
    }

    func complete() {

        // If we have a path it was successful. Note that and return.
        if !show.path.isEmpty {
            show.complete = true
            show.successful = true
            show.status = "Download Complete"
            return
        }

        // Handle all other error cases.
        show.complete = true
        show.successful = false

        if let reasonForFailure {
            show.reasonForFailure = reasonForFailure
        }

        if reasonForFailure == "FileExists" {
            show.status = "Failed: File already exists"
            DDLogError("\(show.showName) failed, already exists")
        } else if reasonForFailure == "ShowNotFound" {
            show.status = "Failed: PID not found"
        } else if reasonForFailure == "proxy" {
            let proxyOption = UserDefaults.standard.string(forKey: "Proxy")
            if proxyOption == "None" {
                show.status = "Failed: See Log"
                DDLogError("REASON FOR FAILURE: VPN or System Proxy failed. If you are using a VPN or a proxy configured in System Preferences, contact the VPN or proxy provider for assistance.")
                show.reasonForFailure = "ShowNotFound"
            } else if proxyOption == "Provided" {
                show.status = "Failed: Bad Proxy"
                DDLogError("REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences.")
                show.reasonForFailure = "Provided_Proxy"
            } else if proxyOption == "Custom" {
                show.status = "Failed: Bad Proxy"
                DDLogError("REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences.")
                DDLogError("If outside the UK, please use a different proxy.")
                show.reasonForFailure = "Custom_Proxy"
            }

            DDLogError("\(show.showName) failed")
        } else if reasonForFailure == "Specified_Modes" {
            show.status = "Failed: No Specified Modes"
            DDLogError("REASON FOR FAILURE: None of the modes in your download format list are available for this show.")
            DDLogError("Try adding more modes.")
            DDLogError("\(show.showName) failed")
        } else if reasonForFailure == "InHistory" {
            show.status = "Failed: In download history"
            DDLogError("InHistory")
        } else if reasonForFailure == "AudioDescribedOnly" {
            show.reasonForFailure = "AudioDescribedOnly"
        } else if reasonForFailure == "External_Disconnected" {
            show.status = "Failed: HDD not Accessible"
            DDLogError("REASON FOR FAILURE: The specified download directory could not be written to.")
            DDLogError("Most likely this is because your external hard drive is disconnected but it could also be a permission issue")
            DDLogError("\(show.showName) failed")
        } else if reasonForFailure == "Download_Directory_Permissions" {
            show.status = "Failed: Download Directory Unwriteable"
            DDLogError("REASON FOR FAILURE: The specified download directory could not be written to.")
            DDLogError("Please check the permissions on your download directory.")
            DDLogError("\(show.showName) failed")
        } else {
            // Failed for an unknown reason.
            show.status = "Download Failed"
            DDLogError("\(show.showName) failed")
        }
    }

    func processGetiPlayerOutput(_ outp: String?) {
        let array = outp?.components(separatedBy: .newlines)

        //Parse each line individually.
        for output in array ?? [] {
            if output.count == 0 {
                continue
            }

            if output.hasPrefix("DEBUG:") {
                DDLogDebug("\(output)")
            } else if output.hasPrefix("WARNING:") {
                DDLogWarn("\(output)")
            } else {
                DDLogInfo("\(output)")
            }

            if output.hasPrefix("INFO: Downloading subtitles") {
                let scanner = Scanner(string: output)
                var srtPath: String?
                scanner.scanString("INFO: Downloading Subtitles to \'", into: nil)
                srtPath = scanner.scanUpToString(".srt\'")
                srtPath = URL(fileURLWithPath: srtPath ?? "").appendingPathExtension("srt").path
                show.subtitlePath = srtPath ?? ""
            } else if output.hasPrefix("INFO: Wrote file ") {
                let scanner = Scanner(string: output)
                scanner.scanString("INFO: Wrote file ", into: nil)
                let path = scanner.scanUpToCharactersFromSet(set: .newlines)
                show.path = path ?? ""
            } else if output.hasPrefix("INFO: No specified modes") && output.hasSuffix("--quality=)") {
                reasonForFailure = "Specified_Modes"
                let modeScanner = Scanner(string: output)
                modeScanner.scanUpTo("--quality=", into: nil)
                modeScanner.scanString("--quality=", into: nil)
                let availableModes = modeScanner.scanUpToString(")")
                show.availableModes = availableModes ?? ""
            } else if output.hasSuffix("use --force to override") {
                reasonForFailure = "InHistory"
            } else if output.contains("Permission denied") {
                if output.contains("/Volumes") {
                    //Most likely disconnected external HDD {
                    reasonForFailure = "External_Disconnected"
                } else {
                    reasonForFailure = "Download_Directory_Permissions"
                }
            } else if output.hasPrefix("WARNING: Use --overwrite") {
                reasonForFailure = "FileExists"
            } else if output.hasPrefix("ERROR: Failed to get version pid") {
                reasonForFailure = "ShowNotFound"
            } else if output.hasPrefix("WARNING: If you use a VPN") || output.hasSuffix("blocked by the BBC") {
                reasonForFailure = "proxy"
            } else if output.hasPrefix("WARNING: No programmes are available for this pid with version(s):") || output.hasPrefix("INFO: No versions of this programme were selected") {
                let versionScanner = Scanner(string: output)
                versionScanner.scanUpTo("available versions:", into: nil)
                versionScanner.scanString("available versions:", into: nil)
                versionScanner.scanCharacters(from: .whitespaces, into: nil)
                let availableVersions = versionScanner.scanUpToString(")")
                if (availableVersions as NSString?)?.range(of: "audiodescribed").location != NSNotFound || (availableVersions as NSString?)?.range(of: "signed").location != NSNotFound {
                    reasonForFailure = "AudioDescribedOnly"
                }
            } else if output.hasPrefix("INFO: Downloading thumbnail") {
                show.status = "Downloading Artwork.."
                setPercentage(102)
                setCurrentProgress("Downloading Artwork.. -- \(show.showName)")
            } else if output.hasPrefix("INFO:") || output.hasPrefix("WARNING:") || output.hasPrefix("ERROR:") || output.hasSuffix("default") || output.hasPrefix(show.pid) {
                // Do nothing! This ensures we don't process any other info messages
            } else if output.hasSuffix("[audio+video]") || output.hasSuffix("[audio]") || output.hasSuffix("[video]") {
                //Process iPhone/Radio Downloads Status Message
                let scanner = Scanner(string: output)
                var percentage: Decimal?
                var h: Decimal?
                var m: Decimal?
                var s: Decimal?
                scanner.scanUpToCharacters(
                    from: .decimalDigits,
                    into: nil)
                percentage = scanner.scanDecimal()
                setPercentage(NSDecimalNumber(decimal: percentage ?? .zero).doubleValue)

                // Jump ahead to the ETA field.
                scanner.scanUpTo("ETA: ", into: nil)
                scanner.scanString("ETA: ", into: nil)
                scanner.scanUpToCharacters(
                    from: .decimalDigits,
                    into: nil)
                h = scanner.scanDecimal()
                scanner.scanUpToCharacters(
                    from: .decimalDigits,
                    into: nil)
                m = scanner.scanDecimal()
                scanner.scanUpToCharacters(
                    from: .decimalDigits,
                    into: nil)
                s = scanner.scanDecimal()
                scanner.scanUpToCharacters(
                    from: .decimalDigits,
                    into: nil)

                let eta = String(format: "%.2ld:%.2ld:%.2ld remaining", NSDecimalNumber(decimal: h ?? .zero).intValue, NSDecimalNumber(decimal: m ?? .zero).intValue, NSDecimalNumber(decimal: s ?? .zero).intValue)
                setCurrentProgress(eta)

                var format = "Video downloaded: %ld%%"

                if output.hasSuffix("[audio+video]") {
                    format = "Downloaded %ld%%"
                } else if output.hasSuffix("[audio]") {
                    format = "Audio download: %ld%%"
                } else if output.hasSuffix("[video]") {
                    format = "Video download: %ld%%"
                }

                if let percentage {
                    show.status = String(format: format, NSDecimalNumber(decimal: percentage).intValue)
                }
            }
        }
    }
}
