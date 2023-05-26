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
    let mainURL = URL(string: "https://player.stv.tv/tvguide/stv")!
    let currentTime = Date()
    var configuration: SwarmConfiguration = {
        var config = SwarmConfiguration()
        config.downloadDelay = 2
        config.maxConcurrentConnections = 5
//        config.scrappingBehavior = .breadthFirst
        return config
    }()

    var stvSwarm: Swarm?

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
        stvSwarm = Swarm(startURLs: [mainURL], configuration: configuration, delegate: self)
        stvSwarm?.start()
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
            let longDateFormatter = ISO8601DateFormatter()
            longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)
            longDateFormatter.formatOptions = [.withYear, .withDay, .withMonth, .withDashSeparatorInDate]
            var dateURLs = [URL]()
            for i in 0...7 {
                if let dayToFetch = Calendar.current.date(byAdding: .day, value: -i, to: Date()) {
                    let dateString = longDateFormatter.string(from: dayToFetch)
                    dateURLs.append(url.origin.url.appendingPathComponent(dateString))
                }
            }
            nextURLs = dateURLs.map { ScrappableURL(url: $0, depth: 2) }
            break
        case 2:
            let showURLs = getProgramLinks(guidePage: url)
            nextURLs = showURLs.map { ScrappableURL(url: $0, depth: 3) }
            break
        case 3:
            let programs = STVMetadataExtractor.getShowMetadata(url: url.origin.url.absoluteString, html: url.htmlString(using: .utf8) ?? "")
            for program in programs {
                if !program.pid.isEmpty {
                    self.episodes.append(program)
                }
            }
            break
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
            AppController.shared().stvProgressIndicator.doubleValue = progress
        }
    }

    func getProgramLinks(guidePage: VisitedURL) -> [URL] {
        guard let dayContent = guidePage.htmlString(), let dayContentHTML = try? HTML(html: dayContent, encoding: .utf8) else {
            return []
        }

        var showPages = [URL]()

        if let metadataBlock = dayContentHTML.at_xpath("//script[@id='__NEXT_DATA__']"),
           let json = metadataBlock.content {
            let programmes = JSON.init(parseJSON: json)
            let programList = programmes[["props","pageProps","assets"]].arrayValue

            for program in programList {
                let episode = program["episode"]
                let showLink = episode["_permalink"].stringValue

                guard let showPageURL = URL(string: showLink) else {
                    continue
                }

                showPages.append(showPageURL)
            }
        }

        return showPages
    }

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

