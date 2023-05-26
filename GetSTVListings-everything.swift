//  GetSTVListings.swift
//
//  Created by Scott Kovatch on 1/16/2023
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjack
import Swarm

public class GetSTVShows: NSObject, SwarmDelegate {

    var fetches: Int = 0
    var fetchesDone: Int = 0
    var episodes = [Programme]()
    var getSTVShowRunning = false
    let mainURL = URL(string: "https://player.stv.tv/categories")!
    let currentTime = Date()
    var configuration: SwarmConfiguration = {
        var config = SwarmConfiguration()
        config.downloadDelay = 2
        config.maxConcurrentConnections = 5
//        config.scrappingBehavior = .breadthFirst
        return config
    }()

    lazy var stvSwarm = Swarm(startURLs: [mainURL], configuration: configuration, delegate: self)

    func supportPath(_ fileName: String) -> String
    {
        if let applicationSupportDir = FileManager.default.applicationSupportDirectory() {
            return applicationSupportDir.appending("/").appending(fileName)
        }
        
        return NSHomeDirectory().appending("/.get_iplayer/").appending(fileName)
    }


    @objc public func stvUpdate() {
        DDLogInfo("STV Cache Update Starting")
        fetches = 1
        fetchesDone = 0
        episodes.removeAll()
        stvSwarm.start()
    }

    public func spider(for url: ScrappableURL) -> Spider {
        let spider = URLSessionSpider()

        spider.httpShouldHandleCookies = false
        spider.userAgent = .randomized(["com.ascoware.get-iplayer", "org.ascoware.get-iplayer", "com.ascoware.get-iplayer-automator"])
//        spider.requestModifier = {
//            var request = $0
//            // Modify URLRequest instance for each request
//            request.timeoutInterval = 20
//            return request
//        }
//        // Modify HTTP headers
//        spider.httpHeaders["Authorization"] = "Basic dGVzdDp0ZXN0"

        return spider
    }

    public func scrappedURL(_ url: VisitedURL, nextScrappableURLs: @escaping ([ScrappableURL]) -> Void) {
        let depth = url.origin.depth
        var nextURLs = [ScrappableURL]()

        DDLogInfo("Processing \(url.origin.url.absoluteString)")

        switch depth {
        case 1:
            let categoryURLs = fetchCategories(categoriesPage: url)
            nextURLs = categoryURLs.map { ScrappableURL(url: $0, depth: 2) }
            break
        case 2:
            let seriesURLs = fetchSeries(categoryPage: url)
            nextURLs = seriesURLs.map { ScrappableURL(url: $0, depth: 3) }
            break
        case 3:
            let seasonURLs = fetchSeasons(seriesPage: url)
            nextURLs = seasonURLs.map { ScrappableURL(url: $0, depth: 4) }
            break
        case 4:
            let programs = fetchPrograms(seasonPage: url)
            for program in programs {
                if !program.pid.isEmpty {
                    self.episodes.append(program)
                }
            }
        default:
            DDLogError("Unknown URL depth while scraping!!")
        }

        fetchesDone += 1
        fetches += nextURLs.count
        DDLogDebug("Fetches done: \(fetchesDone), out of \(fetches), episode count = \(episodes.count)")
        nextScrappableURLs(nextURLs)

        operationCompleted()
    }

    public func scrappingCompleted() {
        writeEpisodeCacheFile()
    }

    public func failedToScrapURL(_ url: VisitedURL) {
        DDLogWarn("===== Failed to get \(url.origin.url.absoluteString)")
        fetchesDone += 1
        operationCompleted()
    }

    /// Default empty protocol implementation
    public func delayingRequest(to url: ScrappableURL, for timeInterval: TimeInterval, becauseOf response: URLResponse?) {
        DDLogWarn("++++ Fetch for \(url.url.absoluteString) was delayed for \(timeInterval)")
    }

    fileprivate func operationCompleted() {
        let progress = (Double(fetchesDone) / Double(fetches)) * 100
        DispatchQueue.main.async {
            AppController.shared().itvProgressIndicator.doubleValue = progress
        }
    }

    func fetchCategories(categoriesPage: VisitedURL) -> [URL] {
        guard let categoryContent = categoriesPage.htmlString(), let categoriesHTML = try? HTML(html: categoryContent, encoding: .utf8) else {
            DDLogWarn("No programmes found on player.stv.tv/categories")
            self.showAlert(message: "No programmes were found on player.stv.tv/categories",
                           informative: "Try again later. If the problem persists please file a bug.")
            return []
        }

        var categoryURLs = [URL]()

        // Main page has links to each category
        if let metadataBlock = categoriesHTML.at_xpath("//script[@id='__NEXT_DATA__']"),
           let json = metadataBlock.content {
            let categories = JSON.init(parseJSON: json)
            let categoryList = categories[["props","pageProps","data", "categoriesMenuItems"]].arrayValue

            for category in categoryList {
                let categoryFragment = category["href"].stringValue
                
                if categoryFragment.hasSuffix("most-popular") || categoryFragment.hasSuffix("recently-added") {
                    continue
                }
                
                guard let categoryPageURL = URL(string: "https://player.stv.tv\(categoryFragment)") else {
                    continue
                }

                categoryURLs.append(categoryPageURL)
            }
        }

        return categoryURLs
    }

    func fetchSeries(categoryPage: VisitedURL) -> [URL] {
        guard let categoryContent = categoryPage.htmlString(), let categoryHTMLPage = try? HTML(html: categoryContent, encoding: .utf8) else {
            return []
        }

        var seriesURLs = [URL]()
        if let metadataBlock = categoryHTMLPage.at_xpath("//script[@id='__NEXT_DATA__']"),
           let json = metadataBlock.content {
            let seriesJSON = JSON.init(parseJSON: json)
            let seriesList = seriesJSON[["props","pageProps","data", "assets"]].arrayValue

            for series in seriesList {
                let seriesLink = series["link"].stringValue
                guard let seriesPageURL = URL(string: "https://player.stv.tv\(seriesLink)") else {
                    continue
                }
                seriesURLs.append(seriesPageURL)
            }
        }

        return seriesURLs
    }

