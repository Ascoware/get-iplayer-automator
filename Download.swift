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
    var hdVideo: Bool = false

    //Subtitle Conversion
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
        arguments.append("--overWrite")
        safeAppend(&arguments, key: "--hdvideo", value: hdVideo ? "true" : "false")
        safeAppend(&arguments, key: "--stik", value: "TV Show")
        safeAppend(&arguments, key: "--TVNetwork", value: show.tvNetwork)
        safeAppend(&arguments, key: "--TVShowName", value: show.seriesName)
        safeAppend(&arguments, key: "--TVSeasonNum", value: String(show.season))
        safeAppend(&arguments, key: "--TVEpisodeNum", value: String(show.episode))
        safeAppend(&arguments, key: "--TVEpisode", value: show.episodeName)
        safeAppend(&arguments, key: "--title", value: show.episodeName)
        safeAppend(&arguments, key: "--description", value: show.desc)
        safeAppend(&arguments, key: "--artist", value: show.tvNetwork)
        safeAppend(&arguments, key: "--year", value: show.lastBroadcastString)

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

        show.status = "Download Complete"
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.post(name: NSNotification.Name("DownloadFinished"), object: show)
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
