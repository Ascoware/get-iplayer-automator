//
//  ITVDownload.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/1/18.
//

import Foundation
import Kanna
import SwiftyJSON

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
        
        self.currentRequest = self.session.dataTask(with: downloadRequest) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                self.metaRequestFinished(response: httpResponse, data: data, error: error)
            }
        }
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
        let enUSPOSIXLocale = Locale(identifier:"en_US_POSIX")
        longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)
        longDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        longDateFormatter.locale = enUSPOSIXLocale

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "EEE MMM dd"
        shortDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        shortDateFormatter.locale = enUSPOSIXLocale

        if let htmlPage = try? HTML(html: responseString, encoding: .utf8) {
            // There should only be one 'video' element.
            if let videoElement = htmlPage.at_xpath("//div[@id='video']") {
                seriesName = videoElement.at_xpath("//@data-video-title")?.text ?? "Unknown"
                episode = videoElement.at_xpath("//@data-video-episode")?.text ?? ""
                episodeID = videoElement.at_xpath("//@data-video-episode-id")?.text ?? ""
            }
            
            if let descriptionElement = htmlPage.at_xpath("//script[@id='json-ld']") {
                if let descriptionJSON = descriptionElement.content {
                    let descriptionData = JSON(parseJSON: descriptionJSON)
                    let breadcrumbs = descriptionData["itemListElement:"].arrayValue
                    for item in breadcrumbs {
                        if item["item:"]["@type"] == "TVEpisode" {
                            let showMetadata = item["item:"]
                            showDescription = showMetadata["description"].string ?? "None available"
                            episodeNumber = showMetadata["episodeNumber"].intValue
                            seriesNumber = showMetadata["partOfSeason"]["seasonNumber"].intValue
                            episode = showMetadata["name"].stringValue
                            thumbnailURL = showMetadata["image"].dictionaryValue["url"]?.stringValue

                            let potentialActions = showMetadata["potentialAction"].arrayValue

                            if potentialActions.count > 0 {
                                let potentialAction = potentialActions[0]
                                let expectActions = potentialAction["expectsAcceptanceOf"].arrayValue

                                if expectActions.count > 0 {
                                    let expectAction = expectActions[0]
                                    let availabilityTime = expectAction["availabilityStarts"].stringValue
                                    timeAired = longDateFormatter.date(from:availabilityTime)
                                }
                            }
                            
                            break
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

    @objc public func youtubeDLProgress(progressNotification: Notification?) {
        guard let fileHandle = progressNotification?.object as? FileHandle else {
            return
        }
        guard let data = progressNotification?.userInfo?[NSFileHandleNotificationDataItem] as? Data,
              data.count > 0,
              let s = String(data: data, encoding: .utf8) else {
            return
        }

        fileHandle.readInBackgroundAndNotify()

        let splitStrings = s.split(separator: "\n")

        for substring in splitStrings {
            if self.verbose && !substring.isEmpty {
                self.logger.add(toLog: String(substring))
            }
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
                show.status = "Downloaded \(progress)%"
            }
            
            if let remaining = remaining {
                setCurrentProgress("Downloading \(show.showName) -- \(remaining) until done")
            }
        }
    }
    
    public func youtubeDLTaskFinished(_ proc: Process) {
        self.add(toLog: "youtube-dl finished downloading")

        self.task = nil
        self.pipe = nil
        self.errorPipe = nil
        
        let exitCode = proc.terminationStatus
        if exitCode == 0 {
            self.show.complete = true
            self.show.successful = true
            let info = ["Programme" : self.show]
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AddProgToHistory"), object:self, userInfo:info)
                self.youtubeDLFinishedDownload()
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
                
                let downloadTask: URLSessionDownloadTask? = session.downloadTask(with: URL(string: thumbnailURL)!) { (location, _, _) in
                    self.thumbnailRequestFinished(location)
                }
                downloadTask?.resume()
            }
            else {
                self.add(toLog: "No thumbnail URL, skipping")
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
        let fh = pipe?.fileHandleForReading
        let errorFh = errorPipe?.fileHandleForReading
        
        var args: [String] = [show.url,
                              "-f",
                              "mp4/best",
                              "-o",
                              downloadPath]
        
        if let downloadSubs = UserDefaults.standard.object(forKey: "DownloadSubtitles") as? Bool, downloadSubs {
            args.append("--write-sub")
            
            if let embedSubs = UserDefaults.standard.object(forKey: "EmbedSubtitles") as? Bool, embedSubs {
                args.append("--embed-subs")
            } else {
                args.append("-k")
            }
        }

        if verbose {
            args.append("--verbose")
        }
        
        if let proxyHost = self.proxy?.host {
            var proxyString = ""

            if let user = self.proxy?.user, let password = self.proxy?.password {
                proxyString += "\(user):\(password)@"
            }

            proxyString += proxyHost
            
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
            let resourcePath = Bundle.main.resourcePath
        {
            task?.launchPath = executableURL.path
            task?.arguments = args
            let extraBinaryPath = AppController.shared().extraBinariesPath
            var envVariableDictionary = [String : String]()
            envVariableDictionary["PATH"] = "\(binaryPath):\(extraBinaryPath):/usr/bin"
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
}

