//  GetITVListings.swift
//  ITVLoader
//
//  Created by Scott Kovatch on 3/16/18
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjack
import Swarm

public class GetITVShows: NSObject, SwarmDelegate {
    var fetches: Int = 0
    var fetchesDone: Int = 0
    var episodes = [Programme]()
    var getITVShowRunning = false
    let mainURL = URL(string: "https://www.itv.com/watch/categories")!
    let currentTime = Date()

    var configuration: SwarmConfiguration = {
        var config = SwarmConfiguration()
        config.downloadDelay = 2
//        config.maxConcurrentConnections = 5
        //        config.scrappingBehavior = .breadthFirst
        return config
    }()

    lazy var itvSwarm = Swarm(startURLs: [mainURL], configuration: configuration, delegate: self)

    func supportPath(_ fileName: String) -> String
    {
        if let applicationSupportDir = FileManager.default.applicationSupportDirectory() {
            return applicationSupportDir.appending("/").appending(fileName)
        }
        
        return NSHomeDirectory().appending("/.get_iplayer/").appending(fileName)
    }

    @objc public func itvUpdate() {
        DDLogInfo("ITV Cache Update Starting")
        fetches = 0
        fetchesDone = 0
        episodes.removeAll()
        itvSwarm.start()
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
            DDLogWarn("No programmes found on www.itv.com/watch/categories")
            self.showAlert(message: "No programmes were found on www.itv.com/watch/categories",
                           informative: "Try again later. If the problem persists please file a bug.")
            return []
        }

        var categoryURLs = [URL]()

        // Main page has links to each category
        let categoriesLinks = categoriesHTML.xpath("//a[@class='cp_link cp_sub-nav__link']")

        for category in categoriesLinks {
            guard let categoryFragment = category["href"],
                  let categoryPageURL = URL(string: "https://www.itv.com" + categoryFragment) else {
                continue
            }

            categoryURLs.append(categoryPageURL)
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
            let programmes = JSON.init(parseJSON: json)
            let programList = programmes[["props","pageProps","programmes"]].arrayValue

            for program in programList {
                let tierData = program["tier"].arrayValue

                // Check for premium/britbox shows. We can't get those.
                for tier in tierData {
                    if tier == "PAID" {
                        continue
                    }
                }

                let titleSlug = program["titleSlug"].stringValue
                let showID = program["encodedProgrammeId"]["letterA"].stringValue
                guard let showPageURL = URL(string: "https://www.itv.com/watch/\(titleSlug)/\(showID)") else {
                    continue
                }
                seriesURLs.append(showPageURL)
            }
        }

        return seriesURLs
    }

    func fetchPrograms(seasonPage: VisitedURL) -> [Programme] {
        guard let seasonContent = seasonPage.htmlString(), let seasonHTMLPage = try? HTML(html: seasonContent, encoding: .utf8) else {
            return []
        }

        var programs = [Programme]()

        if let metadataBlock = seasonHTMLPage.at_xpath("//script[@id='__NEXT_DATA__']"),
           let json = metadataBlock.content {
            let episodeInfo = JSON.init(parseJSON: json)
            let seriesList = episodeInfo[["props","pageProps","title","brand","series"]].arrayValue

            for series in seriesList {
                let episodes = series["episodes"].arrayValue

                for episode in episodes {
                    let tierData = episode["tier"].arrayValue

                    // Check for premium/britbox shows. We can't get those.
                    for tier in tierData {
                        if tier == "PAID" {
                            continue
                        }
                    }

                    let program = Programme()
                    program.seriesName = episode["programmeTitle"].stringValue
                    program.episode = episode["episodeNumber"].intValue
                    program.season = episode["seriesNumber"].intValue
                    program.showName = episode["episodeTitle"].stringValue

                    // Now and then we get a description with a newline. That will break the cache
                    // so clean it up here.
                    let desc = episode["synopsis"].stringValue
                    program.desc = desc.components(separatedBy: .newlines).joined()

                    program.episodeName = episode["episodeTitle"].stringValue
                    if program.episodeName.isEmpty {
                        program.episodeName = episode["numberedEpisodeTitle"].stringValue
                    }

                    program.tvNetwork = "ITV"
                    let lastAirDate = episode["broadcastDateTime"].stringValue
                    let dateFormatter = ISO8601DateFormatter()
                    program.lastBroadcast = dateFormatter.date(from: lastAirDate)

                    if let lastAirDate = program.lastBroadcast {
                        program.lastBroadcastString = DateFormatter.localizedString(from: lastAirDate, dateStyle: .medium, timeStyle: .none)
                    }

                    let showURL = episode["href"].stringValue
                    program.url = "https://www.itv.com/watch\(showURL)"

                    let pathElements = showURL.components(separatedBy: "/")

                    // For consistency we'll use the last item of the show URL as the PID even
                    // though there is a 'productionID' in the metadata.
                    if let pid = pathElements.last {
                        program.pid = pid
                    } else {
                        program.pid = episode["productionId"].stringValue
                    }

                    programs.append(program)
                }
            }
        }

        return programs
    }

    func writeEpisodeCacheFile() {
        DDLogInfo("INFO: Adding \(episodes.count) itv programmes to cache")

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
            cacheEntry += "|ITV|"
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
        NotificationCenter.default.post(name: NSNotification.Name("ITVUpdateFinished"), object: nil)
        DDLogInfo("INFO: ITV update finished")
    }

}

