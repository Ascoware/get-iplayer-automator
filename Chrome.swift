
import ScriptingBridge

// MARK: ChromeGenericMethods
@objc public protocol ChromeGenericMethods {
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
    @objc optional func executeJavascript(_ javascript: String) -> Any // Execute a piece of javascript.
}

// MARK: ChromeApplication
@objc public protocol ChromeApplication: SBApplicationProtocol {
    @objc optional func windows() -> SBElementArray
    @objc optional var name: String { get } // The name of the application.
    @objc optional var frontmost: Int { get } // Is this the frontmost (active) application?
    @objc optional var version: String { get } // The version of the application.
    @objc optional func `open`(_ x: Any!) // Open a document.
    @objc optional func quit() // Quit the application.
    @objc optional func exists(_ x: Any!) // Verify if an object exists.
    @objc optional func bookmarkFolders()
    @objc optional var bookmarksBar: ChromeBookmarkFolder { get } // The bookmarks bar bookmark folder.
    @objc optional var otherBookmarks: ChromeBookmarkFolder { get } // The other bookmarks bookmark folder.
}
extension SBApplication: ChromeApplication {}

// MARK: ChromeWindow
@objc public protocol ChromeWindow: SBObjectProtocol, ChromeGenericMethods {
    @objc optional func tabs() -> SBElementArray
    @objc optional var name: String { get } // The full title of the window.
    @objc optional func id() // The unique identifier of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: NSRect { get } // The bounding rectangle of the window.
    @objc optional var closeable: Bool { get } // Whether the window has a close box.
    @objc optional var minimizable: Bool { get } // Whether the window can be minimized.
    @objc optional var minimized: Bool { get } // Whether the window is currently minimized.
    @objc optional var resizable: Bool { get } // Whether the window can be resized.
    @objc optional var visible: Bool { get } // Whether the window is currently visible.
    @objc optional var zoomable: Bool { get } // Whether the window can be zoomed.
    @objc optional var zoomed: Bool { get } // Whether the window is currently zoomed.
    @objc optional var activeTab: ChromeTab { get } // Returns the currently selected tab
    @objc optional var mode: Int { get } // Represents the mode of the window which can be 'normal' or 'incognito', can be set only once during creation of the window.
    @objc optional var activeTabIndex: Int { get } // The index of the active tab.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: NSRect) // The bounding rectangle of the window.
    @objc optional func setMinimized(_ minimized: Bool) // Whether the window is currently minimized.
    @objc optional func setVisible(_ visible: Bool) // Whether the window is currently visible.
    @objc optional func setZoomed(_ zoomed: Bool) // Whether the window is currently zoomed.
    @objc optional func setMode(_ mode: Int) // Represents the mode of the window which can be 'normal' or 'incognito', can be set only once during creation of the window.
    @objc optional func setActiveTabIndex(_ activeTabIndex: Int) // The index of the active tab.
}
extension SBObject: ChromeWindow {}

// MARK: ChromeTab
@objc public protocol ChromeTab: SBObjectProtocol, ChromeGenericMethods {
    @objc optional func id() // Unique ID of the tab.
    @objc optional var title: String { get } // The title of the tab.
    @objc optional var URL: String { get } // The url visible to the user.
    @objc optional var loading: Int { get } // Is loading?
    @objc optional func setURL(_ URL: String) // The url visible to the user.
}
extension SBObject: ChromeTab {}

// MARK: ChromeBookmarkFolder
@objc public protocol ChromeBookmarkFolder: SBObjectProtocol, ChromeGenericMethods {
    @objc optional func bookmarkFolders()
    @objc optional func bookmarkItems()
    @objc optional func id() // Unique ID of the bookmark folder.
    @objc optional var title: String { get } // The title of the folder.
    @objc optional var index: Int { get } // Returns the index with respect to its parent bookmark folder
    @objc optional func setTitle(_ title: String) // The title of the folder.
}
extension SBObject: ChromeBookmarkFolder {}

// MARK: ChromeBookmarkItem
@objc public protocol ChromeBookmarkItem: SBObjectProtocol, ChromeGenericMethods {
    @objc optional func id() // Unique ID of the bookmark item.
    @objc optional var title: String { get } // The title of the bookmark item.
    @objc optional var URL: String { get } // The URL of the bookmark.
    @objc optional var index: Int { get } // Returns the index with respect to its parent bookmark folder
    @objc optional func setTitle(_ title: String) // The title of the bookmark item.
    @objc optional func setURL(_ URL: String) // The URL of the bookmark.
}
extension SBObject: ChromeBookmarkItem {}

