//
//  ITVDownload.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/1/18.
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjackSwift

public class ITVDownload : Download {

    public override var description: String {
        return "ITV Download (ID=\(show.pid))"
    }
    
    @objc public override init() {
        super.init()
        // Nothing to do here.
    }
    
    @objc public init(programme: Programme, proxy: HTTPProxy?) {
        super.init()
        self.proxy = proxy
        self.show = programme
        self.defaultsPrefix = "ITV_"
        self.running = true
        
        setCurrentProgress("Retrieving Programme Metadata... \(show.showName)")
        setPercentage(102)
        programme.status = "Initialising..."
        
        //        formatList = formats
        DDLogInfo("Downloading \(show.showName)")
        DDLogInfo("INFO: Preparing Request for Auth Info")
        
        DispatchQueue.main.async {
            guard let requestURL = URL(string: self.show.url) else {
                return
            }

            self.currentRequest.cancel()
            var downloadRequest = URLRequest(url:requestURL)

            downloadRequest.timeoutInterval = 10
            self.session = URLSession.shared

            if let proxy = self.proxy {
                // Create an NSURLSessionConfiguration that uses the proxy
                var proxyDict: [AnyHashable : Any] = [kCFNetworkProxiesHTTPEnable : true,
                                                       kCFNetworkProxiesHTTPProxy : proxy.host,
                                                        kCFNetworkProxiesHTTPPort : proxy.port,
                                                     kCFNetworkProxiesHTTPSEnable : true,
                                                      kCFNetworkProxiesHTTPSProxy : proxy.host,
                                                       kCFNetworkProxiesHTTPSPort : proxy.port]

                if let user = proxy.user, let password = proxy.password {
                    proxyDict[kCFProxyUsernameKey] = user
                    proxyDict[kCFProxyPasswordKey] = password
                }

                let configuration = URLSessionConfiguration.ephemeral
                configuration.connectionProxyDictionary = proxyDict

                // Create a NSURLSession with our proxy aware configuration
                self.session = URLSession(configuration:configuration, delegate:nil, delegateQueue:OperationQueue.main)
            }

            DDLogVerbose("ITV: Requesting Metadata")

            self.currentRequest = self.session.dataTask(with: downloadRequest) { (data, response, error) in
                if let httpResponse = response as? HTTPURLResponse {
                    self.metaRequestFinished(response: httpResponse, data: data, error: error)
                }
            }
            self.currentRequest.resume()
        }
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
            DDLogError(message)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
            return
        }
        
        
        DDLogDebug("DEBUG: Metadata response status code: \(response.statusCode)")

        let showMetadata = ITVMetadataExtractor.getShowMetadata(htmlPageContent: responseString)
        self.show.desc = showMetadata.desc
        self.show.episode = showMetadata.episode
        self.show.season = showMetadata.season
        self.show.episodeName = showMetadata.episodeName
        self.show.thumbnailURLString = showMetadata.thumbnailURLString

        DDLogInfo("INFO: Metadata processed.")
        
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

        let lines = s.components(separatedBy: .newlines)

        for line in lines {
            DDLogInfo(line)

            if line.contains("Writing video subtitles") {
                //ITV Download (ID=2a4910a0046): [info] Writing video subtitles to: /Users/skovatch/Movies/TV Shows/LA Story/LA Story - Just Friends - 2a4910a0046.en.vtt
                let scanner = Scanner(string: line)
                scanner.scanUpToString("to: ")
                scanner.scanString("to: ")
                subtitlePath = scanner.scanUpToString("\n") ?? ""
                DDLogDebug("Subtitle path = \(subtitlePath)")
            }

            if line.contains("Destination: ") {
                let scanner = Scanner(string: line)
                scanner.scanUpToString("Destination: ")
                scanner.scanString("Destination: ")
                self.show.path = scanner.scanUpToString("\n") ?? ""
                DDLogDebug("Downloading to \(self.show.path)")
            }

            // youtube-dl native download generates a percentage complete and ETA remaining
            var progress: String? = nil
            var remaining: String? = nil

            if line.contains("[download]") {
                let scanner = Scanner(string: line)
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

            if line.hasSuffix("has already been downloaded") {
                let scanner = Scanner(string: line)
                scanner.scanUpToString("[download]")
                scanner.scanString("[download]")
                self.show.path = scanner.scanUpToString("has already been downloaded")?.trimmingCharacters(in: .whitespaces) ?? ""
            }

            if line.hasPrefix("WARNING: Failed to download m3u8 information") {
                self.show.reasonForFailure = "proxy"
            }
        }
    }
    
    public func youtubeDLTaskFinished(_ proc: Process) {
        DDLogInfo("yt-dlp finished downloading")

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
            
            // Something went wrong inside youtube-dl.
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
        }
    }
    
    @objc public func youtubeDLFinishedDownload() {
        if let tagOption = UserDefaults.standard.object(forKey: "TagShows") as? Bool, tagOption {
            tagDownloadWithMetadata()
        } else {
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

        guard let youtubeDLFolder = Bundle.main.path(forResource: "yt-dlp_macos", ofType:nil),
              let cacertFile = Bundle.main.url(forResource: "cacert", withExtension: "pem") else {
            return
        }

        let youtubeDLBinary = youtubeDLFolder + "/yt-dlp_macos"
        var args: [String] = [show.url,
                              "--user-agent",
                              "Mozilla/5.0",
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

        if let verboseOption = UserDefaults.standard.object(forKey: "Verbose") as? Bool, verboseOption {
            args.append("--verbose")
        }

        if let tagOption = UserDefaults.standard.object(forKey: "TagShows") as? Bool, tagOption {
            args.append("--embed-thumbnail")
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
        
        DDLogVerbose("DEBUG: youtube-dl args:\(args)")


        task?.launchPath = youtubeDLBinary
        task?.arguments = args
        let extraBinaryPath = AppController.shared().extraBinariesPath
        var envVariableDictionary = [String : String]()
        envVariableDictionary["PATH"] = "\(youtubeDLFolder):\(extraBinaryPath)"
        envVariableDictionary["SSL_CERT_FILE"] = cacertFile.path
        task?.environment = envVariableDictionary
        DDLogVerbose("DEBUG: youtube-dl environment: \(envVariableDictionary)")

        NotificationCenter.default.addObserver(self, selector: #selector(self.youtubeDLProgress), name: FileHandle.readCompletionNotification, object: fh)
        NotificationCenter.default.addObserver(self, selector: #selector(self.youtubeDLProgress), name: FileHandle.readCompletionNotification, object: errorFh)

        task?.terminationHandler = youtubeDLTaskFinished

        task?.launch()
        fh?.readInBackgroundAndNotify()
        errorFh?.readInBackgroundAndNotify()
    }
}

