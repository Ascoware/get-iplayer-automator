//
//  ITVDownload.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/1/18.
//

import Foundation

public class ITVDownload : OldITVDownload {
    
    var authURL: String = ""
    
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

        guard let formats = formats, formats.count > 0 else {
            print("ERROR: ITV Format List is empty")
            add(toLog: "ERROR: ITV Format List is empty")
            show.reasonForFailure = "ITVFormatListEmpty"
            show.complete = true
            show.successful = false
            show.setValue("Download Failed", forKey:"status")
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "DownloadFinished"), object:self.show)
            return
        }
        
        setCurrentProgress("Retrieving Programme Metadata... \(show.showName)")
        setPercentage(102)
        programme.setValue("Initialising...", forKey: "status")
        
        formatList = formats
        add(toLog: "Downloading \(show.showName)")
        add(toLog: "INFO: Preparing Request for Auth Info", noTag: true)
        programme.printLongDescription()
        
        DispatchQueue.main.async {
            self.launchMetaRequest()
        }
    }
    
    @objc public override func launchMetaRequest() {
        self.errorCache = NSMutableString()
        self.processErrorCache = Timer(timeInterval:0.25, target:self, selector:#selector(processError), userInfo:nil, repeats:true)
        
        var soapBody = ""
        let url = show.url
        if !url.contains("Filter=") {
            self.show.realPID = self.show.pid
            soapBody = "Body2"
            self.downloadParams["UseCurrentWebPage"] = true
        } else {
            var pid: NSString? = nil
            let scanner = Scanner(string:show.url)
            scanner.scanUpTo("Filter=", into:nil)
            scanner.scanString("Filter=", into:nil)
            scanner.scanUpTo("kljkjj", into:&pid)
            
            guard let foundPid = pid else {
                print("ERROR: GiA cannot interpret the ITV URL: \(show.url)")
                add(toLog:"ERROR: GiA cannot interpret the ITV URL: \(show.url)")
                self.show.reasonForFailure = "MetadataProcessing"
                self.show.complete = true
                self.show.successful = false
                self.show.setValue("Download Failed", forKey:"status")
                NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
                return
            }
            
            self.show.realPID = foundPid as String
            soapBody = "Body"
        }
        
        var body = ""
        if let soapPath = Bundle.main.url(forResource: soapBody, withExtension: nil) {
            body = try! String(contentsOf:soapPath, encoding:.utf8)
        }
        
        body = body.replacingOccurrences(of: "!!!ID!!!", with: self.show.realPID)
        
        let requestURL = URL(string: "http://mercury.itv.com/PlaylistService.svc?wsdl")
        if self.verbose, let url = requestURL {
            let message = "DEBUG: Metadata URL: \(url)"
            print(message)
            add(toLog:message, noTag: true)
        }
        
        self.currentRequest.cancel()
        var downloadRequest = URLRequest(url:requestURL!)
        
        downloadRequest.addValue("http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2", forHTTPHeaderField:"Referer")
        downloadRequest.addValue("text/xml; charset=utf-8", forHTTPHeaderField:"Content-Type")
        downloadRequest.addValue("\"http://tempuri.org/PlaylistService/GetPlaylist\"", forHTTPHeaderField:"SOAPAction")
        downloadRequest.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField:"Accept")
        downloadRequest.httpMethod = "POST"
        downloadRequest.httpBody = body.data(using: .utf8)
        downloadRequest.timeoutInterval = 10
        self.session = URLSession.shared
        
        if let proxy = self.proxy {
            // Create an NSURLSessionConfiguration that uses the proxy
            var proxyDict: [String: Any] = [kCFProxyTypeKey as String : kCFProxyTypeHTTP as String,
                                            kCFNetworkProxiesHTTPEnable as String : 1,
                                            kCFStreamPropertyHTTPProxyHost as String : proxy.host,
                                            kCFStreamPropertyHTTPProxyPort as String : proxy.port
            ]
            
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
        
        guard let data = data, response.statusCode != 0 || response.statusCode == 200 else {
            var message: String = ""
            
            if response.statusCode == 0 {
                message = "ERROR: No response received (probably a proxy issue): \(error?.localizedDescription ?? "Unknown error")"
                self.show.reasonForFailure = "Internet_Connection"
                self.show.setValue("Failed: Bad Proxy", forKey:"status")
            } else {
                message = "ERROR: Could not retrieve programme metadata: \(error?.localizedDescription ?? "Unknown error")"
                self.show.setValue("Download Failed", forKey:"status")
            }
            
            self.show.successful = false
            self.show.complete = true
            print(message)
            add(toLog: message)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
            add(toLog:"Download Failed", noTag:false)
            return
        }
        
        let responseString = String(data:data, encoding:.utf8)
        let message = "DEBUG: Metadata response status code: \(response.statusCode)"
        print(message)
        
        if verbose {
            add(toLog: message, noTag: true)
            add(toLog:"DEBUG: Metadata response: \(responseString ?? "")", noTag:true)
        }

        var itvRateArray: [String] = []
        var bitrateArray: [String] = []
        
        let formatKeys = ["Flash - Very Low",
                          "Flash - Low",
                          "Flash - Standard",
                          "Flash - High",
                          "Flash - Very High",
                          "Flash - HD"]
        let itvRates = ["400",
                        "600",
                        "800",
                        "1200",
                        "1500",
                        "1800"]
        let bitrates = ["400000",
                        "600000",
                        "800000",
                        "1200000",
                        "1500000",
                        "1800000"]
        
        var itvRateDictionary = [String : String]()
        zip(formatKeys, itvRates).forEach { itvRateDictionary[$0.0] = $0.1 }
        
        var bitRateDictionary = [String : String]()
        zip(formatKeys, bitrates).forEach { bitRateDictionary[$0.0] = $0.1 }

        for format in self.formatList {
            if let mode = itvRateDictionary[format.format] {
                itvRateArray.append(mode)
            }
            if let mode = bitRateDictionary[format.format] {
                bitrateArray.append(mode)
            }
        }

        
        let checkForRealPID = downloadParams["UseCurrentWebPage"] as? Bool ?? false
        let metadataParseOperation = ITVMetadataParseOperation(data: data, checkForRealPID: checkForRealPID, verbose: verbose, itvRates: itvRateArray, bitRates: bitrateArray)
        metadataParseOperation.main()
        
        if metadataParseOperation.result.faultCode == "InvalidGeoRegion" {
            add(toLog:"ERROR: Access denied to users outside UK.")
            self.show.successful = false
            self.show.complete = true
            self.show.reasonForFailure = "Outside_UK"
            self.show.setValue("Failed: Outside UK", forKey:"status")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "DownloadFinished"), object:self.show)
            add(toLog:"Download Failed", noTag:false)
            return
        }

        guard let playPath = metadataParseOperation.result.playPath, let authURL = metadataParseOperation.result.authURL else {
            add(toLog:"ERROR: None of the modes in your download format list are available for this show. Try adding more modes if possible.")
            self.show.reasonForFailure = "NoSpecifiedFormatAvailableITV";
            self.show.complete = true;
            self.show.successful = false;
            self.show.setValue("Download Failed", forKey:"status")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "DownloadFinished"), object:self.show)
            return
        }

        logDebugMessage("DEBUG: playPath = \(playPath)", noTag: true)
        
        let result = metadataParseOperation.result
        self.show.seriesName = result.seriesName ?? "Unknown"
        self.show.episodeName = result.episodeTitle ?? ""

        add(toLog:"INFO: Metadata processed.", noTag:true)

            //Create Download Path
            self.createDownloadPath()
            
        var swfplayer = UserDefaults.standard.value(forKey: "\(self.defaultsPrefix)SWFURL") as? String
        if swfplayer == nil {
            swfplayer = "http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654"
        }
        
        DispatchQueue.main.async {
            var args: [String] = ["-r",
                        authURL,
                        "-W",
                        swfplayer!,
                        "-y",
                        playPath,
                        "-o",
                        self.downloadPath]
            if self.verbose {
                args.append("--verbose")
                self.logDebugMessage("DEBUG: RTMPDump args:\(args)", noTag: true)
            }
            self.launchRTMPDump(withArgs: args)
        }
    }

    // TODO: This URL no longer exists, so don't call it until we figure out how to get the description metadata.
