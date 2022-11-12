//
//  AppDelegate.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 11/8/19.
//  Copyright © 2019 Ascoware LLC. All rights reserved.
//

import Cocoa
import SwiftUI
import Sparkle

@NSApplicationMain
public class AppDelegate: NSObject  {

    var window: NSWindow!

    var runDownloads = false
    var runUpdate = false

    func confirmQuit() -> Bool {
        if runDownloads {
            let downloadAlert = NSAlert()
            downloadAlert.messageText = "Are you sure you wish to quit?"
            downloadAlert.addButton(withTitle: "No")
            downloadAlert.addButton(withTitle: "Yes")
            downloadAlert.informativeText = "You are currently downloading shows. If you quit, they will be cancelled."
            let response = downloadAlert.runModal()
            if (response == .alertFirstButtonReturn) {
                return false
            }
        } else if runUpdate {
            let updateAlert = NSAlert()
            updateAlert.messageText = "Are you sure?"
            updateAlert.addButton(withTitle: "No")
            updateAlert.addButton(withTitle: "Yes")
            updateAlert.informativeText = "Get iPlayer Automator is currently updating the cache. If you proceed with quiting, some series-link information will be lost. It is not recommended to quit during an update. Are you sure you wish to quit?";
            let response = updateAlert.runModal()
            if (response == .alertFirstButtonReturn) {
                return false
            }
        }
        
        return true
    }


// MARK: Misc methods
    public func saveAppData() {
//    //Save Queue & Series-Link
//    NSMutableArray *tempQueue = [[NSMutableArray alloc] initWithArray:_queueController.arrangedObjects];
//    NSMutableArray *tempSeries = [[NSMutableArray alloc] initWithArray:_pvrQueueController.arrangedObjects];
//    NSMutableArray *temptempQueue = [[NSMutableArray alloc] initWithArray:tempQueue];
//    for (Programme *show in temptempQueue)
//    {
//    if (([show.complete isEqualToNumber:@YES] && [show.successful isEqualToNumber:@YES])
//    || [show.status isEqualToString:@"Added by Series-Link"]
//    || show.addedByPVR ) [tempQueue removeObject:show];
//    }
//    NSMutableArray *temptempSeries = [[NSMutableArray alloc] initWithArray:tempSeries];
//    for (Series *series in temptempSeries)
//    {
//    if (series.showName.length == 0) {
//    [tempSeries removeObject:series];
//    } else if (series.tvNetwork.length == 0) {
//    series.tvNetwork = @"*";
//    }
//
//    }
//    NSString *appSupportFolder = [[NSFileManager defaultManager] applicationSupportDirectory];
//    NSString *filename = @"Queue.automatorqueue";
//    NSString *filePath = [appSupportFolder stringByAppendingPathComponent:filename];
//
//    NSMutableDictionary * rootObject;
//    rootObject = [NSMutableDictionary dictionary];
//
//    rootObject[@"queue"] = tempQueue;
//    rootObject[@"serieslink"] = tempSeries;
//    rootObject[@"lastUpdate"] = _lastUpdate;
//    [NSKeyedArchiver archiveRootObject: rootObject toFile: filePath];
//
//    filename = @"Formats.automatorqueue";
//    filePath = [appSupportFolder stringByAppendingPathComponent:filename];
//
//    rootObject = [NSMutableDictionary dictionary];
//
//    rootObject[@"tvFormats"] = _tvFormatController.arrangedObjects;
//    rootObject[@"radioFormats"] = _radioFormatController.arrangedObjects;
//    [NSKeyedArchiver archiveRootObject:rootObject toFile:filePath];
//
//    filename = @"ITVFormats.automator";
//    filePath = [appSupportFolder stringByAppendingPathComponent:filename];
//    rootObject = [NSMutableDictionary dictionary];
//    rootObject[@"itvFormats"] = _itvFormatController.arrangedObjects;
//    [NSKeyedArchiver archiveRootObject:rootObject toFile:filePath];
//
//    //Store Preferences in case of crash
//    [[NSUserDefaults standardUserDefaults] synchronize];
    }

}

extension AppDelegate: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        NSApp.terminate(self)
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        return confirmQuit()
    }
}

extension AppDelegate : NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
        
        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.delegate = self

        DispatchQueue.main.async {
            let itvUpdater = ITVPrograms()
            itvUpdater.itvUpdate()
        }
    }
    
    public func applicationWillTerminate(_ aNotification: Notification) {
        //End Downloads if Running
        if runDownloads {
            //_currentDownload.cancelDownload()
        }
        
        saveAppData()
    }
    
    private func applicationShouldTerminateAfterLastWindowClosed(application: NSApplication) -> Bool {
        return true
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return confirmQuit() ? .terminateNow : .terminateCancel
    }
}

extension AppDelegate: SPUUpdaterDelegate {
    public func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        //    NSLog(@"didFinishLoadingAppcast");
    }
    
    public func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        //    NSLog(@"No update found.");
    }
    public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let notification = NSUserNotification()
        notification.informativeText = "Get iPlayer Automator \(item.displayVersionString) is available."
        notification.title = "Update Available!"
        NSUserNotificationCenter.default.deliver(notification)
    }
}
