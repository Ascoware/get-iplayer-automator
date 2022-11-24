//
//  Download.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 11/9/22.
//

import Foundation
import CocoaLumberjackSwift

@objcMembers public class Download : NSObject {
    var show: Programme
    var task: Process?
    var pipe: Pipe?
    var errorPipe: Pipe?

    //Download Information
    var subtitleURL: String?
    var downloadPath: String = ""
    var subtitlePath: String = ""
    //Subtitle Conversion
    var subsTask: Process?
    var subsErrorPipe: Pipe?
    var defaultsPrefix: String = ""
    var running = true
    //Proxy Info
    var proxy: HTTPProxy?
    // If proxy is set, this will be a session configured with the set proxy.
    // Otherwise, it uses the system (shared) session information.
    var currentRequest: URLSessionDataTask?

    public override init() {
        show = Programme()
    }

    // MARK: Notification Posters

    func setCurrentProgress(_ string: String) {
        NotificationCenter.default.post(name: NSNotification.Name("setCurrentProgress"), object: self, userInfo: [
            "string": string
        ])
    }

    func setPercentage(_ d: Double) {
        if d <= 100.0 {
            let value = NSNumber(value: d)
            NotificationCenter.default.post(name: NSNotification.Name("setPercentage"), object: self, userInfo: [
                "nsDouble": value
            ])
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("setPercentage"), object: self, userInfo: nil)
        }
    }

    // MARK: Message Processers

    func safeAppend(_ array: inout [String], key: String, value: String) {
        if !key.isEmpty, !value.isEmpty {
            array.append(key)
            // Converts any object into a string representation
            array.append("\(value)")
        } else {
            DDLogWarn("WARNING: AtomicParsley key: \(key), value: \(value)")
        }
    }

    func tagDownloadWithMetadata() {
        if show.path.isEmpty {
            DDLogWarn("WARNING: Can't tag, no path")
            atomicParsleyFinished(nil)
            return
        }

        let apTask = Process()

        apTask.launchPath = URL(fileURLWithPath: AppController.shared().extraBinariesPath).appendingPathComponent("AtomicParsley").path

        var arguments = [String]()
        arguments.append(show.path)
        safeAppend(&arguments, key: "--stik", value: "value=10")
        safeAppend(&arguments, key: "--TVNetwork", value: show.tvNetwork)
        safeAppend(&arguments, key: "--TVShowName", value: show.seriesName)
        safeAppend(&arguments, key: "--TVSeasonNum", value: String(show.season))
        safeAppend(&arguments, key: "--TVEpisodeNum", value: String(show.episode))
        safeAppend(&arguments, key: "--TVEpisode", value: show.episodeName)
        safeAppend(&arguments, key: "--title", value: show.episodeName)
        safeAppend(&arguments, key: "--description", value: show.desc)
        safeAppend(&arguments, key: "--artist", value: show.tvNetwork)
        safeAppend(&arguments, key: "--year", value: show.lastBroadcastString)
        arguments.append("--overWrite")

        apTask.arguments = arguments

        DDLogVerbose("DEBUG: AtomicParsley args:\(arguments)")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(atomicParsleyFinished(_:)),
            name: Process.didTerminateNotification,
            object: apTask)

        DDLogInfo("INFO: Beginning AtomicParsley Tagging.")

        apTask.launch()
        setCurrentProgress("Tagging the Programme... -- \(show.showName)")
    }

    @objc func atomicParsleyFinished(_ finishedNote: Notification?) {
        if let termination = finishedNote?.object as? Process {
            if termination.terminationStatus == 0 {
                DDLogInfo("INFO: AtomicParsley Tagging finished.")
                show.successful = true
            } else {
                DDLogInfo("INFO: Tagging failed.")
                show.successful = false
            }
        }

        if UserDefaults.standard.bool(forKey: "DownloadSubtitles") {
            // youtube-dl should try to download a subtitle file, but if there isn't one log it and continue.
            if FileManager.default.fileExists(atPath: subtitlePath) {
                if URL(fileURLWithPath: subtitlePath).pathExtension != "srt" {
                    show.status = "Converting Subtitles..."
                    setPercentage(102)
                    setCurrentProgress("Converting Subtitles... -- \(show.showName)")
                    DDLogInfo("INFO: Converting Subtitles...")
                    if URL(fileURLWithPath: subtitlePath).pathExtension == "ttml" {
                        convertTTMLToSRT()
                    } else {
                        convertWebVTTToSRT()
                    }
                } else {
                    convertSubtitlesFinished(nil)
                }
            } else {
                // If youtube-dl embeds subtitles for us it deletes the raw subtitle file. When that happens
                // we don't know if it was subtitled or not, so don't report an error when embedding is on.
                if !UserDefaults.standard.bool(forKey: "EmbedSubtitles") {
                    DDLogInfo("INFO: No subtitles were found for \(show.showName)")
                }
                convertSubtitlesFinished(nil)
            }
        } else {
            convertSubtitlesFinished(nil)
        }
    }

    func convertWebVTTToSRT() {
        if subtitlePath.isEmpty {
            convertSubtitlesFinished(nil)
        } else {
            DispatchQueue.main.async(execute: { [self] in
                DDLogInfo("INFO: Converting to SubRip: \(subtitlePath)")

                var outputURL = URL(fileURLWithPath: subtitlePath)
                outputURL = outputURL.deletingPathExtension().appendingPathExtension("srt")
                var args: [String] = []

                // TODO: Figure out if I can bring this back. ffmpeg doesn't support it.
                //            BOOL srtIgnoreColors = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@SRTIgnoreColors", self.defaultsPrefix]];
                //            if (srtIgnoreColors)
                //            {
                //                [args addObject:@"--srt-ignore-colors"];
                //            }

                args.append("-i")
                args.append(subtitlePath)
                args.append(outputURL.path)

                subsTask = Process()
                subsErrorPipe = Pipe()
                subsTask?.standardError = subsErrorPipe
                NotificationCenter.default.addObserver(self, selector: #selector(convertSubtitlesFinished(_:)), name: Process.didTerminateNotification, object: subsTask)

                let ffmpegURL = URL(fileURLWithPath: AppController.shared().extraBinariesPath).appendingPathComponent("ffmpeg").path
                subsTask?.launchPath = ffmpegURL
                subsTask?.arguments = args
                subsTask?.launch()
            })
        }
    }

    func convertTTMLToSRT() {
        if subtitlePath.isEmpty {
            convertSubtitlesFinished(nil)
        } else {
            DispatchQueue.main.async(execute: { [self] in
                DDLogInfo("INFO: Converting to SubRip: \(subtitlePath)")
                let ttml2srtPath = Bundle.main.path(forResource: "ttml2srt.py", ofType: nil)
                var args = [ttml2srtPath]

                let srtIgnoreColors = UserDefaults.standard.bool(forKey: "\(defaultsPrefix)SRTIgnoreColors")
                if srtIgnoreColors {
                    args.append("--srt-ignore-colors")
                }

                args.append(subtitlePath)

                subsTask = Process()
                subsErrorPipe = Pipe()
                subsTask?.standardError = subsErrorPipe
                NotificationCenter.default.addObserver(self, selector: #selector(convertSubtitlesFinished(_:)), name: Process.didTerminateNotification, object: subsTask)

                let pythonInstall = Bundle.main.url(forResource: "python", withExtension: nil)
                let pythonPath = pythonInstall?.appendingPathComponent("bin/python3.11", isDirectory: false)

                subsTask?.launchPath = pythonPath?.path
                subsTask?.arguments = args.compactMap { $0 }
                subsTask?.launch()
            })
        }
    }

    @objc func convertSubtitlesFinished(_ aNotification: Notification?) {

        if let aNotification, let process = aNotification.object as? Process {
            // Should not get inside this code for ITV (webvtt) subtitles.
            if process.terminationStatus == 0 {
                try? FileManager.default.removeItem(atPath: subtitlePath)
                DDLogInfo("INFO: Conversion to SubRip complete")
            } else {
                DDLogError("ERROR: Conversion to SubRip failed: \(subtitlePath)")
                if let errData = subsErrorPipe?.fileHandleForReading.readDataToEndOfFile(),
                   let errString = String(data: errData, encoding: .utf8) {
                    DDLogError("\(errString)")
                }
            }
        }
        show.status = "Download Complete"
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.post(name: NSNotification.Name("DownloadFinished"), object: show)
        subsTask = nil
        subsErrorPipe = nil
    }

    func cancel() {

        currentRequest?.cancel()
        //Some basic cleanup.
        if task?.isRunning ?? false {
            task?.terminate()
        }

        task = nil
        pipe = nil
        errorPipe = nil

        NotificationCenter.default.removeObserver(self, name: FileHandle.readCompletionNotification, object: nil)
        show.status = "Cancelled"
        show.complete = false
        show.successful = false
        DDLogInfo("\(self): Download Cancelled")
        running = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
