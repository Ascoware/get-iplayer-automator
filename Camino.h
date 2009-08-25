/*
 * Camino.h
 */

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>


@class CaminoItem, CaminoWindow, CaminoApplication, CaminoBrowserWindow, CaminoTab, CaminoBookmarkItem, CaminoBookmarkFolder, CaminoBookmark;



/*
 * Standard Suite
 */

// A scriptable object.
@interface CaminoItem : SBObject

@property (copy) NSDictionary *properties;  // All of the object's properties.

- (void) close;  // Close an object.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy object(s) and put the copies at a new location.
- (BOOL) exists;  // Verify if an object exists.
- (void) moveTo:(SBObject *)to;  // Move object(s) to a new location.
- (void) saveIn:(NSURL *)in_ as:(NSString *)as;  // Save an object.

@end

// A window.
@interface CaminoWindow : SBObject

@property (copy) NSString *name;  // The full title of the window.
- (NSNumber *) id;  // The unique identifier of the window.
@property NSRect bounds;  // The bounding rectangle of the window.
@property (readonly) BOOL closeable;  // Whether the window has a close box.
@property (readonly) BOOL titled;  // Whether the window has a title bar.
@property (copy) NSNumber *index;  // The index of the window in the back-to-front window ordering.
@property (readonly) BOOL floating;  // Whether the window floats.
@property (readonly) BOOL miniaturizable;  // Whether the window can be miniaturized.
@property BOOL miniaturized;  // Whether the window is currently miniaturized.
@property (readonly) BOOL modal;  // Whether the window is the application's current modal window.
@property (readonly) BOOL resizable;  // Whether the window can be resized.
@property BOOL visible;  // Whether the window is currently visible.
@property (readonly) BOOL zoomable;  // Whether the window can be zoomed.
@property BOOL zoomed;  // Whether the window is currently zoomed.

- (void) close;  // Close an object.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy object(s) and put the copies at a new location.
- (BOOL) exists;  // Verify if an object exists.
- (void) moveTo:(SBObject *)to;  // Move object(s) to a new location.
- (void) saveIn:(NSURL *)in_ as:(NSString *)as;  // Save an object.

@end



/*
 * Camino Suite
 */

// The application's top-level scripting object.
@interface CaminoApplication : SBApplication

- (SBElementArray *) windows;
- (SBElementArray *) browserWindows;
- (SBElementArray *) bookmarkFolders;

@property (copy, readonly) NSString *name;  // The name of the application.
@property (readonly) BOOL frontmost;  // Is this the frontmost (active) application?
@property (copy, readonly) NSString *version;  // The version of the application.
@property (copy, readonly) CaminoBookmarkFolder *bookmarkMenuCollection;
@property (copy, readonly) CaminoBookmarkFolder *bookmarkBarCollection;
@property (copy, readonly) CaminoBookmarkFolder *topTenCollection;
@property (copy, readonly) CaminoBookmarkFolder *bonjourCollection;
@property (copy, readonly) CaminoBookmarkFolder *addressBookCollection;

- (void) open:(NSURL *)x;  // Open an object.
- (void) print:(NSURL *)x;  // Print an object.
- (void) quit;  // Quit an application.
- (void) openLocation:(NSString *)x;  // Open a URL in Camino.

@end

@interface CaminoBrowserWindow : CaminoWindow

- (SBElementArray *) tabs;

@property (copy) CaminoTab *currentTab;  // The tab currently selected in the window


@end

@interface CaminoTab : SBObject

@property (copy, readonly) NSString *title;  // The tab's displayed title
@property (copy) NSString *URL;  // The tab's current URL

- (void) close;  // Close an object.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy object(s) and put the copies at a new location.
- (BOOL) exists;  // Verify if an object exists.
- (void) moveTo:(SBObject *)to;  // Move object(s) to a new location.
- (void) saveIn:(NSURL *)in_ as:(NSString *)as;  // Save an object.

@end

@interface CaminoBookmarkItem : SBObject

@property (copy) NSString *name;  // The name of the bookmark item.
@property (copy) NSString *objectDescription;  // The description of the bookmark item.
@property (copy) NSString *shortcut;  // The shortcut for the bookmark item.

- (void) close;  // Close an object.
- (void) delete;  // Delete an object.
- (void) duplicateTo:(SBObject *)to withProperties:(NSDictionary *)withProperties;  // Copy object(s) and put the copies at a new location.
- (BOOL) exists;  // Verify if an object exists.
- (void) moveTo:(SBObject *)to;  // Move object(s) to a new location.
- (void) saveIn:(NSURL *)in_ as:(NSString *)as;  // Save an object.

@end

@interface CaminoBookmarkFolder : CaminoBookmarkItem

- (SBElementArray *) bookmarkItems;
- (SBElementArray *) bookmarkFolders;
- (SBElementArray *) bookmarks;


@end

@interface CaminoBookmark : CaminoBookmarkItem

@property (copy) NSString *URL;  // The URL of the bookmark.
@property (copy, readonly) NSDate *lastVisitDate;  // The date the bookmark was last visited.
@property (copy, readonly) NSNumber *visitCount;  // The number of times the bookmark has been visited.


@end

