//
//  ITVMetadataExtractor.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/3/21.
//

import Foundation
import Kanna
import SwiftyJSON

class ITVMetadataExtractor {

    static func getShowMetadata(htmlPageContent: String) -> Programme {
        var episodeID = ""
        var timeAired: Date? = nil
        let longDateFormatter = DateFormatter()
        let enUSPOSIXLocale = Locale(identifier:"en_US_POSIX")
        longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)
        longDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
        longDateFormatter.locale = enUSPOSIXLocale

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "EEE MMM dd"
        shortDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        shortDateFormatter.locale = enUSPOSIXLocale

        let newProgram = Programme()

        if let htmlPage = try? HTML(html: htmlPageContent, encoding: .utf8) {
            // There should only be one 'video' element.
            if let videoElement = htmlPage.at_xpath("//div[@id='video']") {
                newProgram.seriesName = videoElement.at_xpath("//@data-video-title")?.text ?? "Unknown"
                newProgram.showName = newProgram.seriesName
                newProgram.episodeName = videoElement.at_xpath("//@data-video-episode")?.text ?? ""
                episodeID = videoElement.at_xpath("//@data-video-episode-id")?.text ?? ""
            }

            if let descriptionElement = htmlPage.at_xpath("//script[@id='json-ld']") {
                if let descriptionJSON = descriptionElement.content {
                    let descriptionData = JSON(parseJSON: descriptionJSON)
                    let breadcrumbs = descriptionData["itemListElement:"].arrayValue
                    for item in breadcrumbs {
                        if item["item:"]["@type"] == "TVEpisode" {
                            let showMetadata = item["item:"]
                            newProgram.desc = showMetadata["description"].string ?? "None available"
                            newProgram.episode = showMetadata["episodeNumber"].intValue
                            newProgram.season = showMetadata["partOfSeason"]["seasonNumber"].intValue
                            newProgram.seriesName = showMetadata["partOfSeries"]["name"].stringValue
                            newProgram.episodeName = showMetadata["name"].stringValue
                            newProgram.thumbnailURLString = showMetadata["image"]["url"].stringValue

                            let potentialActions = showMetadata["potentialAction"].arrayValue

                            if potentialActions.count > 0 {
                                let potentialAction = potentialActions[0]
                                let expectActions = potentialAction["expectsAcceptanceOf"].arrayValue

                                if expectActions.count > 0 {
                                    let expectAction = expectActions[0]
                                    let availabilityTime = expectAction["availabilityStarts"].stringValue
                                    timeAired = longDateFormatter.date(from:availabilityTime)
                                }
                            }

                            break
                        }
                    }
                }
            }
        }

        if !episodeID.isEmpty {
            // At this point all we have left is the production ID.
            // A series number doesn't make much sense, so just parse out an episode number.
            let programIDElements = episodeID.split(separator: "/")
            if let lastElement = programIDElements.last, let intLastElement = Int(lastElement) {
                newProgram.episode = intLastElement
            }
        }

        if newProgram.episodeName.isEmpty {
            if let timeAired = timeAired {
                let shortDate = shortDateFormatter.string(from: timeAired)
                newProgram.episodeName = shortDate
            }
        }
        if let timeAired = timeAired {
            newProgram.dateAired = timeAired
            newProgram.standardizedAirDate = longDateFormatter.string(from: timeAired)
        }

        return newProgram
    }

}
