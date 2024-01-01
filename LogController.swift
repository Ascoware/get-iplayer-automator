//
//  LogController.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/1/24.
//

import Foundation
import CocoaLumberjackSwift

@objc(LogController)
class LogController: NSObject, DDLogFormatter {
    @IBOutlet var log: NSTextView!
    @IBOutlet var window: NSWindow!

    override init() {
        super.init()

        let fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1
        fileLogger.logFormatter = self
        DDLog.add(fileLogger)
        DDLog.add(DDOSLogger())
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            DDLogInfo("Get iPlayer Automator \(version) Initialized.")
        }
    }

    override func awakeFromNib() {
        log.textColor = NSColor.white
        log.font = NSFont.userFixedPitchFont(ofSize: 12)
    }

    @IBAction func showLog(sender: AnyObject) {
        window.makeKeyAndOrderFront(self)
        log.scrollToEndOfDocument(self)
    }

    @IBAction func copyLog(sender: AnyObject) {
        let unattributedLog = log.string
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: self)
        pb.setString(String(unattributedLog), forType: .string)
    }

    @IBAction func clearLog(sender: AnyObject) {
        log.string = ""
    }

    func format(message: DDLogMessage) -> String? {
        // In normal mode don't dump debug or verbose messages to the console.
        let verbose = UserDefaults.standard.bool(forKey:"Verbose")
        if !verbose && ((message.flag == .debug) || (message.flag == .verbose)) {
            return nil
        }

        DispatchQueue.main.async {
            let messageWithNewline = message.message + "\r"
            var textColor = self.log.textColor ?? .white

            let newMessage = NSMutableAttributedString(string: messageWithNewline)
            switch message.flag {
            case .warning:
                textColor = NSColor.yellow
            case .error:
                textColor = NSColor.red
            case .debug:
                textColor = NSColor.lightGray
            case .verbose:
                textColor = NSColor.gray
            default:
                // use base color.
                break
            }

            newMessage.addAttribute(NSAttributedString.Key.foregroundColor,
                                    value:textColor,
                                    range:NSMakeRange(0, newMessage.length))

            if let font = self.log.font {
                newMessage.addAttribute(NSAttributedString.Key.font,
                                        value:font,
                                        range:NSMakeRange(0, newMessage.length))
            }
            self.log.textStorage?.append(newMessage)

            //Scroll log to bottom only if it is visible.
            if (self.window.isVisible) {
                let shouldAutoScroll = (NSMaxY(self.log.bounds) == NSMaxY(self.log.visibleRect))
                if (shouldAutoScroll) {
                    self.log.scrollToEndOfDocument(nil)
                }
            }
        }

        return message.message
    }
}
