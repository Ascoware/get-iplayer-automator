import ScriptingBridge

// MARK: MicrosoftEdgeGenericMethods
@objc public protocol MicrosoftEdgeGenericMethods {
    @objc optional func saveIn(_ in_: Any!, as: Any!) // Save an object.
    @objc optional func close() // Close a window.
    @objc optional func delete() // Delete an object.
    @objc optional func duplicateTo(_ to: Any!, withProperties: Any!) // Copy object(s) and put the copies at a new location.
    @objc optional func moveTo(_ to: Any!) // Move object(s) to a new location.
    @objc optional func print() // Print an object.
    @objc optional func reload() // Reload a tab.
    @objc optional func goBack() // Go Back (If Possible).
    @objc optional func goForward() // Go Forward (If Possible).
    @objc optional func selectAll() // Select all.
    @objc optional func cutSelection() // Cut selected text (If Possible).
    @objc optional func copySelection() // Copy text.
    @objc optional func pasteSelection() // Paste text (If Possible).
    @objc optional func undo() // Undo the last change.
    @objc optional func redo() // Redo the last change.
    @objc optional func stop() // Stop the current tab from loading.
    @objc optional func viewSource() // View the HTML source of the tab.
    @objc optional func executeJavascript(_ javascript: Any!) -> Any // Execute a piece of javascript.
}

// MARK: MicrosoftEdgeApplication
@objc public protocol MicrosoftEdgeApplication: SBApplicationProtocol {
    @objc optional func windows() -> SBElementArray
    @objc optional var name: Int { get } // The name of the application.
    @objc optional var frontmost: Int { get } // Is this the frontmost (active) application?
    @objc optional var version: Int { get } // The version of the application.
    @objc optional func `open`(_ x: Any!) // Open a document.
    @objc optional func quit() // Quit the application.
    @objc optional func exists(_ x: Any!) // Verify if an object exists.
    @objc optional func bookmarkFolders()
    @objc optional var bookmarksBar: MicrosoftEdgeBookmarkFolder { get } // The bookmarks bar bookmark folder.
    @objc optional var otherBookmarks: MicrosoftEdgeBookmarkFolder { get } // The other bookmarks bookmark folder.
}
extension SBApplication: MicrosoftEdgeApplication {}

// MARK: MicrosoftEdgeWindow
@objc public protocol MicrosoftEdgeWindow: SBObjectProtocol, MicrosoftEdgeGenericMethods {
    @objc optional func tabs()
    @objc optional var name: Int { get } // The full title of the window.
    @objc optional func id() // The unique identifier of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: Int { get } // The bounding rectangle of the window.
    @objc optional var closeable: Int { get } // Whether the window has a close box.
    @objc optional var minimizable: Int { get } // Whether the window can be minimized.
    @objc optional var minimized: Int { get } // Whether the window is currently minimized.
    @objc optional var resizable: Int { get } // Whether the window can be resized.
    @objc optional var visible: Int { get } // Whether the window is currently visible.
    @objc optional var zoomable: Int { get } // Whether the window can be zoomed.
    @objc optional var zoomed: Int { get } // Whether the window is currently zoomed.
    @objc optional var activeTab: MicrosoftEdgeTab { get } // Returns the currently selected tab
    @objc optional var mode: Int { get } // Represents the mode of the window which can be 'normal' or 'incognito', can be set only once during creation of the window.
    @objc optional var activeTabIndex: Int { get } // The index of the active tab.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: Int) // The bounding rectangle of the window.
    @objc optional func setMinimized(_ minimized: Int) // Whether the window is currently minimized.
    @objc optional func setVisible(_ visible: Int) // Whether the window is currently visible.
    @objc optional func setZoomed(_ zoomed: Int) // Whether the window is currently zoomed.
    @objc optional func setMode(_ mode: Int) // Represents the mode of the window which can be 'normal' or 'incognito', can be set only once during creation of the window.
    @objc optional func setActiveTabIndex(_ activeTabIndex: Int) // The index of the active tab.
}
extension SBObject: MicrosoftEdgeWindow {}

// MARK: MicrosoftEdgeTab
@objc public protocol MicrosoftEdgeTab: SBObjectProtocol, MicrosoftEdgeGenericMethods {
    @objc optional func id() // Unique ID of the tab.
    @objc optional var title: String { get } // The title of the tab.
    @objc optional var URL: String { get } // The url visible to the user.
    @objc optional var loading: Bool { get } // Is loading?
    @objc optional func setURL(_ URL: URL) // The url visible to the user.
}
extension SBObject: MicrosoftEdgeTab {}

// MARK: MicrosoftEdgeBookmarkFolder
@objc public protocol MicrosoftEdgeBookmarkFolder: SBObjectProtocol, MicrosoftEdgeGenericMethods {
    @objc optional func bookmarkFolders()
    @objc optional func bookmarkItems()
    @objc optional func id() // Unique ID of the bookmark folder.
    @objc optional var title: Int { get } // The title of the folder.
    @objc optional var index: Int { get } // Returns the index with respect to its parent bookmark folder
    @objc optional func setTitle(_ title: Int) // The title of the folder.
}
extension SBObject: MicrosoftEdgeBookmarkFolder {}

// MARK: MicrosoftEdgeBookmarkItem
@objc public protocol MicrosoftEdgeBookmarkItem: SBObjectProtocol, MicrosoftEdgeGenericMethods {
    @objc optional func id() // Unique ID of the bookmark item.
    @objc optional var title: Int { get } // The title of the bookmark item.
    @objc optional var URL: Int { get } // The URL of the bookmark.
    @objc optional var index: Int { get } // Returns the index with respect to its parent bookmark folder
    @objc optional func setTitle(_ title: Int) // The title of the bookmark item.
    @objc optional func setURL(_ URL: Int) // The URL of the bookmark.
}
extension SBObject: MicrosoftEdgeBookmarkItem {}