//        guard let dataURL = URL(string: "http://www.itv.com/_app/Dynamic/CatchUpData.ashx?ViewType=5&Filter=\(self.show.realPID)") else {
//            self.show.reasonForFailure = "NoSpecifiedFormatAvailableITV";
//            self.show.complete = true;
//            self.show.successful = false;
//            self.show.setValue("Download Failed", forKey:"status")
//            NotificationCenter.default.post(name: Notification.Name(rawValue: "DownloadFinished"), object:self.show)
//            return
//        }
//        
//        logDebugMessage("DEBUG: Programme data URL: \(dataURL.absoluteString)", noTag: true)
//        self.currentRequest.cancel()
//        
//        var downloadRequest = URLRequest(url:dataURL)
//        downloadRequest.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField:"Accept")
//        downloadRequest.timeoutInterval = 10
//        DispatchQueue.main.async(execute: {
//            self.add(toLog:"INFO: Requesting programme data.", noTag:true)
//            self.currentRequest = self.session.dataTask(with: downloadRequest,
//                                                                   completionHandler: {
//                                                                    (data: Data?, response: URLResponse?, error: Error?) in
//                                                                    if let httpResponse = response as? HTTPURLResponse {
//                                                                        self.dataRequestFinished(httpResponse,
//                                                                                            data: data,
//                                                                                            error: error)
//                                                                    }
//            })
//            self.currentRequest.resume()
//        })
    
    
    
}
