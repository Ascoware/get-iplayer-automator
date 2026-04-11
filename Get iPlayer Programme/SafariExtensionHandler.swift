//
//  SafariExtensionHandler.swift
//  Get iPlayer Programme
//
//  Created by Scott Kovatch on 8/24/18.
//

import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {

    override func toolbarItemClicked(in window: SFSafariWindow) {
        print("[GiA Extension] toolbarItemClicked called")
        window.getActiveTab { tab in
            tab?.getActivePage { page in
                page?.getPropertiesWithCompletionHandler { properties in
                    guard let url = properties?.url else { return }
                    let title = properties?.title ?? ""

                    print("[GiA Extension] Button clicked for URL: \(url.absoluteString)")

                    var request = URLRequest(url: url)
                    request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    URLSession.shared.dataTask(with: request) { data, _, error in
                        if let error = error {
                            print("[GiA Extension] URLSession error: \(error)")
                            return
                        }
                        guard let data = data,
                              let html = String(data: data, encoding: .utf8) else {
                            print("[GiA Extension] Failed to decode HTML")
                            return
                        }
                        print("[GiA Extension] Fetched \(html.count) chars of HTML")

                        // Write payload to shared App Group container
                        let payload: [String: String] = [
                            "url": url.absoluteString,
                            "title": title,
                            "html": html
                        ]
                        if let containerURL = FileManager.default.containerURL(
                            forSecurityApplicationGroupIdentifier: "group.com.ascoware.get-iplayer-automator"),
                           let jsonData = try? JSONSerialization.data(withJSONObject: payload) {
                            let fileURL = containerURL.appendingPathComponent("pending_page.json")
                            try? jsonData.write(to: fileURL)
                            print("[GiA Extension] Wrote payload to \(fileURL.path)")
                        } else {
                            print("[GiA Extension] Failed to write payload — check App Group entitlement")
                        }

                        // Launch app if not running, then post Darwin notification
                        DispatchQueue.main.async {
                            NSWorkspace.shared.launchApplication(
                                withBundleIdentifier: "com.ascoware.getiPlayerAutomator",
                                options: .default,
                                additionalEventParamDescriptor: nil,
                                launchIdentifier: nil)
                        }
                        let notificationName = CFNotificationName(
                            "com.ascoware.get-iplayer-automator.newpage" as CFString)
                        CFNotificationCenterPostNotification(
                            CFNotificationCenterGetDarwinNotifyCenter(),
                            notificationName,
                            nil, nil, true)
                        print("[GiA Extension] Darwin notification posted")
                    }.resume()
                }
            }
        }
    }

    static let supportedURLPrefixes = [
        "https://www.bbc.co.uk/iplayer/episode/",
        "https://www.bbc.co.uk/iplayer/episodes/",
        "https://www.bbc.co.uk/radio/play/",
        "https://www.bbc.co.uk/sounds/play/",
        "https://www.bbc.co.uk/programmes/",
        "https://player.stv.tv/episode/",
    ]

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        window.getActiveTab { tab in
            tab?.getActivePage { page in
                page?.getPropertiesWithCompletionHandler { properties in
                    let url = properties?.url?.absoluteString ?? ""
                    let supported = Self.supportedURLPrefixes.contains { url.hasPrefix($0) }
                    validationHandler(supported, "")
                }
            }
        }
    }


}
