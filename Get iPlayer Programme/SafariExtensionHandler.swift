//
//  SafariExtensionHandler.swift
//  Get iPlayer Programme
//
//  Created by Scott Kovatch on 8/24/18.
//

import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        page.getPropertiesWithCompletionHandler { properties in
            DDLogDebug("The extension received a message (\(messageName)) from a script injected into (\(String(describing: properties?.url))) with userInfo (\(userInfo ?? [:]))")
        }
    }
    
    override func messageReceivedFromContainingApp(withName messageName: String, userInfo: [String : Any]? = nil) {
        DDLogDebug("Got a message!! \(messageName)" )
    }
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
        DDLogDebug("The extension's toolbar item was clicked")
        
        window.getActiveTab() { tab in
            if let tab = tab {
                tab.getActivePage() { page in
                    if let page = page {
                        page.getPropertiesWithCompletionHandler { pageProperties in
                            if let properties = pageProperties {
                                let showURL = properties.url?.absoluteString
                                print (showURL ?? "(null)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

}
