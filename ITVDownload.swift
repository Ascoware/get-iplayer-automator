//
//  ITVDownload.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/1/18.
//

import Foundation
import Kanna

public class ITVDownload : Download {
    
    // Only used for ffmpeg downloads to track progress.
    var durationInSeconds: Int = 0
    var elapsedInSeconds: Int = 0
    
    // Used when ffmpeg converts from flv to mp4
    var downloadedFileURL: URL? = nil
    
    public override var description: String {
        return "ITV Download (ID=\(show.pid))"
    }
    
    @objc public override init() {
        super.init()
        // Nothing to do here.
    }
    
    @objc public init(programme: Programme, formats: [TVFormat]?, proxy: HTTPProxy?, logger: LogController) {
        super.init(logController: logger)
        self.proxy = proxy
        self.show = programme
        self.attemptNumber=1
        self.defaultsPrefix = "ITV_"
        self.running = true

//        guard let formats = formats, formats.count > 0 else {
//            print("ERROR: ITV Format List is empty")
//            add(toLog: "ERROR: ITV Format List is empty")
//            show.reasonForFailure = "ITVFormatListEmpty"
//            show.complete = true
//            show.successful = false
//            show.setValue("Download Failed", forKey:"status")
//            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "DownloadFinished"), object:self.show)
//            return
//        }
        
        setCurrentProgress("Retrieving Programme Metadata... \(show.showName)")
        setPercentage(102)
        programme.status = "Initialising..."
        
//        formatList = formats
        add(toLog: "Downloading \(show.showName)")
        add(toLog: "INFO: Preparing Request for Auth Info", noTag: true)
        
        DispatchQueue.main.async {
            self.launchMetaRequest()
        }
    }
    @objc public override func launchMetaRequest() {
        self.errorCache = NSMutableString()
        self.processErrorCache = Timer(timeInterval:0.25, target:self, selector:#selector(processError), userInfo:nil, repeats:true)
        
        guard let requestURL = URL(string: show.url) else {
            return
        }
        
        self.currentRequest.cancel()
        var downloadRequest = URLRequest(url:requestURL)
        
        downloadRequest.timeoutInterval = 10
        self.session = URLSession.shared
        
        if let proxy = self.proxy {
            // Create an NSURLSessionConfiguration that uses the proxy
            var proxyDict: [String: Any] = [kCFProxyTypeKey as String : kCFProxyTypeHTTP as String,
                                            kCFNetworkProxiesHTTPEnable as String : true,
                                            kCFNetworkProxiesHTTPProxy as String : proxy.host,
                                            kCFStreamPropertyHTTPProxyPort as String : proxy.port,
                                            kCFNetworkProxiesHTTPSEnable as String : true,
                                            kCFNetworkProxiesHTTPSProxy as String : proxy.host,
                                            kCFStreamPropertyHTTPSProxyPort as String : proxy.port]
            
            if let user = proxy.user, let password = proxy.password {
                proxyDict[kCFProxyUsernameKey as String] = user
                proxyDict[kCFProxyPasswordKey as String] = password
            }
            
            let configuration = URLSessionConfiguration.ephemeral
            configuration.connectionProxyDictionary = proxyDict
            
            // Create a NSURLSession with our proxy aware configuration
            self.session = URLSession(configuration:configuration, delegate:nil, delegateQueue:OperationQueue.main)
        }
        
        let message = "INFO: Requesting Metadata."
        print(message)
        if (self.verbose) {
            add(toLog:message, noTag:true)
        }
        
        self.currentRequest = self.session.dataTask(with: downloadRequest, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) in
            if let httpResponse = response as? HTTPURLResponse {
                self.metaRequestFinished(response: httpResponse,
                                         data: data,
                                         error: error)
                
            }
        })
        self.currentRequest.resume()
    }
    
    func metaRequestFinished(response: HTTPURLResponse, data: Data?, error: Error?) {
        guard self.running else {
            return
        }
        
        guard response.statusCode != 0 || response.statusCode == 200, let data = data, let responseString = String(data:data, encoding:.utf8) else {
            var message: String = ""
            
            if response.statusCode == 0 {
                message = "ERROR: No response received (probably a proxy issue): \(error?.localizedDescription ?? "Unknown error")"
                self.show.reasonForFailure = "Internet_Connection"
                self.show.status = "Failed: Bad Proxy"
            } else {
                message = "ERROR: Could not retrieve programme metadata: \(error?.localizedDescription ?? "Unknown error")"
                self.show.status = "Download Failed"
            }
            
            self.show.successful = false
            self.show.complete = true
            print(message)
            add(toLog: message)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
            add(toLog:"Download Failed", noTag:false)
            return
        }
        
        
        let message = "DEBUG: Metadata response status code: \(response.statusCode)"
        print(message)
        
        if verbose {
            add(toLog: message, noTag: true)
        }

        var seriesName = ""
        var episode = ""
        var episodeID = ""
        var showDescription = ""
        var timeAired: Date? = nil
        var episodeNumber = 0
        var seriesNumber = 0
        let longDateFormatter = DateFormatter()
        longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)
        longDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "EEE MMM dd"
        shortDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let htmlPage = try? HTML(html: responseString, encoding: .utf8) {
            // There should only be one 'video' element.
            if let videoElement = htmlPage.at_xpath("//div[@id='video']") {
                seriesName = videoElement.at_xpath("//@data-video-title")?.text ?? "Unknown"
                episode = videoElement.at_xpath("//@data-video-episode")?.text ?? ""
                episodeID = videoElement.at_xpath("//@data-video-episode-id")?.text ?? ""
            }
            
            if let descriptionElement = htmlPage.at_xpath("//script[@id='json-ld']") {
                if let descriptionJSON = descriptionElement.content {
                    if let data = descriptionJSON.data(using: .utf8) {
                        if let descJSONDict = try? JSONSerialization.jsonObject(with: data) as? [String : Any] {
                            showDescription = descJSONDict? ["description"] as? String ?? "None available"
                            episodeNumber = descJSONDict?["episodeNumber"] as? Int ?? 0
                            if let seriesDict = descJSONDict?["partOfSeason"] as? [String: Any] {
                                seriesNumber = seriesDict["seasonNumber"] as? Int ?? 0
                            }
                            
                            episode = descJSONDict? ["name"] as? String ?? ""

                            if let imageDict = descJSONDict? ["image"] as? [String : Any],
                                let thumbnailURLString = imageDict["url"] as? String {
                                self.thumbnailURL = thumbnailURLString
                            }

                            if let potentialActionDict = descJSONDict?["potentialAction"] as? [[String: Any]],
                                let expectsAcceptanceDict = potentialActionDict[0]["expectsAcceptanceOf"] as? [[String: Any]],
                                let availabilityTime = expectsAcceptanceDict[0]["availabilityStarts"] as? String {
                                timeAired = longDateFormatter.date(from:availabilityTime)
                            }
                        }
                    }
                }
            }
            
        }

        if episodeNumber == 0 && seriesNumber == 0 && !episodeID.isEmpty {
            // At this point all we have left is the production ID.
            // A series number doesn't make much sense, so just parse out an episode number.
            let programIDElements = episodeID.split(separator: "/")
            if let lastElement = programIDElements.last, let intLastElement = Int(lastElement) {
                episodeNumber = intLastElement
            }
        }
        
        // Save off the pieces we care about.
        self.show.episode = episodeNumber
        self.show.season = seriesNumber
        self.show.seriesName = seriesName
        self.show.desc = showDescription
        
        if !episode.isEmpty {
            self.show.episodeName = episode
        } else if let timeAired = timeAired {
            let shortDate = shortDateFormatter.string(from: timeAired)
            self.show.episodeName = shortDate
        }
        self.thumbnailURL = thumbnailURL ?? nil
        
        if let timeAired = timeAired {
            self.show.standardizedAirDate = longDateFormatter.string(from: timeAired)
        }
        
        add(toLog:"INFO: Metadata processed.", noTag:true)
        
        //Create Download Path
        self.createDownloadPath()
        
        // show.path will be set when youtube-dl tells us the destination.

        DispatchQueue.main.async {
            self.launchYoutubeDL()
        }
    }

    // This seems inefficient, because we already got a string. Unfortunately it has a fraction of a second
    // which makes it more complicated to parse. This is faster.
    func stringFromTimeInterval(_ interval: Int) -> String {
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    fileprivate func convertToSeconds(_ timeString: String) -> Int {
        let timeParts = timeString.split {($0 == ":") || ($0 == ".")}
        var timeInSeconds = 0
        for (i, d) in timeParts.enumerated() {
            if let x = Int(d) {
                switch (i) {
                case 0:
                    timeInSeconds += x * 60 * 60
                case 1:
                    timeInSeconds += x * 60
                case 2:
                    timeInSeconds += x
                default:
                    break
                    // Don't worry about fractions.
                }
            }
        }
        
        return timeInSeconds
    }
    
    @objc public func youtubeDLProgress(progressNotification: Notification?) {
        guard let data = progressNotification?.userInfo?[NSFileHandleNotificationDataItem] as? Data, data.count > 0,
            let s = String(data: data, encoding: .utf8) else {
                fh?.readInBackgroundAndNotify()
                errorFh?.readInBackgroundAndNotify()
                return
        }
        
        if self.verbose {
            self.logger.add(toLog: s)
        }
        
        if s.contains("Writing video subtitles") {
            //ITV Download (ID=2a4910a0046): [info] Writing video subtitles to: /Users/skovatch/Movies/TV Shows/LA Story/LA Story - Just Friends - 2a4910a0046.en.vtt
            let scanner = Scanner(string: s)
            scanner.scanUpToString("to: ")
            scanner.scanString("to: ")
            subtitlePath = scanner.scanUpToString("\n") ?? ""
            if self.verbose {
                self.add(toLog: "Subtitle path = \(subtitlePath)")
            }
        }
        
        if s.contains("Destination: ") {
            let scanner = Scanner(string: s)
            scanner.scanUpToString("Destination: ")
            scanner.scanString("Destination: ")
            self.show.path = scanner.scanUpToString("\n") ?? ""
            if self.verbose {
                self.add(toLog: "Downloading to \(self.show.path)")
            }
        }
        
        // youtube-dl native download generates a percentage complete and ETA remaining
        var progress: String? = nil
        var remaining: String? = nil
        
        // ffmpeg download outputs how much of the show was downloaded.
        // At the beginning of the download it prints the duration of the show.
        var duration: String? = nil
        var elapsed: String? = nil
        
        if s.contains("[download]") {
            let scanner = Scanner(string: s)
            scanner.scanUpToString("[download]")
            scanner.scanString("[download]")
            progress = scanner.scanUpToString("%")?.trimmingCharacters(in: .whitespaces)
            scanner.scanUpToString("ETA ")
            scanner.scanString("ETA ")
            remaining = scanner.scanUpToCharactersFromSet(set: .whitespacesAndNewlines)
            
            if let progress = progress, let progressVal = Double(progress) {
                setPercentage(progressVal)
            }
            
            if let remaining = remaining {
                setCurrentProgress("Downloading \(show.showName) -- \(remaining) until done")
            }
        } else if s.contains("Duration:") {
            let scanner = Scanner(string: s)
            scanner.scanUpToString("Duration:")
            scanner.scanString("Duration:")
            duration = scanner.scanUpToString(",")?.trimmingCharacters(in: .whitespaces)
        } else if s.contains("time=") {
            let scanner = Scanner(string: s)
            scanner.scanUpToString("time=")
            scanner.scanString("time=")
            elapsed = scanner.scanUpToString(" ")?.trimmingCharacters(in: .whitespaces)
        }
        
        if let duration = duration {
            durationInSeconds = convertToSeconds(duration)
        }
        if let elapsed = elapsed {
            elapsedInSeconds = convertToSeconds(elapsed)
        }
        
        // This code should only be run for ffmpeg downloads.
        if elapsedInSeconds != 0 && durationInSeconds != 0 {
            setPercentage(100.0 * Double(elapsedInSeconds) / Double(durationInSeconds))
            let formattedElapsed = stringFromTimeInterval(elapsedInSeconds)
            let formattedDuration = stringFromTimeInterval(durationInSeconds)
            setCurrentProgress("Downloading \(show.showName) -- \(formattedElapsed) of \(formattedDuration)")
        }

        fh?.readInBackgroundAndNotify()
        errorFh?.readInBackgroundAndNotify()
    }
    
    public func youtubeDLTaskFinished(_ proc: Process) {
        self.add(toLog: "youtube-dl finished downloading")
        processErrorCache.invalidate()
        self.processErrorCache.invalidate()
        let exitCode = proc.terminationStatus
        if exitCode == 0 {
            if self.show.path.hasSuffix("flv") {
                // Need to convert to MP4
                DispatchQueue.main.async {
                    self.convertToMP4()
                }
            } else {
                self.show.complete = true
                self.show.successful = true
                let info = ["Programme" : self.show]
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AddProgToHistory"), object:self, userInfo:info)
                    self.youtubeDLFinishedDownload()
                }
            }
        } else {
            self.show.complete = true
            self.show.successful = false
            self.show.status = "Download Failed"
            
            // We can't be sure we were terminated or that youtube-dl died.
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)        
        }
    }
    
    @objc public func youtubeDLFinishedDownload() {
        if let tagOption = UserDefaults.standard.object(forKey: "TagShows") as? Bool, tagOption {
            self.show.status = "Downloading Thumbnail..."
            setPercentage(102)
            setCurrentProgress("Downloading Thumbnail... -- \(show.showName)")
            if let thumbnailURL = thumbnailURL {
                add(toLog: "INFO: Downloading thumbnail", noTag: true)
                thumbnailPath = URL(fileURLWithPath: show.path).appendingPathExtension("jpg").path
                let downloadTask: URLSessionDownloadTask? = session.downloadTask(with: URL(string: thumbnailURL)!, completionHandler: {(_ location: URL?, _ response: URLResponse?, _ error: Error?) -> Void in
                    self.thumbnailRequestFinished(location)
                })
                downloadTask?.resume()
            }
            else {
                thumbnailRequestFinished(nil)
            }
        }
        else {
            atomicParsleyFinished(nil)
        }
    }
    
    
    private func launchYoutubeDL() {
        setCurrentProgress("Downloading \(show.showName)")
        setPercentage(102)
        show.status = "Downloading..."
        
        task = Process()
        pipe = Pipe()
        errorPipe = Pipe()
        task?.standardInput = FileHandle.nullDevice
        task?.standardOutput = pipe
        task?.standardError = errorPipe
        fh = pipe?.fileHandleForReading
        errorFh = errorPipe?.fileHandleForReading
        
        var args: [String] = [show.url,
                              "-f",
                              "mp4/best",
                              "-o",
                              downloadPath]
        
        if let downloadSubs = UserDefaults.standard.object(forKey: "DownloadSubtitles") as? Bool, downloadSubs {
            args.append("--write-sub")
        }
        
        if verbose {
            args.append("--verbose")
        }
        if let proxyHost = self.proxy?.host {
            var proxyString = proxyHost
            if let port = self.proxy?.port {
                proxyString += ":\(port)"
            }
            
            args.append("--proxy")
            args.append(proxyString)
        }
        
        if self.verbose {
            self.logDebugMessage("DEBUG: youtube-dl args:\(args)", noTag: true)
        }
        
        if let executableURL = Bundle.main.url(forResource: "youtube-dl", withExtension:nil),
            let binaryPath = Bundle.main.executableURL?.deletingLastPathComponent().path,
            let resourcePath = Bundle.main.resourcePath {
            task?.launchPath = executableURL.path
            task?.arguments = args
            var envVariableDictionary = [String : String]()
            envVariableDictionary["PATH"] = "\(binaryPath):/usr/bin"
            envVariableDictionary["PYTHONPATH"] = "\(resourcePath)"
            task?.environment = envVariableDictionary
            self.logDebugMessage("DEBUG: youtube-dl environment: \(envVariableDictionary)", noTag: true)
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.youtubeDLProgress), name: FileHandle.readCompletionNotification, object: fh)
            NotificationCenter.default.addObserver(self, selector: #selector(self.youtubeDLProgress), name: FileHandle.readCompletionNotification, object: errorFh)

            task?.terminationHandler = youtubeDLTaskFinished
            
            task?.launch()
            fh?.readInBackgroundAndNotify()
            errorFh?.readInBackgroundAndNotify()
        }
    }
    
    func convertToMP4() {
        ffTask = Process()
        ffPipe = Pipe()
        ffErrorPipe = Pipe()
        
        guard let ffTask = self.ffTask, let ffPipe = self.ffPipe, let ffErrorPipe = self.ffErrorPipe else {
            assert(false, "Help? Can't create a process or pipe?")
            return
        }
        
        ffTask.standardOutput = ffPipe
        ffTask.standardError = ffErrorPipe
        ffFh = ffPipe.fileHandleForReading
        ffErrorFh = ffErrorPipe.fileHandleForReading
        downloadedFileURL = URL(fileURLWithPath: self.show.path)
        let convertedFileURL = downloadedFileURL!.deletingPathExtension().appendingPathExtension("mp4")
        show.path = convertedFileURL.path
        let binaryPath = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("ffmpeg")

        ffTask.launchPath = binaryPath?.path
        ffTask.arguments = ["-i",
                            "\(downloadedFileURL!.path)",
                            "-c:a",
                            "copy",
                            "-c:v",
                            "copy",
                            "\(convertedFileURL.path)"]
        NotificationCenter.default.addObserver(self, selector: #selector(ffmpegFinished), name: Process.didTerminateNotification, object: ffTask)
        ffTask.launch()
        ffFh?.readInBackgroundAndNotify()
        ffErrorFh?.readInBackgroundAndNotify()
        setCurrentProgress("Converting... -- \(show.showName)")
        show.status = "Converting..."
        add(toLog: "INFO: Converting FLV File to MP4", noTag: true)
        self.setPercentage(102)
    }

    
    @objc func ffmpegFinished(_ finishedNote: Notification) {
        print("Conversion Finished")
        add(toLog: "INFO: Finished Converting.", noTag: true)
        if let process = finishedNote.object as? Process {
            if process.terminationStatus != 0 {
                add(toLog: "INFO: Exit Code = \(process.terminationStatus)", noTag: true)
                self.show.status = "Download Complete"
                show.path = downloadPath
                NotificationCenter.default.removeObserver(self)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
            } else {
                
                if let downloadedFile = downloadedFileURL {
                    try? FileManager.default.removeItem(at: downloadedFile)
                }

                self.show.complete = true
                self.show.successful = true
                let info = ["Programme" : self.show]
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AddProgToHistory"), object:self, userInfo:info)
                    self.youtubeDLFinishedDownload()
                }
            }
        }
}
}

