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
        if let applicationSupportDir = FileManager.default.applicationSupportDirectory() {
            return applicationSupportDir.appending("/").appending(fileName)
        }
        
        return NSHomeDirectory().appending("/.get_iplayer/").appending(fileName)
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
        episodes = []
        
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
                            self.myOpQueue.addOperation {
                                self.requestProgrammeEpisodes(todayProgramme)
                            }
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

    func requestProgrammeEpisodes(_ myProgramme: ProgrammeData) {
        /* Get all episodes for the programme name identified in MyProgramme */
        if let url = URL(string: myProgramme.programmeURL) {
            mySession?.dataTask(with: url) {(data, _, error) in
                self.processEpisodesForProgram(myProgramme, pageData: data, error: error)
            }.resume()
        }
    }
    
    func dateForTimeString(_ time:String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT:0)
        return dateFormatter.date(from: time)
    }
        
    func processEpisodeElement(program: ProgrammeData, show: Kanna.XMLElement) {
        let dateTimeString = show.at_xpath(".//@datetime")?.text
        
        var dateAiredUTC: Date? = nil
        if let dateTimeString = dateTimeString {
            dateAiredUTC = dateForTimeString(dateTimeString)
        }
        
        let programURL = URL(string: program.programmeURL)?.deletingLastPathComponent()

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
        
//        print("Program: \(program.programmeName)")
//        print("Show URL: \(showURL?.absoluteString ?? "")")
//        print("Episode number: \(episodeNumber ?? 0)")
//        print("Series number: \(seriesNumber ?? 0)")
//        print("productionID: \(productionID ?? "")")
//        print("Date aired: \(dateTimeString ?? "Unknown")")
//        print("=================")
        
        // Make sure the URL matches the show listing -- ITV likes to sneak other shows on a program page.
        if let showURLBase = showURL?.deletingLastPathComponent(), showURLBase.absoluteString == programURL?.absoluteString {
            
            /* Create ProgrammeData Object and store in array */
            let myProgramme = ProgrammeData(name: program.programmeName, pid: productionID ?? "", url: showURL?.absoluteString ?? "", numberEpisodes: program.numberEpisodes , timeDateLastAired: dateAiredUTC, programDescription: description ?? "", thumbnailURL: "")
            
            myProgramme.addProgrammeSeriesInfo(seriesNumber ?? 0, aEpisodeNumber: episodeNumber ?? 0)
            self.episodes.append(myProgramme)
        }

    }
    
    func processSingleEpisode(_ aProgramme: ProgrammeData, html: HTMLDocument) {
        let showDataElement = html.xpath("//script[@id=\"json-ld\"]")

        if let nodeContent = showDataElement.first?.text {
            let data = nodeContent.data(using: String.Encoding.utf8, allowLossyConversion: false)!
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: AnyObject]
                if let description = json["description"] as? String {
                    aProgramme.programDescription = description
                }
                
                if let url = json["@id"] as? String {
                    aProgramme.programmeURL = url
                    aProgramme.productionId = URL(string: url)?.lastPathComponent ?? ""
                }
                
                if let showName = json["partOfSeries"]?["name"] as? String {
                    aProgramme.programmeName = showName
                }
                
                if let thumbnailURL = json["image"]?["url"] as? String {
                    aProgramme.thumbnailURL = thumbnailURL
                }
            } catch let error as NSError {
                print("Failed to load: \(error.localizedDescription)")
            }
        }
        
        if let dateElement = html.at_xpath(".//li[@class='episode-info__meta-item episode-info__meta-item--broadcast']") {
            if let dateTimeElement = dateElement.at_xpath(".//@datetime")?.text {
                aProgramme.timeDateLastAired = dateForTimeString(dateTimeElement)
            }
        }
        
        let myProgramme = ProgrammeData(name: aProgramme.programmeName, pid: aProgramme.productionId, url: aProgramme.programmeURL, numberEpisodes: 1 , timeDateLastAired: aProgramme.timeDateLastAired, programDescription: aProgramme.programDescription, thumbnailURL: aProgramme.thumbnailURL)
        
        self.episodes.append(myProgramme)
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
    
    func processEpisodesForProgram(_ aProgramme: ProgrammeData, pageData: Data?, error: Error?) {
        if let error = error {
            let errorMessage = "GetITVListings (Error(\(error))): Unable to retreive programme episodes for \(aProgramme.programmeURL)"
            self.logger?.add(toLog: errorMessage)
            operationCompleted()
            return
        }

        guard let pageData = pageData else {
            operationCompleted()
            return
        }
        
        if let showPageHTML = try? HTML(html: pageData, encoding: .utf8) {
            let episodeElements = showPageHTML.xpath("//a[@data-content-type=\"episode\"]")

            if episodeElements.count > 0 {
                // This is a series, so create a ProgrammeData for each episode.
                for episode in episodeElements {
                    processEpisodeElement(program: aProgramme, show: episode)
                }
            } else {
                // This page is itself a program (most likely a movie.)
                // Extract its metadata and create a ProgrammeData for it.
                processSingleEpisode(aProgramme, html: showPageHTML)
            }
        }
        
        operationCompleted()
    }
    
    func writeEpisodeCacheFile() {
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
    
}

