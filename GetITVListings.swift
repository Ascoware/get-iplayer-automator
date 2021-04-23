//  GetITVListings.swift
//  ITVLoader
//
//  Created by Scott Kovatch on 3/16/18
//

import Foundation
import Kanna
import SwiftyJSON

public class GetITVShows: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    var myQueueSize: Int = 0
    var myQueueLeft: Int = 0
    var mySession: URLSession?
    
    var programmes = [Programme]()
    var episodes = [Programme]()
    var getITVShowRunning = false
    let currentTime = Date()
    var logger: LogController?
    
    func supportPath(_ fileName: String) -> String
    {
        if let applicationSupportDir = FileManager.default.applicationSupportDirectory() {
            return applicationSupportDir.appending("/").appending(fileName)
        }
        
        return NSHomeDirectory().appending("/.get_iplayer/").appending(fileName)
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
        episodes.removeAll()
        programmes.removeAll()
        
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
        if let aString = URL(string: "https://www.itv.com/hub/shows") {
            mySession?.dataTask(with: aString) {(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void in
                if let error = error {
                    let errorMessage = "GetITVListings (Error: \(error.localizedDescription)): Unable to retreive show listings from ITV"
                    self.logger?.add(toLog: errorMessage)
                }
                guard let data = data else {
                    self.endOfRun()
                    return
                }
                
                if self.createProgrammes(data: data) {
                    self.myQueueSize = self.programmes.count
                    self.myQueueLeft = self.myQueueSize

                    if self.myQueueSize >= 0 {
                        for todayProgramme in self.programmes {
                            self.requestEpisodes(program: todayProgramme)
                        }
                    } else {
                        self.writeEpisodeCacheFile()
                    }
                    
                } else {
                    self.endOfRun()
                }
            }.resume()
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
                    let existingProgram = programmes.filter { $0.pid == productionID }
                    
                    if existingProgram.count == 0 {
                        let seriesInfo = Programme()
                        seriesInfo.seriesName = showName ?? ""
                        seriesInfo.pid = productionID ?? ""
                        seriesInfo.url = showPageURLString ?? ""
                        programmes.append(seriesInfo)
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
        
        programmes.sort { $0.seriesName < $1.seriesName }
        return true
    }

    func requestEpisodes(program: Programme) {
        /* Get all episodes for the programme name identified in MyProgramme */
        if let url = URL(string: program.url) {
            mySession?.dataTask(with: url) {(data, _, error) in
                self.processEpisodes(program: program, pageData: data, error: error)
            }.resume()
        }
    }
    
    func dateForTimeString(_ time:String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT:0)
        return dateFormatter.date(from: time)
    }
        
    func processEpisodeElement(programInfo: Programme, show: Kanna.XMLElement, season: Int) {
        let dateTimeString = show.at_xpath(".//@datetime")?.text
        
        var dateAiredUTC: Date? = nil
        if let dateTimeString = dateTimeString {
            dateAiredUTC = dateForTimeString(dateTimeString)
        }
        
        let programURL = URL(string: programInfo.url)?.deletingLastPathComponent()

        let description = show.at_xpath(".//p[@class='tout__summary theme__subtle']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var episodeNumber: Int = 0
        var episodeTitle: String?

        let episodeContent = show.at_xpath(".//h3[@class='tout__title complex-link__target theme__target']")?.content?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let episodeContent = episodeContent {
            if episodeContent.hasPrefix("Episode ") {
                let pattern = #"Episode (\d+)"#;
                let episodeRegex = try! NSRegularExpression(pattern: pattern, options: [])
                let nsrange = NSRange(episodeContent.startIndex..<episodeContent.endIndex,
                                      in: episodeContent)
                episodeRegex.enumerateMatches(in: episodeContent,
                                              options: [],
                                              range: nsrange) { (match, _, stop) in
                    guard let match = match else { return }
                    if let numberRange = Range(match.range(at: 1), in: episodeContent) {
                        episodeNumber = Int(episodeContent[numberRange]) ?? 0
                    }
                }
                episodeTitle = episodeContent
            } else {
                let pattern = #"(\d+)\. (.+)"#
                let episodeRegex = try! NSRegularExpression(pattern: pattern, options: [])
                let nsrange = NSRange(episodeContent.startIndex..<episodeContent.endIndex,
                                      in: episodeContent)
                episodeRegex.enumerateMatches(in: episodeContent,
                                              options: [],
                                              range: nsrange) { (match, _, stop) in
                    guard let match = match else { return }
                    if let numberRange = Range(match.range(at: 1), in: episodeContent) {
                        episodeNumber = Int(episodeContent[numberRange]) ?? 0
                    }
                    if let epNameRange = Range(match.range(at: 2), in: episodeContent) {
                        episodeTitle = String(episodeContent[epNameRange])
                    }
                }
            }
        }
        
        var productionID: String? = ""
        var showURL: URL? = nil
        if let showURLString = show.at_xpath("@href")?.text {
            showURL = URL(string: showURLString)
            productionID = showURL?.lastPathComponent
        }
        
//        print("Program: \(program.programmeName)")
//        print("Show URL: \(showURL?.absoluteString ?? "")")
//        print("Episode number: \(episodeNumber ?? 0)")
//        print("Series number: \(seriesNumber ?? 0)")
//        print("productionID: \(productionID ?? "")")
//        print("Date aired: \(dateTimeString ?? "Unknown")")
//        print("=================")
        
        // Make sure the URL matches the show listing -- ITV likes to sneak other shows on a program page.
        if let showURLBase = showURL?.deletingLastPathComponent(), showURLBase.absoluteString == programURL?.absoluteString {
            let episode = Programme()
            episode.seriesName = programInfo.seriesName
            episode.pid = productionID ?? ""
            episode.url = showURL?.absoluteString ?? ""
            episode.lastBroadcast = dateAiredUTC ?? Date()
            episode.lastBroadcastString = dateTimeString ?? ""
            episode.desc = description ?? ""
            episode.episodeName = episodeTitle ?? ""
            episode.season = season
            episode.episode = episodeNumber
            self.episodes.append(episode)
        }

    }
    
    func processSingleEpisode(html: String) {
        let newProgram = ITVMetadataExtractor.getShowMetadata(htmlPageContent: html)
        self.episodes.append(newProgram)
    }

    fileprivate func operationCompleted() {
        let increment = Double(myQueueSize - 1) > 0 ? 100.0 / Double(myQueueSize - 1) : 100.0
        AppController.shared().itvProgressIndicator.increment(by: increment)
        
        /* Check if there is any outstanding work before processing the carried forward programme list */
        myQueueLeft -= 1
        if (myQueueLeft == 0) {
            writeEpisodeCacheFile()
        }
    }

    func processEpisodes(program: Programme, pageData: Data?, error: Error?) {
        if let error = error {
            let errorMessage = "GetITVListings (Error(\(error))): Unable to retreive programme episodes for \(program.url)"
            self.logger?.add(toLog: errorMessage)
            operationCompleted()
            return
        }

        guard let pageData = pageData else {
            operationCompleted()
            return
        }

        if let showPageHTML = try? HTML(html: pageData, encoding: .utf8) {
            let seriesElements = showPageHTML.xpath("//section[@class='module module--secondary js-series-group']")

            if seriesElements.count > 0 {
                for series in seriesElements {
                    var seriesNumber = 0
                    if let seriesText = series.at_xpath("//h2")?.content {
                        let pattern = #"([\d]+$)"#;
                        let episodeRegex = try! NSRegularExpression(pattern: pattern, options: [])
                        let nsrange = NSRange(seriesText.startIndex..<seriesText.endIndex,
                                              in: seriesText)
                        episodeRegex.enumerateMatches(in: seriesText,
                                                      options: [],
                                                      range: nsrange) { (match, _, stop) in
                            guard let match = match else { return }
                            if let numberRange = Range(match.range(at: 1), in: seriesText) {
                                seriesNumber = Int(seriesText[numberRange]) ?? 0
                            }
                        }

                    }
                    let episodeElements = series.xpath("//a[@data-content-type='episode']")

                    if episodeElements.count == 0 {
                        print ("----- Found series but no episode: \(program.url)")
                    }

                    for episode in episodeElements {
                        processEpisodeElement(programInfo: program, show: episode, season: seriesNumber)
                    }
                }
            } else {
                let episodeElements = showPageHTML.xpath("//a[@data-content-type='episode']")

                if episodeElements.count > 0 {
                    // This is a series, so create a Programme for each episode.
                    for episode in episodeElements {
                        processEpisodeElement(programInfo: program, show: episode, season: 0)
                    }
                } else {
                    // This page is itself a program (most likely a movie.)
                    // Extract its metadata and create a ProgrammeData for it.
                    if let pageText = String(data: pageData, encoding: .utf8) {
                        processSingleEpisode(html: pageText)
                    }
                }
            }
        }
        
        operationCompleted()
    }
    
    func writeEpisodeCacheFile() {
        self.logger?.add(toLog: "GetITVShows (Info): Episodes: \(episodes.count) Today Programmes: \(programmes.count) ")

        /* Now create the cache file that used to be created by get_iplayer */
        //    my @cache_format = qw/index type name episode seriesnum episodenum pid channel available expires duration desc web thumbnail timeadded/;
        let cacheFileHeader = "#index|type|name|episode|seriesnum|episodenum|pid|channel|available|expires|duration|desc|web|thumbnail|timeadded\n"
        var cacheIndexNumber: Int = 100000
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        var cacheFileEntries = [String]()
        cacheFileEntries.append(cacheFileHeader)
        let creationTime = Date()

        episodes.forEach { episode in
            var cacheEntry = ""
            if episode.pid.isEmpty {
                print("WARN: Bad episode object \(episode) ")
                return
            }
            let dateAiredString = isoFormatter.string(from: episode.lastBroadcast)

            if episode.episodeName.isEmpty {
                episode.episodeName = DateFormatter.localizedString(from: episode.lastBroadcast, dateStyle: .medium, timeStyle: .none)
            }

            let dateAddedInteger = Int(floor(creationTime.timeIntervalSince1970))

            //    my @cache_format = qw/index type name episode seriesnum episodenum pid channel available expires duration desc web thumbnail timeadded/;
            cacheEntry += String(format: "%06d|", cacheIndexNumber)
            cacheIndexNumber += 1
            cacheEntry += "itv|"
            cacheEntry += episode.seriesName

            // For consistency with get_iplayer append the ': Series x' for shows that are part of a season.
            if (episode.season > 0) {
                cacheEntry += ": Series \(episode.season)"
            }

            cacheEntry += "|"
            cacheEntry += episode.episodeName
            cacheEntry += "|\(episode.season)|\(episode.episode)|"
            cacheEntry += episode.pid
            cacheEntry += "|ITV Player|"
            cacheEntry += dateAiredString
            cacheEntry += "|||\(episode.desc)"
            cacheEntry += "|"
            cacheEntry += episode.url
            cacheEntry += "|"
            cacheEntry += episode.thumbnailURLString
            cacheEntry += "|\(dateAddedInteger)|\n"
            cacheFileEntries.append(cacheEntry)
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
    
}

