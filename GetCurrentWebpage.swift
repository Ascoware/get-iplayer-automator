//  Converted with Swiftify v1.0.6472 - https://objectivec2swift.com/
//
//  GetCurrentWebpageController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

import ScriptingBridge
import SwiftyJSON
import Kanna

@objcMembers public class GetCurrentWebpage : NSObject {
    
    private class func extractMetadata(url: String, tabTitle: String, pageSource: String) -> Programme {
        var show = Programme()

        if url.hasPrefix("https://www.bbc.co.uk/iplayer/episode/") {
            // PID is always the second-to-last element in the URL.
            if let nsUrl = URL(string: url) {
                show.pid = nsUrl.deletingLastPathComponent().lastPathComponent
            }

            let nameScanner = Scanner(string: tabTitle)
            nameScanner.scanString("BBC iPlayer - ")
            show.showName = nameScanner.scanUpToString( " - ") ?? ""
            show.tvNetwork = "BBC"
        } else if url.hasPrefix("https://www.bbc.co.uk/iplayer/episodes/") {
            // https://www.bbc.co.uk/iplayer/episodes/p00yzlr0/line-of-duty?seriesId=b01k9pm3
            // It looks like a PID, but it's a 'brand ID' The real URL is embedded in an anchor tag.
            if let htmlPage = try? HTML(html: pageSource, encoding: .utf8) {
                // There should only be one 'video' element.
                if let anchorElement = htmlPage.at_xpath("//a[@class='play-cta__inner play-cta__inner--do-not-wrap play-cta__inner--link']") {
                    let showURLString = anchorElement.at_xpath("//@href")?.text ?? ""
                    if let pageURL = URL(string: url), let showURL = URL(string: showURLString, relativeTo: pageURL) {
                        show.pid = showURL.deletingLastPathComponent().lastPathComponent
                        show.url = showURL.absoluteString
                    }
                }
            }

            let nameScanner = Scanner(string: tabTitle)
            nameScanner.scanString("BBC iPlayer - ")
            show.showName = nameScanner.scanUpToString( " - ") ?? ""
            show.tvNetwork = "BBC"
        } else if url.hasPrefix("https://www.bbc.co.uk/radio/play/") || url.hasPrefix("https://www.bbc.co.uk/sounds/play/") {
            // PID is always the last element in the URL.
            if let nsUrl = URL(string: url) {
                show.pid = nsUrl.lastPathComponent
                show.tvNetwork = "BBC"
            }

            show.radio = true
            // Program title is buried in the page HTML.
            
        } else if url.hasPrefix("https://www.bbc.co.uk/programmes/") {
            // Search the page to see if it is an episode or a series page. If we don't the PID inside
            // a bbcProgrammes element, it's a series page and we can't use it (though we might want to try
            // adding it with recursive-pid)
            guard let htmlPage = try? HTML(html: pageSource, encoding: .utf8) else {
                return show
            }

            var infoDicts: [JSON] = []

            for showInfo in htmlPage.xpath("//script[@type='application/ld+json']") {
                guard let content = showInfo.content, !content.isEmpty else {
                    continue
                }

                let infoJSON = JSON(parseJSON: content)

                if infoJSON["@type"].exists() {
                    infoDicts.append(infoJSON)
                } else {
                    let graphBlocks = infoJSON["@graph"].arrayValue
                    for block in graphBlocks {
                        if block["@type"].exists() {
                            infoDicts.append(block)
                        }
                    }
                }
            }

            // Search all of the show infos for something we know about.
            for infoDict in infoDicts {
                let contentType = infoDict["@type"]

                if contentType == "BreadcrumbList" {
                    continue
                }

                switch contentType {
                case "TVEpisode", "@TVEpisode", "@RadioEpisode", "RadioEpisode", "Clip":
                    show.pid = infoDict["identifier"].stringValue
                    show.seriesName = infoDict["partOfSeries"]["name"].stringValue
                    show.episodeName = infoDict["name"].stringValue
                    show.url = infoDict["url"].stringValue
                    show.desc = infoDict["description"].stringValue
                    show.showName = !show.seriesName.isEmpty ? show.seriesName : show.episodeName

                    if ["@RadioEpisode", "RadioEpisode"].contains(contentType.stringValue) {
                        show.radio = true
                    }

                    break

                default:
                    continue
                }
            }

            if show.pid.isEmpty {
                let invalidPage = NSAlert()
                invalidPage.addButton(withTitle: "OK")
                invalidPage.messageText = "Series Page Found: \(url)"
                invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an iPlayer episode page or programme clip page. Get iPlayer Automator doesn't support downloading all available shows from a series."
                invalidPage.alertStyle = .warning
                invalidPage.runModal()
                return show
            }
        } else if url.hasPrefix("https://www.itv.com/hub/") {
            show = ITVMetadataExtractor.getShowMetadata(htmlPageContent: pageSource)
        }

