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

}
