//  GetITVListings.swift
//  ITVLoader
//
//  Created by Scott Kovatch on 3/16/18
//

import Foundation
import Kanna

extension Sequence where Iterator.Element: Hashable {
    func uniq() -> [Iterator.Element] {
        var seen = Set<Iterator.Element>()
        return filter { seen.update(with: $0) == nil }
    }
}

public class GetITVShows: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    var myQueueSize: Int = 0
    var myQueueLeft: Int = 0
    var mySession: URLSession?

    var broughtForwardProgrammeArray = [ProgrammeData]()
    var todayProgrammeArray = [ProgrammeData]()
    var carriedForwardProgrammeArray = [ProgrammeData]()
    var getITVShowRunning = false
    var forceUpdateAllProgrammes = false
    var timeIntervalSince1970UTC: TimeInterval = 0.0
    var intTimeThisRun: TimeInterval = 0
    var logger: LogController?
    var myOpQueue = OperationQueue()

    func supportPath(_ fileName: String) -> String
    {
        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.absoluteURL {
            let historyFile = applicationSupportURL.appendingPathComponent("Get iPlayer Automator").appendingPathComponent(fileName)
            return historyFile.path
        }
        
        return NSHomeDirectory().appending("/").appending(fileName)
    }
    
    var programmesFilePath: String {
        return supportPath("itvprogrammes.gia")
    }
    
