//  Converted with Swiftify v1.0.6472 - https://objectivec2swift.com/
//
//  GetCurrentWebpageController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 8/3/14.
//
//

import ScriptingBridge

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
            // TODO: Get the series/episode info from the tail.
        } else if url.hasPrefix("https://www.bbc.co.uk/radio/play/") || url.hasPrefix("https://www.bbc.co.uk/sounds/play/") {
            // PID is always the last element in the URL.
            if let nsUrl = URL(string: url) {
                show.pid = nsUrl.lastPathComponent
                show.tvNetwork = "BBC"
            }

            show.radio = true
            // Program title is buried in the page HTML.
            
        } else if url.hasPrefix("https://www.bbc.co.uk/programmes/") {
            // PID is the last element in the URL, but it could be a program or series page.
            if let nsUrl = URL(string: url) {
                show.pid = nsUrl.lastPathComponent
                show.tvNetwork = "BBC"

                // Search the page to see if it is an episode or a series page. If we don't the PID inside
                // a bbcProgrammes element, it's a series page and we can't use it (though we might want to try
                // adding it with recursive-pid)
                let scanner = Scanner(string: pageSource)
                scanner.scanUpTo("\"@type\":\"TVEpisode\",\"identifier\":\"\(show.pid)\"", into: nil)
                if scanner.isAtEnd {
                    scanner.scanLocation = 0
                    scanner.scanUpTo("\"@type\":\"RadioEpisode\",\"identifier\":\"\(show.pid)\"", into: nil)
                    
                    // Radio shows and clips will be routed to Music.app.
                    show.radio = true
                    
                    if scanner.isAtEnd {
                        scanner.scanLocation = 0
                        scanner.scanUpTo("bbcProgrammes.programme = { pid : '\(show.pid)', type : 'clip' }", into: nil)
                    }
                }
                
                if scanner.isAtEnd {
                    let invalidPage = NSAlert()
                    invalidPage.addButton(withTitle: "OK")
                    invalidPage.messageText = "Series Page Found: \(url)"
                    invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an iPlayer episode page or programme clip page. Get iPlayer Automator doesn't support downloading all available shows from a series."
                    invalidPage.alertStyle = .warning
                    invalidPage.runModal()
                    return show
                }
            }

        } else if url.hasPrefix("https://www.itv.com/hub/") {
            show = ITVMetadataExtractor.getShowMetadata(htmlPageContent: pageSource)

            if let nsUrl = URL(string: url) {
                show.pid = nsUrl.lastPathComponent
            }
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
        if (browser == "Safari") {
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
        } else if (browser == "Chrome") {
            guard let chrome : ChromeApplication = SBApplication(bundleIdentifier: "com.google.Chrome"), chrome.isRunning, let chromeWindows = chrome.windows?().compactMap({ $0 as? ChromeWindow }) else {
                browserNotOpen.runModal()
                return nil
            }

            let orderedWindows = chromeWindows.sorted { $0.index! < $1.index! }
            if let frontWindow = orderedWindows.first, let tab = frontWindow.activeTab, let url = tab.URL, let title = tab.title,
               let source = tab.executeJavascript?("document.documentElement.outerHTML") as? String {
                newProgram = extractMetadata(url: url, tabTitle: title, pageSource: source)
            }
        } else if (browser == "Microsoft Edge") {
            guard let edge : MicrosoftEdgeApplication = SBApplication(bundleIdentifier: "com.microsoft.edgemac"), edge.isRunning, let edgeWindows =
                edge.windows?().compactMap({ $0 as? MicrosoftEdgeWindow }) else {
                browserNotOpen.runModal()
                return nil
            }

            let orderedWindows = edgeWindows.sorted { $0.index! < $1.index! }
            if let frontWindow = orderedWindows.first, let tab = frontWindow.activeTab, let url = tab.URL, let title = tab.title,
               let source = tab.executeJavascript?("document.documentElement.outerHTML") as? String {
                newProgram = extractMetadata(url: url, tabTitle: title, pageSource: source)
            }
        } else {
            let unsupportedBrowser = NSAlert()
            unsupportedBrowser.messageText = "Uh, something went horribly wrong."
            unsupportedBrowser.addButton(withTitle: "OK")
            unsupportedBrowser.informativeText = "Get iPlayer Automator only works with Safari and Chrome. We shouldn't be here; please file a bug."
            unsupportedBrowser.runModal()
            return nil
        }
        
        // If we have a PID we can search for it.
        if newProgram?.pid == nil {
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
