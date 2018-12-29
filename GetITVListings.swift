//  GetITVListings.swift
//  ITVLoader
//
//  Created by Scott Kovatch on 3/16/18
//

import Foundation
import Kanna

public class GetITVShows: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    var myQueueSize: Int = 0
    var myQueueLeft: Int = 0
    var mySession: URLSession?
    
    var programmes = [ProgrammeData]()
    var episodes = [ProgrammeData]()
    var getITVShowRunning = false
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
    
    public override init() {
        super.init()
        getITVShowRunning = false
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
        defaultConfigObject.timeoutIntervalForResource = 30
        defaultConfigObject.timeoutIntervalForRequest = 30
        mySession = URLSession(configuration: defaultConfigObject, delegate: self, delegateQueue: OperationQueue.main)
        
        /* Load in all shows for itv.com */
        myOpQueue.maxConcurrentOperationCount = 1
        myOpQueue.addOperation {
            self.requestShowListing()
        }
    }
    
    func requestShowListing() {
        if let aString = URL(string: "https://www.itv.com/hub/shows") {
            mySession?.dataTask(with: aString, completionHandler: {(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void in
                if let error = error {
                    let errorMessage = "GetITVListings (Error(\(error))): Unable to retreive show listings from ITV"
                    self.logger?.add(toLog: errorMessage)
                }
                guard let data = data else {
                    return
                }
                
                if !self.createProgrammes(data: data) {
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
        
        var programURL: URL? = nil
        if let programURLString = aProgramme?.programmeURL {
            programURL = URL(string: programURLString)?.deletingLastPathComponent()
        }
            
        if let showPageHTML = try? HTML(html: pageData, encoding: .utf8) {
            let showElements = showPageHTML.xpath("//a[@data-content-type='episode']")

            for show in showElements {
                var dateAiredUTC: Date? = nil
                let dateTimeString = show.at_xpath(".//@datetime")?.text
                
                if let dateTimeString = dateTimeString{
                    dateAiredUTC = dateFormatter.date(from: dateTimeString)
                }

                let description = show.at_xpath(".//p[@class='tout__summary theme__subtle']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines)
                
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
                
                // Make sure the URL matches the show listing -- ITV likes to sneak other shows on a program page.
                if let showURLBase = showURL?.deletingLastPathComponent(), showURLBase.absoluteString == programURL?.absoluteString {
                    
                    /* Create ProgrammeData Object and store in array */
                    let myProgramme = ProgrammeData(name: aProgramme?.programmeName ?? "", pid: productionID ?? "", url: showURL?.absoluteString ?? "", numberEpisodes: aProgramme?.numberEpisodes ?? 0, timeDateLastAired: dateAiredUTC, programDescription: description ?? "", thumbnailURL: "")
                    
                    myProgramme.addProgrammeSeriesInfo(seriesNumber ?? 0, aEpisodeNumber: episodeNumber ?? 0)
                    self.episodes.append(myProgramme)
                }
            }
        }
        
        let increment = Double(myQueueSize - 1) > 0 ? 100.0 / Double(myQueueSize - 1) : 100.0
        AppController.shared().itvProgressIndicator.increment(by: increment)

        /* Check if there is any outstanding work before processing the carried forward programme list */
        myQueueLeft -= 1
        if (myQueueLeft == 0) {
            processEpisodes()
        }
    }
    
    func processEpisodes() {
        self.logger?.add(toLog: "GetITVShows (Info): Episodes: \(episodes.count) Today Programmes: \(programmes.count) ")
        
        /* First we update datetimeadded for the carried forward programmes */
        for programme: ProgrammeData in episodes {
            programme.timeAdded = currentTime
        }
        
        /* Now write CF to disk */
        NSKeyedArchiver.archiveRootObject(episodes, toFile: programmesFilePath)
        
        /* Now create the cache file that used to be created by get_iplayer */
        //    my @cache_format = qw/index type name episode seriesnum episodenum pid channel available expires duration desc web thumbnail timeadded/;
        let cacheFileHeader = "#index|type|name|episode|seriesnum|episodenum|pid|channel|available|expires|duration|desc|web|thumbnail|timeadded\n"
        var cacheIndexNumber: Int = 100000
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        var episodeString: String? = nil
        let dateFormatter1 = DateFormatter()
        dateFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter1.timeZone = TimeZone(secondsFromGMT: 0)
        var dateAiredString: String? = nil
        var cacheFileEntries = [String]()
        cacheFileEntries.append(cacheFileHeader)
        
        for episode: ProgrammeData in episodes {
            var cacheFileContentString = ""
            if let timeDateLastAired = episode.timeDateLastAired {
                episodeString = dateFormatter.string(from: timeDateLastAired)
                dateAiredString = dateFormatter1.string(from: timeDateLastAired)
            } else {
                episodeString = ""
                dateAiredString = dateFormatter1.string(from: Date())
            }
            
            let dateAddedInteger: TimeInterval
            if let timeAdded = episode.timeAdded {
                dateAddedInteger = timeAdded.timeIntervalSince1970
            } else {
                dateAddedInteger = Date().timeIntervalSince1970
            }
            
            //    my @cache_format = qw/index type name episode seriesnum episodenum pid channel available expires duration desc web thumbnail timeadded/;
            cacheFileContentString += String(format: "%06d|", cacheIndexNumber)
            cacheIndexNumber += 1
            cacheFileContentString += "itv|"
            cacheFileContentString += episode.programmeName
            cacheFileContentString += "|"
            
            if let aString = episodeString {
                cacheFileContentString += aString
            }
            
            cacheFileContentString += "|\(episode.seriesNumber)|\(episode.episodeNumber)|"
            cacheFileContentString += episode.productionId
            cacheFileContentString += "|ITV Player|"
            if let aString = dateAiredString {
                cacheFileContentString += aString
            }
            
            cacheFileContentString += "|||\(episode.programDescription)"
            cacheFileContentString += "|"
            cacheFileContentString += episode.programmeURL
            cacheFileContentString += "||\(Int(dateAddedInteger))|\n"
            cacheFileEntries.append(cacheFileContentString)
        }
        
        var cacheData = Data()
        for cacheString in cacheFileEntries {
            if let stringData = cacheString.data(using: .utf8) {
                cacheData.append(stringData)
            }
        }

        let cacheFilePath = supportPath("itv.cache")
        let fileManager = FileManager.default
        if !fileManager.createFile(atPath: cacheFilePath, contents: cacheData, attributes: nil) {
            showAlert(message: "GetITVShows: Could not create cache file!",
                      informative: "Please submit a bug report saying that the history file could not be created.")
        }

        endOfRun()
    }
    
    private func showAlert(message: String, informative: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = informative
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()

        }
    }
    func endOfRun() {
        /* Notify finish and invaliate the NSURLSession */
        getITVShowRunning = false
        mySession?.finishTasksAndInvalidate()
        NotificationCenter.default.post(name: NSNotification.Name("ITVUpdateFinished"), object: nil)
        self.logger?.add(toLog: "GetITVShows: Update Finished")
    }
    
    func mergeAllProgrammes() {
        
        myQueueSize = programmes.count
        myQueueLeft = myQueueSize

        for todayProgramme in programmes {
            myOpQueue.addOperation {
                self.requestProgrammeEpisodes(todayProgramme)
            }
        }
        
        if myQueueSize < 2 {
            AppController.shared()?.itvProgressIndicator.increment(by: 100.0)
        }
        
        if myQueueSize == 0 {
            processEpisodes()
        }
    }
    
    func createProgrammes(data: Data) -> Bool {
        /* Scan itv.com/shows to create full listing of programmes (not episodes) that are available today */
        programmes.removeAll()
        
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

                if numberEpisodes > 0 {
                    // Check for duplicate show listings.
                    let existingProgram = programmes.filter { $0.productionId == productionID }
                    
                    if existingProgram.count == 0 {
                        let myProgramme = ProgrammeData(name: showName ?? "<None>", pid: productionID ?? "", url: showPageURLString ?? "", numberEpisodes: numberEpisodes, timeDateLastAired: currentTime, programDescription:"", thumbnailURL: "")
                        programmes.append(myProgramme)
                    }
                }
            }
        }
        
        /* Now we sort the programmes and drop the duplicates */
        if programmes.count == 0 {
            self.logger?.add(toLog: "No programmes found on www.itv.com/hub/shows")
            showAlert(message: "No programmes were found on www.itv.com/hub/shows",
                      informative: "Try again later. If the problem persists please file a bug.")
            return false
        }
        
        programmes.sort { $0.programmeName < $1.programmeName }
        return true
    }
}