//    var cachePath: String {
//        return supportPath(fileName: "itv")
//    }
//
    private(set) var isCreateTodayProgrammeArray = false
    
    public override init() {
        super.init()
        forceUpdateAllProgrammes = false
        getITVShowRunning = false
    }
    
    @objc public func forceITVUpdate(logger: LogController) {
        self.logger = logger
        logger.add(toLog: "GetITVShows: Force all programmes update ")
        forceUpdateAllProgrammes = true
        itvUpdate(newLogger: logger)
    }
    
    @objc public func itvUpdate(newLogger: LogController) {
        /* cant run if we are already running */
        if getITVShowRunning == true {
            return
        }
        logger = newLogger
        logger?.add(toLog: "GetITVShows: ITV Cache Update Starting ")
        getITVShowRunning = true
        myQueueSize = 0

        /* Create the NUSRLSession */
        let defaultConfigObject = URLSessionConfiguration.default
        let cachePath: String = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("/itvloader.cache").absoluteString
        let myCache = URLCache(memoryCapacity: 16384, diskCapacity: 268435456, diskPath: cachePath)
        defaultConfigObject.urlCache = myCache
        defaultConfigObject.requestCachePolicy = .useProtocolCachePolicy
        mySession = URLSession(configuration: defaultConfigObject, delegate: self, delegateQueue: OperationQueue.main)
 
        /* Load in carried forward programmes & programme History*/
        if !forceUpdateAllProgrammes {
            NSKeyedUnarchiver.setClass(ProgrammeData.self, forClassName: "ProgrammeData")

            if let currentPrograms = NSKeyedUnarchiver.unarchiveObject(withFile: programmesFilePath) as? [ProgrammeData] {
                broughtForwardProgrammeArray = currentPrograms
            }
        }

        if broughtForwardProgrammeArray.count == 0 || forceUpdateAllProgrammes {
            let emptyProgramme = ProgrammeData(name: "program to be deleted", pid: "PID", url: "URL", numberEpisodes: 0, timeDateLastAired: 0)
            broughtForwardProgrammeArray.append(emptyProgramme)
        }

        /* Create empty carriedForwardProgrammeArray & history array */

        /* establish time added for any new programmes we find today */
        var timeAdded: TimeInterval = Date().timeIntervalSince1970
        timeAdded += TimeInterval(NSTimeZone.system.secondsFromGMT(for: Date()))
        intTimeThisRun = timeAdded
        /* Load in todays shows for itv.com */
        
        myOpQueue.maxConcurrentOperationCount = 1
        myOpQueue.addOperation {
            self.requestTodayListing()
        }
    }
    
    func requestTodayListing() {
        if let aString = URL(string: "https://www.itv.com/hub/shows") {
            mySession?.dataTask(with: aString, completionHandler: {(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void in
                guard let data = data else {
                    return
                }
                
                let htmlData = String(data: data, encoding: .utf8)
                
                if !self.createTodayProgrammeArray(from: htmlData) {
                    self.endOfRun()
                } else {
                    self.mergeAllProgrammes()
                }
            }).resume()
        }
    }
    
    func requestProgrammeEpisodes(_ myProgramme: ProgrammeData?) {
        /* Get all episodes for the programme name identified in MyProgramme */
        usleep(1)
        if let aURL = myProgramme?.programmeURL, let aURL1 = URL(string: aURL) {
            mySession?.dataTask(with: aURL1, completionHandler: {(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void in
                if let error = error {
                    let errorMessage = "GetITVListings (Error(\(error))): Unable to retreive programme episodes for \(myProgramme?.programmeURL ?? "missing!")"
                    self.logger?.add(toLog: errorMessage)
//                    NSAlert(messageText: "GetITVShows: Unable to retreive programme episode data", defaultButton: "OK", alternateButton: nil, otherButton: nil, informativeTextWithFormat: "If problem persists, please submit a bug report and include the log file.").runModal()
                } else if let data = data {
                    let myHtmlData = String(data: data, encoding: .utf8)
                    self.processProgrammeEpisodesData(myProgramme, myHtmlData: myHtmlData)
                }
            }).resume()
        }
        return
    }
    
    func processProgrammeEpisodesData(_ aProgramme: ProgrammeData?, myHtmlData: String?) {
        /*  Scan through episode page and create carried forward programme entries for each eipsode of aProgramme */
        let scanner = Scanner(string: myHtmlData ?? "")
        var fullProgrammeScanner: Scanner?
        var programmeURL: String? = nil
        var fullProgramme: String? = nil
        var searchPath: String? = nil
        let basePath = "<a href=\"https://www.itv.com/hub/"
        var numberEpisodesFound: Int = 0
        var temp: NSString? = nil
        
        /* Scan to start of episodes data  - first re-hyphonate the programe name */
        scanner.scanUpTo("data-episode-current", into: nil)
        
        if let aString = aProgramme?.programmeName?.replacingOccurrences(of: " ", with: "-") {
            searchPath = basePath.appending(aString)
        }
        
        if let aPath = searchPath {
            searchPath = aPath.appending("/")
        }
        
        /* Get first episode  */
        if let aPath = searchPath {
            scanner.scanUpTo(aPath, into: nil)
        }
        
        fullProgramme = scanner.scanUpToString("</a>")
        
        while !scanner.isAtEnd {
            if let aProgramme = fullProgramme {
                fullProgrammeScanner = Scanner(string: aProgramme)
            }
            numberEpisodesFound += 1
            /* URL */
            fullProgrammeScanner?.scanUpTo("<a href=\"", into: &temp)
            fullProgrammeScanner?.scanString("<a href=\"", into: &temp)
            programmeURL = fullProgrammeScanner?.scanUpToString("\"")
            
            // Fetch this URL to get the show data.
//            myOpQueue.addOperation {
                if let aURL = programmeURL, let aURL1 = URL(string: aURL) {
                    self.mySession?.dataTask(with: aURL1, completionHandler: {(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void in

                        guard let data = data, let programHTML = String(data: data, encoding: .utf8) else {
                            return
                        }

                        var productionID: String? = nil
                        var seriesNumber: Int = 0
                        var episodeNumber: Int = 0
                        var dateLastAired: String? = nil
                        var timeDateLastAired: TimeInterval = 0
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm'Z'"
                        dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0) as TimeZone
                        let scanner = Scanner(string: programHTML)
                        /* Production ID */
                        scanner.scanUpToString("data-video-production-id=\"")
                        scanner.scanString("data-video-production-id=\"")
                        productionID = scanner.scanUpToString("\"")
                        /* Series (if available) */
                        let scanPoint: Int? = fullProgrammeScanner?.scanLocation

                        scanner.scanUpToString("Series")
                        if !scanner.isAtEnd {
                            scanner.scanString("Series")
                            seriesNumber = scanner.scanInteger() ?? 0
                        }
                        episodeNumber = 0
                        if let aPoint = scanPoint {
                            scanner.scanLocation = aPoint
                        }
                        scanner.scanUpToString("Episode")
                        if !scanner.isAtEnd {
                            scanner.scanString("Episode")
                            episodeNumber = scanner.scanInteger() ?? 0
                        }
                        /* get date aired so that we can quickPurge last episode in mergeAllEpisodes */
                        dateLastAired = ""
                        if let aPoint = scanPoint {
                            scanner.scanLocation = aPoint
                        }
                        scanner.scanUpToString("datetime=\"")
                        if !scanner.isAtEnd {
                            scanner.scanString("datetime=\"")
                            dateLastAired = scanner.scanUpToString("\"")
                            if let aAired = dateLastAired, let aSince1970 = (dateFormatter.date(from: aAired)?.timeIntervalSince1970) {
                                timeDateLastAired = aSince1970
                            }
                        }
                        /* Create ProgrammeData Object and store in array */
                        let myProgramme = ProgrammeData(name: aProgramme?.programmeName ?? "", pid: productionID ?? "", url: programmeURL ?? "", numberEpisodes: numberEpisodesFound, timeDateLastAired: timeDateLastAired)
                        
                        myProgramme.addProgrammeSeriesInfo(seriesNumber, aEpisodeNumber: episodeNumber)
                        
                        if numberEpisodesFound == 1 {
                            myProgramme.isNew = true
                        }
                        
                        self.carriedForwardProgrammeArray.append(myProgramme)
                        
                        /* if we couldnt find dateAired then mark first programme for forced cache update - hopefully this will repair issue on next run */
                        if myProgramme.timeDateLastAired == 0 {
                            let index = self.carriedForwardProgrammeArray.count - numberEpisodesFound
                            self.carriedForwardProgrammeArray[index].forceCacheUpdate = true
                            let programName = aProgramme?.programmeName ?? ""
                            self.logger?.add(toLog: "GetITVListings: WARNING: Date aired not found for \(programName)")
                        }
                    }).resume()
                }
//          }
            /* Scan for next programme */
            if let aPath = searchPath {
                scanner.scanUpTo(aPath, into: nil)
            }
           
            fullProgramme = scanner.scanUpToString("</a>")
        }
        /* Quick sanity check - did we find the number of episodes that we expected */
        if numberEpisodesFound != aProgramme?.numberEpisodes {
            /* if not - mark first entry as requireing a full update on next run - hopefully this will repair the issue */
            if numberEpisodesFound > 0 {
                carriedForwardProgrammeArray[carriedForwardProgrammeArray.count - numberEpisodesFound].forceCacheUpdate = true
            }
            let programURL = aProgramme?.programmeURL ?? "(blank)"
            self.logger?.add(toLog: "GetITVListings (Warning): Processing Error \(programURL) - episodes expected/found \(aProgramme?.numberEpisodes ?? 0))/\(numberEpisodesFound)")
        }
        /* Check if there is any outstanding work before processing the carried forward programme list */
        myQueueLeft -= 1
        let increment = Double(myQueueSize > 0 ? 100 / myQueueSize : 100)
        AppController.shared().itvProgressIndicator.increment(by: increment)

        if (myQueueLeft == 0) {
            processCarriedForwardProgrammes()
        }
    }
    
    func processCarriedForwardProgrammes() {
        /* First we add or update datetimeadded for the carried forward programmes */
        broughtForwardProgrammeArray.sort {$0.productionId ?? "" < $1.productionId ?? ""}
        
        for cfProgram: ProgrammeData in carriedForwardProgrammeArray {
            if let foundProgram = broughtForwardProgrammeArray.first(where: { $0.productionId == cfProgram.productionId }) {
                cfProgram.timeAdded = foundProgram.timeAdded ?? intTimeThisRun
            }
        }

        /* Now we sort the programmes & write CF to disk */
        carriedForwardProgrammeArray.sort {
            if $0.programmeName == $1.programmeName {
                if $0.isNew == $1.isNew {
                    return $0.timeDateLastAired ?? 0 < $1.timeDateLastAired ?? 0
                } else {
                    return $0.isNew && !$1.isNew
                }
            } else {
                return $0.programmeName ?? "" < $1.programmeName ?? ""
            }
        }
        NSKeyedArchiver.archiveRootObject(carriedForwardProgrammeArray, toFile: programmesFilePath)

        /* Now create the cache file that used to be created by get_iplayer */
        var cacheFileContentString = "#index|type|name|pid|available|expires|episode|seriesnum|episodenum|versions|duration|desc|channel|categories|thumbnail|timeadded|guidance|web\n"
        var cacheIndexNumber: Int = 100000
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        var episodeString: String? = nil
        let dateFormatter1 = DateFormatter()
        dateFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        var dateAiredString: String? = nil
        var dateAiredUTC: Date?
        for carriedForwardProgramme: ProgrammeData in carriedForwardProgrammeArray {
            if let dateLastAired = carriedForwardProgramme.timeDateLastAired {
                dateAiredUTC = Date(timeIntervalSince1970: dateLastAired)
                if let aUTC = dateAiredUTC {
                    episodeString = dateFormatter.string(from: aUTC)
                }
                if let aUTC = dateAiredUTC {
                    dateAiredString = dateFormatter1.string(from: aUTC)
                }
            }
            else {
                episodeString = ""
                dateAiredUTC = Date()
                if let aUTC = dateAiredUTC {
                    dateAiredString = dateFormatter1.string(from: aUTC)
                }
            }
            cacheFileContentString += String(format: "%06d|", cacheIndexNumber)
            cacheIndexNumber += 1
            cacheFileContentString += "itv|"
            cacheFileContentString += carriedForwardProgramme.programmeName ?? ""
            cacheFileContentString += "|"
            cacheFileContentString += carriedForwardProgramme.productionId ?? ""
            cacheFileContentString += "|"
            if let aString = dateAiredString {
                cacheFileContentString += aString
            }
            cacheFileContentString += "||"
            if let aString = episodeString {
                cacheFileContentString += aString
            }
            cacheFileContentString += "|||default|||ITV Player|TV||"
            cacheFileContentString += "\(carriedForwardProgramme.timeAdded ?? 0))||"
            cacheFileContentString += carriedForwardProgramme.programmeURL
            cacheFileContentString += "|\n"
        }
        
        if let cacheData = cacheFileContentString.data(using: .utf8) {
            let cacheFilePath = supportPath("itv.cache")
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: cacheFilePath) {
                if !fileManager.createFile(atPath: cacheFilePath, contents: cacheData, attributes: nil) {
                    let alert = NSAlert()
                    alert.messageText = "GetITVShows: Could not create cache file!"
                    alert.informativeText = "Please submit a bug report saying that the history file could not be created."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
            else {
                if let file = FileHandle(forWritingAtPath: cacheFilePath) {
                    file.write(cacheData)
                    file.closeFile()
                } else {
                    let alert = NSAlert()
                    alert.messageText = "GetITVShows: Could not write to history file!"
                    alert.informativeText = "Please submit a bug report saying that the history file could not be written to."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
        endOfRun()
    }
    
    func endOfRun() {
        /* Notify finish and invaliate the NSURLSession */
        getITVShowRunning = false
        mySession?.finishTasksAndInvalidate()
        if forceUpdateAllProgrammes {
            NotificationCenter.default.post(name: NSNotification.Name("ForceITVUpdateFinished"), object: nil)
        }
        else {
            NotificationCenter.default.post(name: NSNotification.Name("ITVUpdateFinished"), object: nil)
        }
        forceUpdateAllProgrammes = false
        self.logger?.add(toLog: "GetITVShows: Update Finished")
    }
    
    func mergeAllProgrammes() {
        var bfIndex: Int = 0
        var todayIndex: Int = 0
        var bfProgramme: ProgrammeData = broughtForwardProgrammeArray[bfIndex]
        var todayProgramme: ProgrammeData = todayProgrammeArray[todayIndex]
        var bfProgrammeName: String = ""
        var todayProgrammeName: String = ""
        repeat {
            if bfIndex < broughtForwardProgrammeArray.count {
                bfProgramme = broughtForwardProgrammeArray[bfIndex]
                if let aName = bfProgramme.programmeName {
                    bfProgrammeName = aName
                }
            }
            else {
                bfProgrammeName = "~~~~~~~~~~"
            }
            if todayIndex < todayProgrammeArray.count {
                todayProgramme = todayProgrammeArray[todayIndex]
                if let aName = todayProgramme.programmeName {
                    todayProgrammeName = aName
                }
            }
            else {
                todayProgrammeName = "~~~~~~~~~~"
            }
            let result: ComparisonResult = bfProgrammeName.compare(todayProgrammeName)
            switch result {
            case .orderedDescending:
                /* Now get all episodes & add carriedForwardProgrammeArray - note if only 1 episode then just copy todays programme */
                if todayProgramme.numberEpisodes == 1 {
                    todayProgramme.isNew = true
                    carriedForwardProgrammeArray.append(todayProgramme)
                }
                else {
                    myQueueSize += 1
                    myOpQueue.addOperation {
                        self.requestProgrammeEpisodes(todayProgramme)
                    }
                }
                todayIndex += 1
            case .orderedSame:
                /* for programmes that have more then one current episode and cache update is forced or current episode has changed or new episodes have been found; get full episode listing */
                if todayProgramme.numberEpisodes > 1 && bfProgramme.forceCacheUpdate || todayProgramme.productionId != bfProgramme.productionId || todayProgramme.numberEpisodes > bfProgramme.numberEpisodes {
                    if bfProgramme.forceCacheUpdate {
                        self.logger?.add(toLog: "GetITVListings (Warning): Cache upate forced for: \(bfProgramme.programmeName ?? "<blank>")")
                    }
                    myQueueSize += 1
                    myOpQueue.addOperation {
                        self.requestProgrammeEpisodes(todayProgramme)
                    }
                    /* Now skip remaining BF episodes */
                    bfIndex += 1
                    while (bfIndex < broughtForwardProgrammeArray.count && (todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName)) {
                        bfIndex += 1
                    }
                }
                else if todayProgramme.numberEpisodes == 1 {
                    /* For programmes with only 1 episode found just copy it from today to CF */
                    todayProgramme.isNew = true
                    carriedForwardProgrammeArray.append(todayProgramme)
                    /* Now skip remaining BF episodes (if any) */
                    bfIndex += 1
                    while (bfIndex < broughtForwardProgrammeArray.count && (todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName)) {
                        bfIndex += 1
                    }
                }
                else if todayProgramme.productionId == bfProgramme.productionId && todayProgramme.numberEpisodes == bfProgramme.numberEpisodes {
                    /* For programmes where the current episode and number of episodes has not changed so just copy BF to CF  */
                    repeat {
                        carriedForwardProgrammeArray.append(broughtForwardProgrammeArray[bfIndex])
                        bfIndex += 1
                    } while bfIndex < broughtForwardProgrammeArray.count && (todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName)
                }
                else if todayProgramme.numberEpisodes < bfProgramme.numberEpisodes {
                    /* For programmes where the current episode has changed but fewer episodes found today; copy available episodes & drop the remainder */
                    var i = todayProgramme.numberEpisodes
                    while i > 0 {
                        let pd: ProgrammeData = broughtForwardProgrammeArray[bfIndex]
                        pd.numberEpisodes = todayProgramme.numberEpisodes
                        carriedForwardProgrammeArray.append(pd)
                        i -= 1
                        bfIndex += 1
                    }
                    /* and drop the rest */
                    
                    while (bfIndex < broughtForwardProgrammeArray.count && (todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName)) {
                        bfIndex += 1
                    }
                }
                else {
                    /* Should never get here fo full reload & skip all episodes for this programme */
                    self.logger?.add(toLog: "GetITVListings (Error): Failed to correctly process \(todayProgramme) will issue a full refresh")
                    myQueueSize += 1
                    myOpQueue.addOperation {
                        self.requestProgrammeEpisodes(todayProgramme)
                    }
                    bfIndex += 1
                    while bfIndex < broughtForwardProgrammeArray.count && todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName {
                        bfIndex += 1
                    }
                }
                todayIndex += 1
            case .orderedAscending:
                /*  BF not found; Skip all episdoes on BF as programme no longer available */
                bfIndex += 1
                while bfIndex < broughtForwardProgrammeArray.count && bfProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName {
                    bfIndex += 1
                }
            }
        } while bfIndex < broughtForwardProgrammeArray.count || todayIndex < todayProgrammeArray.count
        self.logger?.add(toLog: "GetITVShows (Info): Merge complete B/F Programmes: \(broughtForwardProgrammeArray.count) C/F Programmes: \(carriedForwardProgrammeArray.count) Today Programmes: \(todayProgrammeArray.count) ")
        myQueueLeft = myQueueSize
        if myQueueSize < 2 {
            AppController.shared()?.itvProgressIndicator.increment(by: 100.0)
        }
        if myQueueSize == 0 {
            processCarriedForwardProgrammes()
        }
    }
    
    func createTodayProgrammeArray(from htmlData: String?) -> Bool {
        /* Scan itv.com/shows to create full listing of programmes (not episodes) that are available today */
        todayProgrammeArray.removeAll()
        
        let scanner = Scanner(string: htmlData ?? "")
        var programmeName:String? = nil
        var programmeURL: String? = nil
        var productionId: String? = nil
        var token: String? = nil
        var fullProgramme: String = ""
        var scanPoint: Int = 0
        var numberEpisodes: Int = 0
        /* Get first programme  */
        scanner.scanUpTo("<a href=\"https://www.itv.com/hub/", into: nil)
        fullProgramme = scanner.scanUpToString("</a>") ?? ""
        while !scanner.isAtEnd {
            let fullProgrammeScanner = Scanner(string: fullProgramme)
            scanPoint = fullProgrammeScanner.scanLocation
            /* URL */
            fullProgrammeScanner.scanString("<a href=\"", into: nil)
            programmeURL = fullProgrammeScanner.scanUpToString("\"")
            /* Programme Name */
            fullProgrammeScanner.scanLocation = scanPoint
            fullProgrammeScanner.scanString("<a href=\"https://www.itv.com/hub/", into: nil)
            programmeName = fullProgrammeScanner.scanUpToString("/")
            /* Production ID */
            fullProgrammeScanner.scanUpTo("/", into: nil)
            fullProgrammeScanner.scanString("/", into: nil)
            token = fullProgrammeScanner.scanUpToString("\"")
            productionId = token?.removingPercentEncoding
            /* Get mumber of episodes, assume 1 if you cant figure it out */
            numberEpisodes = 1
            fullProgrammeScanner.scanUpToString("<p class=\"tout__meta theme__meta\">")
            if !fullProgrammeScanner.isAtEnd {
                fullProgrammeScanner.scanString("<p class=\"tout__meta theme__meta\">")
                scanPoint = fullProgrammeScanner.scanLocation
                fullProgrammeScanner.scanUpToString("episode")
                if !fullProgrammeScanner.isAtEnd {
                    fullProgrammeScanner.scanLocation = scanPoint
                    numberEpisodes = fullProgrammeScanner.scanInteger() ?? 0
                }
            }
            /* Create ProgrammeData Object and store in array */
            let myProgramme = ProgrammeData(name: programmeName ?? "<None>", pid: productionId ?? "", url: programmeURL ?? "", numberEpisodes: numberEpisodes, timeDateLastAired: timeIntervalSince1970UTC)
            todayProgrammeArray.append(myProgramme)
            /* Scan for next programme */
            scanner.scanUpTo("<a href=\"https://www.itv.com/hub/", into: nil)
            fullProgramme = scanner.scanUpToString("</a>") ?? ""
        }
        
        /* Now we sort the programmes and the drop duplicates */
        if todayProgrammeArray.count == 0 {
            self.logger?.add(toLog: "No programmes found on www.itv.com/hub/shows")
            let alert = NSAlert()
            alert.messageText = "No programmes were found on www.itv.com/hub/shows"
            alert.informativeText = "Try again later. If the problem persists please file a bug."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }

        todayProgrammeArray.sort { $0.programmeName ?? "" < $1.programmeName ?? "" }
        todayProgrammeArray = todayProgrammeArray.uniq()
        return true
    }
}



