//
//  ITVMetadataParseOperation.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/2/18.
//

import Foundation

public struct ITVShowMetadata {
    var faultCode: String?
    var seriesName: String?
    var seriesNumber: Int?
    var transmissionDate: Date?
    var transmissionDateString: String?
    var episodeTitle: String?
    var episodeNumber: String?
    var thumbnailURL: URL?
    var thumbnailSize: CGSize?
    var subtitleURL: URL?
    var authURL: String?
    var realPID: String?
    var playPath: String?
}

public class ITVMetadataParseOperation : Operation, XMLParserDelegate {
    
    public var result = ITVShowMetadata()
    
    let data: Data
    let checkForRealPID: Bool
    let verbose: Bool
    let itvRates: [String]
    let bitRates: [String]
    var currentMediaFile: ITVMediaFileEntry? = nil
    var mediaFileEntries = [ITVMediaFileEntry]()

    var rawTransmitDate: String?
    var rawTransmitTime: String?
    var vodcridElement: String?
    let dateFormatter : DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT:0)
        return dateFormatter
    }()
    
    var elementStack: [String] = []
    var currentParsedCharacterData = ""
    var accumulatingParsedCharacterData = false
    var inThumbnailElement = false
    var inClosedCaptionElement = false

    public init(data: Data, checkForRealPID: Bool, verbose: Bool, itvRates: [String], bitRates:[String]) {
        self.data = data
        self.itvRates = itvRates
        self.bitRates = bitRates
        self.checkForRealPID = checkForRealPID
        self.verbose = verbose
        super.init()
    }
    
    public override func main() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    
    // MARK: XMLParserDelegate methods
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        elementStack.append(elementName)
        accumulatingParsedCharacterData = false
        
        switch elementName {
        case "EpisodeName", "EpisodeNumber", "SeriesName", "TransmissionDate", "TransmissionTime", "ProgrammeTitle", "faultcode":
            accumulatingParsedCharacterData = true
            currentParsedCharacterData = ""
            
        case "MediaFiles":
            result.authURL = attributeDict["base"]

        case "MediaFile":
            elementStack.append(elementName)
            currentMediaFile = ITVMediaFileEntry()
            currentMediaFile?.bitrate = attributeDict["bitrate"]
            // Pick up the ITV rate from the URL.
        default:
            // Don't care.
            break
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if accumulatingParsedCharacterData {
            currentParsedCharacterData.append(string)
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        elementStack.removeLast()
        
        switch elementName {
        case "ProgrammeTitle":
            result.seriesName = currentParsedCharacterData
        case "EpisodeName":
            result.episodeTitle = currentParsedCharacterData
        case "EpisodeNumber":
            result.episodeNumber = currentParsedCharacterData
        case "TransmissionDate":
            rawTransmitDate = currentParsedCharacterData
        case "TransmissionTime":
            rawTransmitTime = currentParsedCharacterData
        case "Vodcrid":
            vodcridElement = currentParsedCharacterData
        case "faultcode":
            result.faultCode = currentParsedCharacterData
        case "MediaFile":
            if let currentMediaFile = currentMediaFile {
                mediaFileEntries.append(currentMediaFile)
                self.currentMediaFile = nil
            }
            
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        
        // We want to jump back to the element surrounding the <URL> element so we know where it goes.
        if let currentElement = elementStack.last, currentElement == "URL" {
            let previousElement = elementStack[elementStack.count - 2]
            switch previousElement {
            case "PosterFrame":
                if let thumbnailString = String(data: CDATABlock, encoding: .utf8),
                    let thumbnailURL = URL(string: thumbnailString) {
//                    //Increase thumbnail size to 640x360
//                    NSInteger thumbWidth = 0;
//                    NSScanner *thumbScanner = [NSScanner scannerWithString:self.thumbnailURL];
//                    [thumbScanner scanUpToString:@"?w=" intoString:nil];
//                    [thumbScanner scanString:@"?w=" intoString:nil];
//                    [thumbScanner scanInteger:&thumbWidth];
//                    if (thumbWidth != 0 && thumbWidth < 640)
//                    {
//                        NSRange thumbSizeRange = [self.thumbnailURL rangeOfString:@"?w=" options:NSCaseInsensitiveSearch];
//                        if (thumbSizeRange.location != NSNotFound)
//                        {
//                            thumbSizeRange.length = self.thumbnailURL.length - thumbSizeRange.location;
//                            self.thumbnailURL = [self.thumbnailURL stringByReplacingCharactersInRange:thumbSizeRange withString:@"?w=640&h=360"];
//                            NSLog(@"DEBUG: Thumbnail URL changed: %@", self.thumbnailURL);
//                            if (self.verbose)
//                            [self addToLog:[NSString stringWithFormat:@"DEBUG: Thumbnail URL changed: %@", self.thumbnailURL] noTag:YES];
//                        }
//                    }

                    result.thumbnailURL = thumbnailURL
                }
                
            case "ClosedCaptioningURIs":
                if let subtitlesString = String(data: CDATABlock, encoding: .utf8),
                    let subtitlesURL = URL(string: subtitlesString) {
                    result.subtitleURL = subtitlesURL
                }
                
            case "MediaFile":
                if let mediaString = String(data: CDATABlock, encoding: .utf8) {
                    let URIparts = mediaString.split(separator: "_")
                    if URIparts.count == 3 {
                        let itvRate = URIparts[1] as NSString
                        // Strip off the "PC01" to get the ITV bitrate.
                        currentMediaFile?.itvRate = itvRate.substring(from: 4)
                    }
                    currentMediaFile?.url = mediaString
                }

            default:
                break
            }
        }
    }
    
    public func parserDidEndDocument(_ parser: XMLParser) {
        let message = "DEBUG: Metadata processed: seriesName=\(result.seriesName ?? "") dateString=\(result.transmissionDateString ?? "") episodeName=\(result.episodeTitle ?? "") episodeNumber=\(result.episodeNumber ?? "") thumbnail=\(result.thumbnailURL?.absoluteString ?? "") subtitleURL=\(result.subtitleURL?.absoluteString ?? "") authURL=\(result.authURL ?? "")"
        
        print(message)

        if let transmissionDateString = rawTransmitDate, let transmissionTimeString = rawTransmitTime  {
            dateFormatter.dateFormat = "dd LLLL yyyy"
            if let transmissionDate = dateFormatter.date(from: transmissionDateString) {
                dateFormatter.dateFormat = "HH:mm"
                if let transmissionTime = dateFormatter.date(from:transmissionTimeString) {
                    var thisYear = Calendar.current
                    thisYear.timeZone = dateFormatter.timeZone
                    let transmissionTimeComponents = thisYear.dateComponents([.hour, .minute], from:transmissionTime)
                    if let airDate = thisYear.date(byAdding: transmissionTimeComponents, to: transmissionDate, wrappingComponents: false) {
                        result.transmissionDate = airDate;
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                        result.transmissionDateString = dateFormatter.string(from:airDate)
                    }
                }
            }
        }

        if checkForRealPID, let crID = vodcridElement {
            let crIDElements = crID.split(separator: "/").map(String.init)
            if crIDElements.count > 1 {
                result.realPID = crIDElements.last
            }
        }

        for mediaEntry in mediaFileEntries {
            print("DEBUG: ITVMediaFileEntry: bitrate=\(mediaEntry.bitrate) itvRate=\(mediaEntry.itvRate) url=\(mediaEntry.url)")
        }
        
        var matchingEntries = mediaFileEntries.filter { itvRates.contains($0.itvRate) }
        
        if matchingEntries.count == 0 {
            matchingEntries = mediaFileEntries.filter { bitRates.contains($0.bitrate) }
        }
        
        if let mediaFile = matchingEntries.first {
            result.playPath = mediaFile.url
            print("DEBUG: Found matching entry - \(result.playPath!)")
        }

    }
}
