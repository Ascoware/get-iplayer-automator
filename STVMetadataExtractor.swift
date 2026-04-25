//
//  STVMetadataExtractor.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/3/21.
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjackSwift

enum STVMetadataError: Error {
    case noMetadataFound
    case drmProtectedError
}

class STVMetadataExtractor {

    static func getShowMetadata(html: String) throws -> [Programme] {
        let longDateFormatter = ISO8601DateFormatter()
        longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)

        let newProgram = Programme()
        newProgram.tvNetwork = "STV"

        // Find the "props" JSON dictionary. Then traverse the tree
        if let htmlPage = try? HTML(html: html, encoding: .utf8) {
            guard let propertiesElement = htmlPage.at_xpath("//script[@id='__NEXT_DATA__']") else {
                DDLogError("**** No metadata found")
                throw STVMetadataError.noMetadataFound
            }

            if let propertiesContent = propertiesElement.content {
                let propertiesJSON = JSON(parseJSON: propertiesContent)
                let propsDict = propertiesJSON["props"].dictionaryValue
                if let pageProps = propsDict["pageProps"] {
                    let episodeInfo = pageProps["episodeInfo"]
                    // episodeInfo.episodeId is a JSON string; pageProps.episodeId is an integer — use the string version
                    newProgram.pid = episodeInfo["episodeId"].stringValue

                    // Primary metadata from episodeInfo — always present on first page load
                    newProgram.seriesName = episodeInfo["name"].stringValue
                    newProgram.episodeName = episodeInfo["title"].stringValue
                    let startTime = episodeInfo["startTime"].stringValue
                    newProgram.lastBroadcast = longDateFormatter.date(from: startTime)
                    if let lastAirDate = newProgram.lastBroadcast {
                        newProgram.lastBroadcastString = DateFormatter.localizedString(from: lastAirDate, dateStyle: .medium, timeStyle: .none)
                    }

                    // episodeInfo.summary is the episode description; pageProps.summary is the series description
                    let rawDesc = episodeInfo["summary"].string ?? pageProps["summary"].string ?? "None available"
                    newProgram.desc = rawDesc.filter { !$0.isNewline }

                    // Supplement with playerApiCache if available (series/episode numbers and DRM check)
                    let episodesKey = "/episodes/\(newProgram.pid)"
                    if let showData = propsDict["initialReduxState"]?["playerApiCache"][episodesKey]["results"],
                       !showData.isEmpty {
                        let protectedMedia = showData["programme"]["drmEnabled"].boolValue
                        if protectedMedia {
                            DDLogError("**** DRM protected media - bailing out")
                            throw STVMetadataError.drmProtectedError
                        }

                        let seriesString = showData["playerSeries"]["name"].stringValue
                        for item in seriesString.components(separatedBy: .whitespacesAndNewlines) {
                            if let number = Int(item) {
                                newProgram.season = number
                            }
                        }
                        newProgram.episode = showData["number"].intValue
                    }

                    newProgram.url = pageProps["currentUrl"].stringValue
                    newProgram.thumbnailURLString = pageProps["image"].stringValue
                }
            }
        }

        // The series number should appear in the showName.
        // STV provides us a "Series xx" string, so if that's available use it.
        newProgram.showName = newProgram.seriesName

        if newProgram.season != 0 {
            newProgram.showName = "\(newProgram.seriesName): Series \(newProgram.season)"
        }

        if newProgram.episodeName.isEmpty {
            if newProgram.episode != 0 {
                newProgram.episodeName = "Episode \(newProgram.episode)"
            } else {
                newProgram.episodeName = newProgram.lastBroadcastString
            }
        }

        return [newProgram]
    }

    static func getSeriesEpisodes(html: String, selectedSeriesId: String? = nil) throws -> [Programme] {
        guard let htmlPage = try? HTML(html: html, encoding: .utf8),
              let propertiesElement = htmlPage.at_xpath("//script[@id='__NEXT_DATA__']"),
              let propertiesContent = propertiesElement.content else {
            throw STVMetadataError.noMetadataFound
        }

        let json = JSON(parseJSON: propertiesContent)
        let data = json["props"]["pageProps"]["data"]

        // Programme-level DRM check
        if data["programmeData"]["drmEnabled"].boolValue {
            throw STVMetadataError.drmProtectedError
        }

        let showName = data["programmeHeader"]["name"].stringValue
        guard !showName.isEmpty else {
            throw STVMetadataError.noMetadataFound
        }

        // Each series gets its own tab. The tab the page rendered server-side has its
        // episodes inline in `data`; the others have `data: null` and a `params` block
        // pointing at the player API.
        let episodeTabs = data["tabs"].arrayValue.filter {
            $0["type"].stringValue == "episode" && $0["accessibility"].type == .null
        }
        guard !episodeTabs.isEmpty else {
            throw STVMetadataError.noMetadataFound
        }

        // Pick the tab matching the selected series fragment (e.g. "all31-kingdom-series-3"),
        // falling back to the first/only tab.
        let episodeTab: JSON = {
            if let id = selectedSeriesId,
               let match = episodeTabs.first(where: { $0["id"].stringValue == id }) {
                return match
            }
            return episodeTabs[0]
        }()

        let episodeURLs = episodeURLStrings(for: episodeTab)
        var programmes: [Programme] = []

        for episodeURLString in episodeURLs {
            guard let episodeHTML = fetchHTML(urlString: episodeURLString) else {
                DDLogWarn("Failed to fetch episode page: \(episodeURLString)")
                continue
            }

            do {
                let progs = try getShowMetadata(html: episodeHTML)
                programmes.append(contentsOf: progs)
            } catch {
                DDLogWarn("Failed to extract metadata from \(episodeURLString): \(error)")
            }
        }

        return programmes
    }

    /// Resolve a series tab to a list of episode page URLs. Inline `data` is used when
    /// present; otherwise the player API is queried using the tab's `params`.
    private static func episodeURLStrings(for episodeTab: JSON) -> [String] {
        if let inline = episodeTab["data"].array, !inline.isEmpty {
            return inline.compactMap { episode in
                guard let link = episode["link"].string, !link.isEmpty else { return nil }
                return "https://player.stv.tv" + link
            }
        }

        let params = episodeTab["params"]
        let path = params["path"].stringValue
        guard !path.isEmpty else { return [] }

        var components = URLComponents(string: "https://player.api.stv.tv/v1" + path)
        var items: [URLQueryItem] = []
        for (key, value) in params["query"].dictionaryValue {
            items.append(URLQueryItem(name: key, value: value.stringValue))
        }
        if !items.contains(where: { $0.name == "limit" }) {
            items.append(URLQueryItem(name: "limit", value: "200"))
        }
        components?.queryItems = items

        guard let apiURL = components?.url?.absoluteString,
              let body = fetchHTML(urlString: apiURL),
              let bodyData = body.data(using: .utf8) else {
            DDLogWarn("Failed to fetch series episodes from player API")
            return []
        }

        let apiJSON = JSON(bodyData)
        return apiJSON["results"].arrayValue.compactMap { $0["_permalink"].string }
    }

    private static func fetchHTML(urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        var result: String? = nil
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                result = String(data: data, encoding: .utf8)
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()
        return result
    }

}
