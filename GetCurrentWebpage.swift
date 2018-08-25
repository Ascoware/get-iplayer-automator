//  Converted with Swiftify v1.0.6472 - https://objectivec2swift.com/
//
//  GetCurrentWebpageController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

import Kanna
import ScriptingBridge
import SafariServices

@objcMembers public class GetCurrentWebpage : NSObject, SBApplicationDelegate {
    
    public func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
        print("error handling event \(error)")
        return nil
    }
    
    public class func getCurrentWebpage(_ logger: LogController) -> Programme? {
        //Get Default Browser
        guard let browser = UserDefaults.standard.object(forKey: "DefaultBrowser") as? String else {
            return nil
        }
        
        // Parsed show name from tab title
        var newShowName: String? = nil
        
        // URL of first tab with a valid show.
        var showURL: String? = nil
        
        // Page HTML source for scraping
        var source: String? = nil
        
        //Prepare Alert in Case the Browser isn't Open
        let browserNotOpen = NSAlert()
        browserNotOpen.addButton(withTitle: "OK")
        browserNotOpen.messageText = "\(browser) is not open."
        browserNotOpen.informativeText = "Please ensure your browser is running and has at least one window open."
        browserNotOpen.alertStyle = .warning
        
        //Get URL
        if (browser == "Safari") {
            

            guard let safari: SafariApplication = SBApplication(bundleIdentifier: "com.apple.Safari") else {
                return nil
            }

            safari.delegate = GetCurrentWebpage()

            guard safari.isRunning, let safariWindows = safari.windows?() else {
                browserNotOpen.runModal()
                return nil
            }

            let orderedWindows = safariWindows.compactMap { $0 as? SafariWindow }.sorted { $0.index! < $1.index! }

            for window: SafariWindow in orderedWindows {
                if let tab = window.currentTab, let url = tab.URL, let name = tab.name {
                    if url.hasPrefix("http://www.bbc.co.uk/iplayer/episode/") || url.hasPrefix("http://bbc.co.uk/iplayer/episode/") || url.hasPrefix("http://bbc.co.uk/sport") || url.hasPrefix("https://www.bbc.co.uk/iplayer/episode/") || url.hasPrefix("https://bbc.co.uk/iplayer/episode/") || url.hasPrefix("https://bbc.co.uk/sport") {
                        let nameScanner = Scanner(string: name)
                        nameScanner.scanString("BBC iPlayer - ", into: nil)
                        nameScanner.scanString("BBC Sport - ", into: nil)
                        newShowName = nameScanner.scanUpToString("kjklgfdjfgkdlj")
                        showURL = url
                    }
                    else if url.hasPrefix("http://www.bbc.co.uk/programmes/") || url.hasPrefix("https://www.bbc.co.uk/programmes/") {
                        let nameScanner = Scanner(string: name)
                        nameScanner.scanUpTo("- ", into: nil)
                        nameScanner.scanString("- ", into: nil)
                        newShowName = nameScanner.scanUpToString("kjklgfdjfgkdlj")
                        showURL = url
                        source = tab.source
                    }
                    else if url.hasPrefix("http://www.itv.com/hub/") || url.hasPrefix("https://www.itv.com/hub/") {
                        source = tab.source
                        newShowName = name.replacingOccurrences(of: " - ITV Hub", with: "")
                        showURL = url
                    }
                }

                if showURL != nil {
                    break
                }
            }

            // If we didn't find a page that conforms to our expectations, try the front-most tab of the
            // front-most page. It might have something we can use.
            if showURL == nil, orderedWindows.count > 0 {
                showURL = orderedWindows[0].currentTab?.URL
                source = orderedWindows[0].currentTab?.source
            }
            
        } else if (browser == "Chrome") {
            
            guard let chrome : ChromeApplication = SBApplication(bundleIdentifier: "com.google.Chrome") else {
                return nil
            }
            
            chrome.delegate = GetCurrentWebpage()
           
            guard chrome.isRunning, let chromeWindows = chrome.windows?().compactMap({ $0 as? ChromeWindow }) else {
                browserNotOpen.runModal()
                return nil
            }

            let orderedWindows = chromeWindows.sorted { $0.index! < $1.index! }
            for window: ChromeWindow in orderedWindows {
                if let tab = window.activeTab, let url = tab.URL, let title = tab.title {
                    if url.hasPrefix("http://www.bbc.co.uk/iplayer/episode/") || url.hasPrefix("http://bbc.co.uk/iplayer/episode/") || url.hasPrefix("https://www.bbc.co.uk/iplayer/episode/") || url.hasPrefix("https://bbc.co.uk/iplayer/episode/") || url.hasPrefix("https://bbc.co.uk/iplayer/episode/") {
                        let nameScanner = Scanner(string: title)
                        nameScanner.scanString("BBC iPlayer - ", into: nil)
                        nameScanner.scanString("BBC Sport - ", into: nil)
                        newShowName = nameScanner.scanUpToString("kjklgfdjfgkdlj")
                        showURL = url
                    } else if url.hasPrefix("http://www.bbc.co.uk/programmes/") || url.hasPrefix("https://www.bbc.co.uk/programmes/") {
                        let nameScanner = Scanner(string: title)
                        nameScanner.scanUpTo("- ", into: nil)
                        nameScanner.scanString("- ", into: nil)
                        newShowName = nameScanner.scanUpToString("kjklgfdjfgkdlj")
                        showURL = url
                        source = tab.executeJavascript?("document.documentElement.outerHTML") as? String
                    }
                    else if url.hasPrefix("http://www.itv.com/hub/") || url.hasPrefix("https://www.itv.com/hub/") {
                        source = tab.executeJavascript?("document.getElementsByTagName('html')[0].innerHTML") as? String
                        newShowName = title.replacingOccurrences(of: " - ITV Hub", with: "")
                        showURL = url
                    }
                }

                if showURL != nil {
                    break
                }
            }
            
            // If we didn't find a page that conforms to our expectations, try the front-most tab of the
            // front-most page. It might have something we can use.
            if showURL == nil, orderedWindows.count > 0 {
                showURL = orderedWindows[0].activeTab?.URL
                source = orderedWindows[0].activeTab?.executeJavascript?("document.documentElement.outerHTML") as? String
            }
            
        } else {
            let unsupportedBrowser = NSAlert()
            unsupportedBrowser.messageText = "Get iPlayer Automator currently only supports Safari and Chrome."
            unsupportedBrowser.addButton(withTitle: "OK")
            unsupportedBrowser.informativeText = "Please change your preferred browser in the preferences and try again."
            unsupportedBrowser.runModal()
            return nil
        }
        
        //Process URL
        guard let url = showURL else {
            return nil
        }
        
        if url.hasPrefix("http://www.bbc.co.uk/iplayer/episode/") || url.hasPrefix("https://www.bbc.co.uk/iplayer/episode/") {
            let urlScanner = Scanner(string: url)
            urlScanner.scanUpTo("/episode/", into: nil)
            if urlScanner.isAtEnd {
                urlScanner.scanLocation = 0
                urlScanner.scanUpTo("/console/", into: nil)
            }
            urlScanner.scanString("/", into: nil)
            urlScanner.scanUpTo("/", into: nil)
            urlScanner.scanString("/", into: nil)
            if let pid = urlScanner.scanUpToString("/"), let newShowName = newShowName {
                let newProg = Programme()
                newProg.pid = pid
                newProg.showName = newShowName
                newProg.status = "Processing..."
                newProg.performSelector(inBackground: #selector(Programme.getName), with: nil)
                return newProg
            }
        }
        else if url.hasPrefix("http://www.bbc.co.uk/programmes/") || url.hasPrefix("https://www.bbc.co.uk/programmes/") {
            let urlScanner = Scanner(string: url)
            urlScanner.scanUpTo("/programmes/", into: nil)
            urlScanner.scanString("/", into: nil)
            urlScanner.scanUpTo("/", into: nil)
            urlScanner.scanString("/", into: nil)
            
            if let pid = urlScanner.scanUpToString("#"), let source = source {
                let scanner = Scanner(string: source)
                scanner.scanUpTo("bbcProgrammes.programme = { pid : '\(pid)', type : 'episode' }", into: nil)
                if scanner.isAtEnd {
                    scanner.scanLocation = 0
                    scanner.scanUpTo("bbcProgrammes.programme = { pid : '\(pid)', type : 'clip' }", into: nil)
                }
                if scanner.isAtEnd {
                    let invalidPage = NSAlert()
                    invalidPage.addButton(withTitle: "OK")
                    invalidPage.messageText = "Invalid Page: \(url)"
                    invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an iPlayer episode page or programme clip page."
                    invalidPage.alertStyle = .warning
                    invalidPage.runModal()
                    return nil
                }

                let newProg = Programme()
                newProg.pid = pid
                newProg.showName = newShowName ?? ""
                newProg.status = "Processing..."
                newProg.performSelector(inBackground: #selector(Programme.getName), with: nil)
                return newProg
            }
        } else if url.hasPrefix("http://www.itv.com/hub/") || url.hasPrefix("https://www.itv.com/hub/") {
            var seriesName = ""
            var episode = ""
            var episodeID = ""
            var showDescription = ""
            var timeAired: Date? = nil
            var episodeNumber = 0
            var seriesNumber = 0
            let longDateFormatter = DateFormatter()
            longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)
            longDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
            
            let shortDateFormatter = DateFormatter()
            shortDateFormatter.dateFormat = "EEE MMM dd"
            shortDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let source = source, let htmlPage = try? HTML(html: source, encoding: .utf8) {
                // There should only be one 'video' element.
                if let videoElement = htmlPage.at_xpath("//div[@id='video']") {
                    seriesName = videoElement.at_xpath("//@data-video-title")?.text ?? "Unknown"
                    episode = videoElement.at_xpath("//@data-video-episode")?.text ?? ""
                    episodeID = videoElement.at_xpath("//@data-video-episode-id")?.text ?? ""
                }
                
                if let descriptionElement = htmlPage.at_xpath("//script[@id='json-ld']") {
                    if let descriptionJSON = descriptionElement.content {
                        if let data = descriptionJSON.data(using: .utf8) {
                            if let descJSONDict = try? JSONSerialization.jsonObject(with: data) as? [String : Any] {
                                showDescription = descJSONDict? ["description"] as? String ?? "None available"
                                episodeNumber = descJSONDict?["episodeNumber"] as? Int ?? 0
                                if let seriesDict = descJSONDict?["partOfSeason"] as? [String: Any] {
                                    seriesNumber = seriesDict["seasonNumber"] as? Int ?? 0
                                }
                                
                                episode = descJSONDict? ["name"] as? String ?? ""
                                
                                if let potentialActionDict = descJSONDict?["potentialAction"] as? [[String: Any]],
                                    let expectsAcceptanceDict = potentialActionDict[0]["expectsAcceptanceOf"] as? [[String: Any]],
                                    let availabilityTime = expectsAcceptanceDict[0]["availabilityStarts"] as? String {
                                    timeAired = longDateFormatter.date(from:availabilityTime)
                                }
                            }
                        }
                    }
                }
                
            }
            
            let productionId = URL(string: url)?.lastPathComponent
            
            if episodeNumber == 0 && seriesNumber == 0 && !episodeID.isEmpty {
                // At this point all we have left is the production ID.
                // A series number doesn't make much sense, so just parse out an episode number.
                let programIDElements = episodeID.split(separator: "/")
                if let lastElement = programIDElements.last, let intLastElement = Int(lastElement) {
                    episodeNumber = intLastElement
                }
            }
            
            // Save off the pieces we care about.
            let programme = Programme()
            programme.pid = productionId ?? ""
            programme.processedPID = true
            programme.showName = newShowName ?? ""
            programme.episode = episodeNumber
            programme.season = seriesNumber
            programme.seriesName = seriesName
            programme.desc = showDescription
            programme.url = url
            programme.tvNetwork = "ITV Player"

            if !episode.isEmpty {
                programme.episodeName = episode
            } else if let timeAired = timeAired {
                let shortDate = shortDateFormatter.string(from: timeAired)
                programme.lastBroadcastString = shortDate
                programme.episodeName = shortDate
            }
            
            if let timeAired = timeAired {
                programme.standardizedAirDate = longDateFormatter.string(from: timeAired)
                programme.lastBroadcast = timeAired
            }
            
            return programme
            
//            add(toLog:"INFO: Metadata processed.", noTag:true)
//
//            var progname: String? = nil
//            var productionId: String? = nil
//            var title: String? = nil
//            var desc: String? = nil
//            var timeString: String? = nil
//            var seriesnum: Int = 0
//            var episodenum: Int = 0
//            progname = newShowName
//            var scanner = Scanner(string: source!)
//            scanner.scanUpTo("<meta property=\"og:title\" content=\"", into: nil)
//            scanner.scanString("<meta property=\"og:title\" content=\"", into: nil)
//            scanner.scanUpTo("\"", into: title as? AutoreleasingUnsafeMutablePointer<NSString?>)
//            if title != nil {
//                progname = title?.decodingHTMLEntities()
//            }
//            scanner.scanUpTo("<meta property=\"og:description\" content=\"", into: nil)
//            scanner.scanString("<meta property=\"og:description\" content=\"", into: nil)
//            scanner.scanUpTo("\"", into: desc as? AutoreleasingUnsafeMutablePointer<NSString?>)
//            let dateTimePrefix = "episode-info__meta-item--pipe-after\"><time datetime=\""
//            scanner.scanUpTo(dateTimePrefix, into: nil)
//            scanner.scanString(dateTimePrefix, into: nil)
//            scanner.scanUpTo("\"", into: timeString as? AutoreleasingUnsafeMutablePointer<NSString?>)
//            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
//            dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0) as? TimeZone ?? TimeZone()
//            let parsedDate: Date? = dateFormatter.date(from: timeString!)
//            let shortDate = DateFormatter.localizedString(from: parsedDate!, dateStyle: .medium, timeStyle: .none)
//            if !(progname || !productionId) {
//                let invalidPage = NSAlert()
//                invalidPage.addButton(withTitle: "OK")
//                invalidPage.messageText = "Invalid Page: \(url)"
//                invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an ITV Hub episode page."
//                invalidPage.alertStyle = NSWarningAlertStyle as? NSAlert.Style ?? NSAlert.Style(rawValue: 0)!
//                invalidPage.runModal()
//                return nil
//            }
//            var pid: String? = productionId?.removingPercentEncoding
//            let showName = "\(progname) - \(pid)"
//            let newProg = Programme()
//            newProg.pid = pid
//            newProg.showName = showName
//            newProg.tvNetwork = "ITV Player"
//            newProg.processedPID = true
//            newProg.url = url
//            newProg.lastBroadcastString = shortDate
//            newProg.lastBroadcast = parsedDate
//            newProg.episodeName = shortDate
//            scanner = Scanner(string: title!)
//            scanner.scanUpTo("Series ", into: nil)
//            scanner.scanString("Series ", into: nil)
//            scanner.scanInt(seriesnum as? UnsafeMutablePointer<Int>)
//            scanner.scanLocation = 0
//            scanner.scanUpTo("Episode ", into: nil)
//            scanner.scanString("Episode ", into: nil)
//            scanner.scanInt(episodenum as? UnsafeMutablePointer<Int>)
//            scanner = Scanner(string: desc!)
//            if seriesnum == 0 {
//                scanner.scanUpTo("Series ", into: nil)
//                scanner.scanString("Series ", into: nil)
//                scanner.scanInt(seriesnum as? UnsafeMutablePointer<Int>)
//            }
//            if episodenum == 0 {
//                scanner.scanLocation = 0
//                scanner.scanUpTo("Episode ", into: nil)
//                scanner.scanString("Episode ", into: nil)
//                scanner.scanInt(episodenum as? UnsafeMutablePointer<Int>)
//            }
//            newProg.season = seriesnum
//            newProg.episode = episodenum
//            return newProg
        }
        else {
            let invalidPage = NSAlert()
            invalidPage.addButton(withTitle: "OK")
            invalidPage.messageText = "Invalid Page: \(url)"
            invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an iPlayer episode page or ITV Hub episode page."
            invalidPage.alertStyle = .warning
            invalidPage.runModal()
            return nil
        }

        return nil
    }
    
}
