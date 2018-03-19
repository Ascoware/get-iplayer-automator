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
    let currentTime = Date()
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
        return supportPath("itvprograms.gia")
    }
    
    //    var cachePath: String {
    //        return supportPath(fileName: "itv")
    //    }
    //
    
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
        let cachePath: String = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("/itvloader.cache").path
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
        
//        if broughtForwardProgrammeArray.count == 0 || forceUpdateAllProgrammes {
//            let emptyProgramme = ProgrammeData(name: "program to be deleted", pid: "PID", url: "URL", numberEpisodes: 0, timeDateLastAired: Date())
//            broughtForwardProgrammeArray.append(emptyProgramme)
//        }
        
        /* Create empty carriedForwardProgrammeArray & history array */
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
                
                if !self.createTodayProgrammeArray(data: data) {
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
                    self.processProgrammeEpisodesData(myProgramme, pageData: data)
                }
            }).resume()
        }
        return
    }
    
    func processProgrammeEpisodesData(_ aProgramme: ProgrammeData?, pageData: Data) {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT:0)

        if let showPageHTML = try? HTML(html: pageData, encoding: .utf8) {
            let showElements = showPageHTML.xpath("//a[@data-content-type='episode']")

            for show in showElements {
                var dateAiredUTC: Date? = nil
                let dateTimeString = show.at_xpath(".//@datetime")?.text
                
                if let dateTimeString = dateTimeString{
                    dateAiredUTC = dateFormatter.date(from: dateTimeString)
                }

                let description = show.at_xpath(".//p[@class='tout__summary theme__subtle']")?.content
                
                var episodeNumber: Int? = 0
                if let episode = show.at_xpath(".//h3[@class='tout__title complex-link__target theme__target ']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let episodeScanner = Scanner(string: episode)
                    episodeScanner.scanString("Episode ")
                    episodeNumber = episodeScanner.scanInteger()
                }
                
                var seriesNumber: Int? = 0
                if let series = show.at_xpath(".//h2[@class='module__heading']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let seriesScanner = Scanner(string: series)
                    seriesScanner.scanString("Series ")
                    seriesNumber = seriesScanner.scanInteger()
                }

                var productionID: String? = ""
                var showURL: URL? = nil
                if let showURLString = show.at_xpath("@href")?.text {
                    showURL = URL(string: showURLString)
                    productionID = showURL?.lastPathComponent
                }
                
//                print("Program: \(aProgramme?.programmeName ?? "")")
//                print("Show URL: \(showURL?.absoluteString ?? "")")
//                print("Episode number: \(episodeNumber ?? 0)")
//                print("Series number: \(seriesNumber ?? 0)")
//                print("productionID: \(productionID ?? "")")
//                print("Date aired: \(dateTimeString ?? "Unknown")")
//                print("=================")

                /* Create ProgrammeData Object and store in array */
                let myProgramme = ProgrammeData(name: aProgramme?.programmeName ?? "", pid: productionID ?? "", url: showURL?.absoluteString ?? "", numberEpisodes: aProgramme?.numberEpisodes ?? 0, timeDateLastAired: dateAiredUTC, programDescription: description ?? "", thumbnailURL: "")

                myProgramme.addProgrammeSeriesInfo(seriesNumber ?? 0, aEpisodeNumber: episodeNumber ?? 0)
                
//                if showElements.count == 1 {
//                    myProgramme.isNew = true
//                }
//
                self.carriedForwardProgrammeArray.append(myProgramme)
            }
    
        }
        
        let increment = Double(myQueueSize - 1) > 0 ? 100.0 / Double(myQueueSize - 1) : 100.0
        AppController.shared().itvProgressIndicator.increment(by: increment)

        /* Check if there is any outstanding work before processing the carried forward programme list */
        myQueueLeft -= 1
        if (myQueueLeft == 0) {
            processCarriedForwardProgrammes()
        }
    }
    
    func processCarriedForwardProgrammes() {
        /* First we add or update datetimeadded for the carried forward programmes */
        broughtForwardProgrammeArray.sort {$0.productionId < $1.productionId}
        
        for cfProgram: ProgrammeData in carriedForwardProgrammeArray {
            if let foundProgram = broughtForwardProgrammeArray.first(where: { $0.productionId == cfProgram.productionId }) {
                cfProgram.timeAdded = foundProgram.timeAdded ?? currentTime
            }
        }
        
        /* Now we sort the programmes & write CF to disk */
        carriedForwardProgrammeArray.sort {
            if $0.programmeName == $1.programmeName {
                if let date0 = $0.timeDateLastAired, let date1 = $1.timeDateLastAired {
                    return date0.compare(date1) == .orderedAscending
                } else {
                    return $0.timeDateLastAired != nil
                }
            } else {
                return $0.programmeName < $1.programmeName
            }
        }
        NSKeyedArchiver.archiveRootObject(carriedForwardProgrammeArray, toFile: programmesFilePath)
        
        /* Now create the cache file that used to be created by get_iplayer */
        var cacheFileContentString = "#index|type|name|pid|available|expires|episode|seriesnum|episodenum|versions|duration|desc|channel|categories|thumbnail|timeadded|guidance|web\n"
        var cacheIndexNumber: Int = 100000
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        var episodeString: String? = nil
        var dateAddedString: String? = nil
        let dateFormatter1 = DateFormatter()
        dateFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        var dateAiredString: String? = nil
        for carriedForwardProgramme: ProgrammeData in carriedForwardProgrammeArray {
            if let timeDateLastAired = carriedForwardProgramme.timeDateLastAired {
                episodeString = dateFormatter.string(from: timeDateLastAired)
                dateAiredString = dateFormatter1.string(from: timeDateLastAired)
            } else {
                episodeString = ""
                dateAiredString = dateFormatter1.string(from: Date())
            }
            
            if let timeAdded = carriedForwardProgramme.timeAdded {
                dateAddedString = dateFormatter1.string(from: timeAdded)
            } else {
                dateAddedString = dateFormatter1.string(from: Date())
            }
            
            
            cacheFileContentString += String(format: "%06d|", cacheIndexNumber)
            cacheIndexNumber += 1
            cacheFileContentString += "itv|"
            cacheFileContentString += carriedForwardProgramme.programmeName
            cacheFileContentString += "|"
            cacheFileContentString += carriedForwardProgramme.productionId
            cacheFileContentString += "|"
            if let aString = dateAiredString {
                cacheFileContentString += aString
            }
            cacheFileContentString += "||"
            if let aString = episodeString {
                cacheFileContentString += aString
            }
            cacheFileContentString += "|||default|||ITV Hub|||"
            cacheFileContentString += "\(dateAddedString ?? "")||"
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
        let broughtForwardCount = broughtForwardProgrammeArray.count
        let todayCount = todayProgrammeArray.count
        while bfIndex < broughtForwardCount || todayIndex < todayCount {
            let bfProgramme: ProgrammeData? = bfIndex < broughtForwardCount ? broughtForwardProgrammeArray[bfIndex] : nil
            let todayProgramme: ProgrammeData? = todayIndex < todayCount ? todayProgrammeArray[todayIndex] : nil
            let bfProgrammeName = bfProgramme?.programmeName ?? "~~~~~~~~~~~~~~~~"
            let todayProgrammeName = todayProgramme?.programmeName ?? "~~~~~~~~~~~~~~~~"

            let result: ComparisonResult = bfProgrammeName.compare(todayProgrammeName)
            
            switch result {
            case .orderedDescending:
                myQueueSize += 1
                myOpQueue.addOperation {
                    self.requestProgrammeEpisodes(todayProgramme)
                }

                todayIndex += 1
            case .orderedSame:
                /* for programmes that have more then one current episode and cache update is forced or current episode has changed or new episodes have been found; get full episode listing */
                guard let todayProgramme = todayProgramme, let bfProgramme = bfProgramme else {
                    continue  //// !!!!!!!!
                }
                if todayProgramme.productionId != bfProgramme.productionId || todayProgramme.numberEpisodes > bfProgramme.numberEpisodes {
                    if bfProgramme.forceCacheUpdate {
                        self.logger?.add(toLog: "GetITVListings (Warning): Cache upate forced for: \(bfProgramme.programmeName)")
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
//                }
//                else if todayProgramme.numberEpisodes == 1 {
//                    /* For programmes with only 1 episode found just copy it from today to CF */
//                    todayProgramme.isNew = true
//                    carriedForwardProgrammeArray.append(todayProgramme)
//                    /* Now skip remaining BF episodes (if any) */
//                    bfIndex += 1
//                    while (bfIndex < broughtForwardProgrammeArray.count && (todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName)) {
//                        bfIndex += 1
//                    }
                } else if todayProgramme.productionId == bfProgramme.productionId && todayProgramme.numberEpisodes == bfProgramme.numberEpisodes {
                    /* For programmes where the current episode and number of episodes has not changed so just copy BF to CF  */
                    repeat {
                        carriedForwardProgrammeArray.append(broughtForwardProgrammeArray[bfIndex])
                        bfIndex += 1
                    } while bfIndex < broughtForwardProgrammeArray.count && (todayProgramme.programmeName == broughtForwardProgrammeArray[bfIndex].programmeName)
                } else if todayProgramme.numberEpisodes < bfProgramme.numberEpisodes {
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
                } else {
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
                while bfIndex < broughtForwardProgrammeArray.count && bfProgrammeName == broughtForwardProgrammeArray[bfIndex].programmeName {
                    bfIndex += 1
                }
            }
        }
        
        self.logger?.add(toLog: "GetITVShows (Info): Merge complete B/F Programmes: \(broughtForwardProgrammeArray.count) C/F Programmes: \(carriedForwardProgrammeArray.count) Today Programmes: \(todayProgrammeArray.count) ")
        
        myQueueLeft = myQueueSize
        
        if myQueueSize < 2 {
            AppController.shared()?.itvProgressIndicator.increment(by: 100.0)
        }
        
        if myQueueSize == 0 {
            processCarriedForwardProgrammes()
        }
    }
    
    func createTodayProgrammeArray(data: Data) -> Bool {
        /* Scan itv.com/shows to create full listing of programmes (not episodes) that are available today */
        todayProgrammeArray.removeAll()
        
        if let showsPage = try? HTML(html: data, encoding: .utf8) {
            let shows = showsPage.xpath("//a[@class='complex-link']")
            
            for show in shows {
                guard let showPage = show.at_xpath("@href")?.text,
                    let showPageURL = URL(string: showPage) else {
                    continue
                }
                
                let showName: String?
                let numberEpisodes: Int
                let productionID: String?
                let showPageURLString: String?

                showPageURLString = showPage
                productionID = showPageURL.lastPathComponent

                showName = show.at_xpath(".//h3[@class='tout__title complex-link__target theme__target']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let numberEpisodesString = show.at_xpath(".//p[@class='tout__meta theme__meta']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let scanner = Scanner(string: numberEpisodesString)
                    numberEpisodes = scanner.scanInteger() ?? 0
                } else {
                    numberEpisodes = 0
                }

                /* Create ProgrammeData Object and store in array */
//                print("Show name: \(showName ?? "")")
//                print("Prod ID: \(productionID ?? "")")
//                print("Show URL: \(showPageURLString ?? "")")
//                print("Number Episodes: \(numberEpisodes)")
//                print("=================")
                
                if numberEpisodes > 0 {
                    let myProgramme = ProgrammeData(name: showName ?? "<None>", pid: productionID ?? "", url: showPageURLString ?? "", numberEpisodes: numberEpisodes, timeDateLastAired: currentTime, programDescription:"", thumbnailURL: "")
                    todayProgrammeArray.append(myProgramme)
                }
            }
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
        
        todayProgrammeArray.sort { $0.programmeName < $1.programmeName }
        todayProgrammeArray = todayProgrammeArray.uniq()
        return true
    }
}