        return show
    }
    
    public class func getCurrentWebpage(_ logger: LogController) -> Programme? {
        //Get Default Browser
        guard let browser = UserDefaults.standard.object(forKey: "DefaultBrowser") as? String else {
            return nil
        }

        var newProgram: Programme? = nil

        //Prepare Alert in Case the Browser isn't Open
        let browserNotOpen = NSAlert()
        browserNotOpen.addButton(withTitle: "OK")
        browserNotOpen.messageText = "\(browser) is not open."
        browserNotOpen.informativeText = "Please ensure your browser is running and has at least one window open."
        browserNotOpen.alertStyle = .warning
        
        //Get URL
        switch (browser) {
        case "Safari":
            var safariRunning: SafariApplication? = nil
            let safariTechPreview = SBApplication(bundleIdentifier: "com.apple.SafariTechnologyPreview")
            
            if safariTechPreview?.isRunning ?? false {
                safariRunning = safariTechPreview
            } else {
                let safariDefault = SBApplication(bundleIdentifier: "com.apple.Safari")
                if safariDefault?.isRunning ?? false {
                    safariRunning = safariDefault
                }
            }
            
            guard let safari = safariRunning, let safariWindows = safari.windows?().compactMap({ $0 as? SafariWindow }) else {
                browserNotOpen.runModal()
                return nil
            }

            let orderedWindows = safariWindows.sorted { $0.index! < $1.index! }
            if let frontWindow = orderedWindows.first, let tab = frontWindow.currentTab, let url = tab.URL, let name = tab.name, let source = tab.source {
                newProgram = extractMetadata(url: url, tabTitle: name, pageSource: source)
            }
            break

        case "Chrome", "Microsoft Edge", "Vivaldi", "Brave":
            // All WebKit browsers have the same AppleScript support.
            // We just need to find the right bundle ID.
            let mapping = [
                "Chrome" : "com.google.Chrome",
                "Microsoft Edge" : "com.microsoft.edgemac",
                "Vivaldi" : "com.vivaldi.Vivaldi",
                "Brave" : "com.brave.Browser"]

            guard let bundleID = mapping[browser], let chrome : ChromeApplication = SBApplication(bundleIdentifier: bundleID), chrome.isRunning, let chromeWindows = chrome.windows?().compactMap({ $0 as? ChromeWindow }) else {
                browserNotOpen.runModal()
                return nil
            }

            let orderedWindows = chromeWindows.sorted { $0.index! < $1.index! }
            if let frontWindow = orderedWindows.first, let tab = frontWindow.activeTab, let url = tab.URL, let title = tab.title,
               let source = tab.executeJavascript?("document.documentElement.outerHTML") as? String {
                newProgram = extractMetadata(url: url, tabTitle: title, pageSource: source)
            }

            break

        default:
            let unsupportedBrowser = NSAlert()
            unsupportedBrowser.messageText = "Uh, something went horribly wrong."
            unsupportedBrowser.addButton(withTitle: "OK")
            unsupportedBrowser.informativeText = "Get iPlayer Automator only works with Safari and Chrome. We shouldn't be here; please file a bug."
            unsupportedBrowser.runModal()
            return nil
        }
        
        // If we have a PID we can search for it.
        guard let pid = newProgram?.pid, !pid.isEmpty else {
            let invalidPage = NSAlert()
            invalidPage.addButton(withTitle: "OK")
            invalidPage.messageText = "Programme Page Not Found"
            invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an iPlayer episode page or ITV Hub episode page."
            invalidPage.alertStyle = .warning
            invalidPage.runModal()
            return nil
        }

        newProgram?.status = "Processing..."
        newProgram?.performSelector(inBackground: #selector(Programme.getName), with: nil)
        return newProgram
    }
    
}