    func fetchSeasons(seriesPage: VisitedURL) -> [URL] {
        guard let seriesContent = seriesPage.htmlString(), let seriesHTMLPage = try? HTML(html: seriesContent, encoding: .utf8) else {
            return []
        }

        var programURLs = [URL]()
        if let metadataBlock = seriesHTMLPage.at_xpath("//script[@id='__NEXT_DATA__']"),
           let json = metadataBlock.content {
            let episodeInfo = JSON.init(parseJSON: json)

            // Multiple series are stored in tabs, but not all tabs have episode data
            let tabList = episodeInfo[["props","pageProps","data","tabs"]].arrayValue
            
            for tab in tabList {

                let tabType = tab["type"].stringValue
                if tabType != "episode" {
                    continue
                }

                let seriesID = tab["id"].stringValue
                let originPage = seriesPage.origin.url
                guard let seriesLink = URL(string: "\(originPage.absoluteString)#\(seriesID)") else {
                    continue
                }

                programURLs.append(seriesLink)
            }
        }

        return programURLs
    }

    func fetchPrograms(seasonPage: VisitedURL) -> [Programme] {
        guard let seasonContent = seasonPage.htmlString(), let seasonHTMLPage = try? HTML(html: seasonContent, encoding: .utf8) else {
            return []
        }

        var programs = [Programme]()
        if let metadataBlock = seasonHTMLPage.at_xpath("//script[@id='__NEXT_DATA__']"),
           let json = metadataBlock.content {
            let seasonJSON = JSON.init(parseJSON: json)
            let seriesInfo = seasonJSON[["props","pageProps","data"]]
            let programName = seriesInfo[["programmeHeader", "name"]].stringValue

            // This time we will pick up the program URLs in the tab.
            let tabList = seasonJSON[["props","pageProps","data","tabs"]].arrayValue

            for tab in tabList {

                let tabType = tab["type"].stringValue
                if tabType != "episode" {
                    continue
                }

                let seriesString = tab["title"].stringValue
                let episodes = tab["data"].arrayValue

                for episode in episodes {
                    let program = Programme()
                    program.pid = episode["id"].stringValue
                    program.desc = episode["summary"].stringValue.components(separatedBy: .newlines).joined(separator: " ")
                    let episodeLink = episode["link"].stringValue
                    program.url = "https://player.stv.tv\(episodeLink)"
                    program.seriesName = seriesString
                    program.episodeName = episode["title"].stringValue
                    program.showName = "\(programName): \(seriesString)"
                    program.tvNetwork = "STV"
                    programs.append(program)
                }

            }
        }

        return programs
    }

//    func processEpisode(episodePage: VisitedURL) -> [Programme] {
//        guard let episodeContent = episodePage.htmlString() else {
//            return []
//        }
//
//        return STVMetadataExtractor.getShowMetadataFromPage(url: episodePage.origin.url.absoluteString, html: episodeContent)
//    }
//
    func writeEpisodeCacheFile() {
        DDLogInfo("INFO: Adding \(episodes.count) stv programmes to cache")
        
        episodes.sort()
        
        /* Now create the cache file that used to be created by get_iplayer */
        //    my @cache_format = qw/index type name episode seriesnum episodenum pid channel available expires duration desc web thumbnail timeadded/;
        let cacheFileHeader = "#index|type|name|episode|seriesnum|episodenum|pid|channel|available|expires|duration|desc|web|thumbnail|timeadded\n"
        var cacheIndexNumber: Int = 100000
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        var cacheFileEntries = [String]()
        cacheFileEntries.append(cacheFileHeader)
        let creationTime = Date()
        
        episodes.forEach { episode in
            var cacheEntry = ""
            if episode.pid.isEmpty {
                DDLogWarn("WARNING: Bad episode object \(episode) ")
                return
            }
            
            let dateAiredString = isoFormatter.string(from: episode.lastBroadcast ?? Date())
            
            if episode.episodeName.isEmpty, let lastBCast = episode.lastBroadcast {
                episode.episodeName = DateFormatter.localizedString(from: lastBCast, dateStyle: .medium, timeStyle: .none)
            }
            
            let dateAddedInteger = Int(floor(creationTime.timeIntervalSince1970))
            
            //    my @cache_format = qw/index type name episode seriesnum episodenum pid channel available expires duration desc web thumbnail timeadded/;
            cacheEntry += String(format: "%06d|", cacheIndexNumber)
            cacheIndexNumber += 1
            cacheEntry += "stv|"
            cacheEntry += episode.seriesName
            
            // For consistency with get_iplayer append the ': Series x' for shows that are part of a season.
            if (episode.season > 0) {
                cacheEntry += ": Series \(episode.season)"
            }
            
            cacheEntry += "|"
            cacheEntry += episode.episodeName
            cacheEntry += "|\(episode.season)|\(episode.episode)|"
            cacheEntry += episode.pid
            cacheEntry += "|STV|"
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
        
        let cacheFilePath = supportPath("stv.cache")
        let fileManager = FileManager.default
        if !fileManager.createFile(atPath: cacheFilePath, contents: cacheData, attributes: nil) {
            showAlert(message: "GetSTVhows: Could not create cache file!",
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
        NotificationCenter.default.post(name: NSNotification.Name("STVUpdateFinished"), object: nil)
        DDLogInfo("INFO: STV update finished")
    }
    
}

