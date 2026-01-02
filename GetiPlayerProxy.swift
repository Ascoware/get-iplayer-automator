//
//  GetiPlayerProxy.swift
//  Get_iPlayer GUI
//
//  Created by Scott Kovatch on 6/29/25.
import Foundation
import AppKit

@objc public enum ProxyLoadError: Int {
case cancelled
case failed
case testFailed
}

@objc class GetiPlayerProxy: NSObject {
    private var proxyDict: [String: Any] = [:]
    private var currentIsSilent: Bool = false

    public override init() {}

    @objc public func loadProxyInBackground (
                                             silently silent: Bool,
                                             completion: @escaping (_ proxyDict: [String: Any]) -> Void
                                             )
    {        // Ensure this method is called on the main thread
        updateProxyLoadStatus(working: true, message: "Loading proxy settings...")
        proxyDict.removeAll()
        //                                   proxyDict["object"] = object
        self.currentIsSilent = silent

        let userDefaults = UserDefaults.standard
        let proxyOption = userDefaults.string(forKey: "Proxy")
        if proxyOption == "Custom" {
            let customProxy = userDefaults.string(forKey: "CustomProxy") ?? ""
            let proxyValue = customProxy.trimmingCharacters(in: .whitespacesAndNewlines)
            if proxyValue.isEmpty {
                if !currentIsSilent {
                    let alert = NSAlert()
                    alert.messageText = "Custom proxy setting was blank.\nDownloads may fail.\nDo you wish to continue?"
                    alert.addButton(withTitle: "No")
                    alert.addButton(withTitle: "Yes")
                    alert.alertStyle = .critical
                    if alert.runModal() == .alertFirstButtonReturn {
                        cancelProxyLoad(completion: completion)
                    } else {
                        failProxyLoad(completion: completion)
                    }
                } else {
                    failProxyLoad(completion: completion)
                }
            } else {
                proxyDict["proxy"] = HTTPProxy(string: proxyValue)
                finishProxyLoad(completion: completion)
            }
        } else {
            finishProxyLoad(completion: completion)
        }
    }

    private func cancelProxyLoad(completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        returnFromProxyLoad(error: ProxyLoadError.cancelled, completion: completion)
    }

    private func failProxyLoad(completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        returnFromProxyLoad(error: ProxyLoadError.failed, completion: completion)
    }

    private func finishProxyLoad(completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        if proxyDict["proxy"] != nil, UserDefaults.standard.bool(forKey: "TestProxy") {
            testProxyOnLoad(completion: completion)
            return
        }
        returnFromProxyLoad(error: nil, completion: completion)
    }

    private func testProxyOnLoad(completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        guard let proxy = proxyDict["proxy"] as? HTTPProxy else {
            finishProxyTest(completion: completion)
            return
        }

        guard let host = proxy.host, !host.isEmpty, !host.contains("(null)") else {
            if !currentIsSilent {
                let alert = NSAlert()
                alert.messageText = "Invalid proxy host.\nDownloads may fail.\nDo you wish to continue?"
                alert.addButton(withTitle: "No")
                alert.addButton(withTitle: "Yes")
                alert.informativeText = "Invalid proxy host: address=[\(proxy.host ?? "")] length=\(proxy.host?.count ?? 0)"
                alert.alertStyle = .critical
                if alert.runModal() == .alertFirstButtonReturn {
                    cancelProxyLoad(completion: completion)
                } else {
                    failProxyTest(completion: completion)
                }
            } else {
                failProxyLoad(completion: completion)
            }
            return
        }

        let testURL = UserDefaults.standard.string(forKey: "ProxyTestURL") ?? "http://www.google.com"
        let port: Int = proxy.port != 0 ? proxy.port : (proxy.type == kCFProxyTypeHTTPS as String ? 443 : 80)

        var proxySettings: [AnyHashable: Any] = [
            kCFNetworkProxiesHTTPEnable as String: 1,
            kCFNetworkProxiesHTTPProxy as String: host,
            kCFNetworkProxiesHTTPPort as String: port,
            kCFNetworkProxiesHTTPSEnable as String: 1,
            kCFNetworkProxiesHTTPSProxy as String: host,
            kCFNetworkProxiesHTTPSPort as String: port
        ]
        if let user = proxy.user {
            proxySettings[kCFProxyUsernameKey as String] = user
            proxySettings[kCFProxyPasswordKey as String] = proxy.password
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = proxySettings
        configuration.timeoutIntervalForResource = 30

        let session = URLSession(configuration: configuration)
        let url = URL(string: testURL)!
        let testingMessage = "Testing proxy (may take up to 30 seconds)..."
        updateProxyLoadStatus(working: true, message: testingMessage)

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let httpResponse = response as? HTTPURLResponse {
                self.proxyTestDidFinish(response: httpResponse, error: error, completion: completion)
            } else {
                self.failProxyTest(completion: completion)
            }
        }
        task.resume()
    }

    private func proxyTestDidFinish(response: HTTPURLResponse, error: Error?, completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        if response.statusCode != 200 {
            if !currentIsSilent {
                let alert = NSAlert()
                alert.messageText = "Proxy failed to load test page.\nDownloads may fail.\nDo you wish to continue?"
                alert.addButton(withTitle: "No")
                alert.addButton(withTitle: "Yes")
                let proxyURL = (proxyDict["proxy"] as? HTTPProxy)?.url.absoluteString ?? ""
                alert.informativeText = "Failed to load \(response.url?.absoluteString ?? "") within 30 seconds\nUsing proxy: \(proxyURL)\nError: \(error?.localizedDescription ?? "Unknown error")"
                alert.alertStyle = .critical
                if alert.runModal() == .alertFirstButtonReturn {
                    cancelProxyLoad(completion: completion)
                } else {
                    failProxyTest(completion: completion)
                }
            } else {
                failProxyTest(completion: completion)
            }
        } else {
            finishProxyTest(completion: completion)
        }
            }

    private func failProxyTest(completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        returnFromProxyLoad(error: ProxyLoadError.testFailed, completion: completion)
    }

    private func finishProxyTest(completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        returnFromProxyLoad(error: nil, completion: completion)
    }

    private func returnFromProxyLoad(error: ProxyLoadError?, completion: @escaping (_ proxyDict: [String: Any]) -> Void) {
        updateProxyLoadStatus(working: false, message: nil)
        if let error = error {
            proxyDict["error"] = error
        }
            completion(proxyDict)
            }

    private func updateProxyLoadStatus(working: Bool, message: String?) {
        let userInfo: [String: Any] = [
            "indeterminate": working,
            "animated": working
        ]
        NotificationCenter.default.post(name: Notification.Name("setPercentage"), object: self, userInfo: userInfo)
        NotificationCenter.default.post(name: Notification.Name("setCurrentProgress"), object: self, userInfo: ["string": message ?? ""])
    }
}

