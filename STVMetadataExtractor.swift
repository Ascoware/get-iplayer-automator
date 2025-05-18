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
                    newProgram.pid = pageProps["episodeId"].stringValue
                    let episodesKey = "/episodes/\(newProgram.pid)"
                    if let showData = propsDict["initialReduxState"]?["playerApiCache"][episodesKey]["results"] {
                        if showData.isEmpty {
                            DDLogError("**** No metadata found")
                            throw STVMetadataError.noMetadataFound
                        }
                        
                        let protectedMedia = showData["programme"]["drmEnabled"].boolValue

                        if protectedMedia {
                            DDLogError("**** DRM protected media - bailing out")
                            throw STVMetadataError.drmProtectedError
                        }

                        newProgram.seriesName = showData["programme"]["name"].stringValue
                        newProgram.episodeName = showData["title"].stringValue
                        let seriesString = showData["playerSeries"]["name"].stringValue

                        let seriesComponents = seriesString.components(separatedBy: .whitespacesAndNewlines)
                        for item in seriesComponents {
                            if let number = Int(item) {
                                newProgram.season = number
                            }
                        }

                        newProgram.episode = showData["number"].intValue
                        let startTime = showData["schedule"]["startTime"].stringValue
                        newProgram.lastBroadcast = longDateFormatter.date(from: startTime)
                        if let lastAirDate = newProgram.lastBroadcast {
                            newProgram.lastBroadcastString = DateFormatter.localizedString(from: lastAirDate, dateStyle: .medium, timeStyle: .none)
                        }
                    }
                    newProgram.url = pageProps["currentUrl"].stringValue
                    let rawDesc = pageProps["summary"].string ?? "None available"
                    newProgram.desc = rawDesc.filter { !$0.isNewline }
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
