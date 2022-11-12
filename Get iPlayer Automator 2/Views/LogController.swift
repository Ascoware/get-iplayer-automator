
import Cocoa
import CocoaLumberjackSwift

class LogController: NSObject, DDLogFormatter {
    @IBOutlet var log: NSTextView!
    @IBOutlet weak var window: NSWindow!

    override init() {
        //Initialize Log
        super.init()
        let fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1
        fileLogger.logFormatter = self
        DDLog.add(fileLogger)
        DDLog.add(DDOSLogger())
        var version: String? = nil
        if let object = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            version = "\(object)"
        }
        DDLogInfo("Get iPlayer Automator \(version ?? "Unknown") Initialized.")
    }

    override func awakeFromNib() {
        log.textColor = .white
        log.font = .userFixedPitchFont(ofSize: 12.0)
    }

    @IBAction func showLog(_ sender: Any) {
        window.makeKeyAndOrderFront(self)
        log.scrollToEndOfDocument(self)
    }

    @IBAction func copyLog(_ sender: Any) {
        let unattributedLog = log.string
        let pb = NSPasteboard.general
        let types: [NSPasteboard.PasteboardType] = [.string]
        pb.declareTypes(types, owner: self)
        pb.setString(unattributedLog, forType: .string)
    }

    @IBAction func clearLog(_ sender: Any) {
        log.string = ""
    }

    func format(message logMessage: DDLogMessage) -> String? {
        DispatchQueue.main.async(execute: { [self] in
            // In normal mode don't dump debug or verbose messages to the console.
            let verbose = UserDefaults.standard.bool(forKey: "Verbose")
            if !verbose && ((logMessage.flag == .debug) || (logMessage.flag == .verbose)) {
                return
            }

            let messageWithNewline = logMessage.message + "\r"
            let newMessage = NSMutableAttributedString(string: messageWithNewline)

            var textColor = log.textColor

            switch logMessage.flag {
            case .warning:
                textColor = .yellow
            case .error:
                textColor = .red
            case .debug:
                textColor = .lightGray
            case .verbose:
                textColor = .gray
            default:
                // use base color.
                break
            }

            if let textColor {
                newMessage.addAttribute(
                    .foregroundColor,
                    value: textColor,
                    range: NSRange(location: 0, length: newMessage.length))
            }

            if let font = log.font {
                newMessage.addAttribute(
                    .font,
                    value: font,
                    range: NSRange(location: 0, length: newMessage.length))
            }

            log.textStorage?.append(newMessage)

            //Scroll log to bottom only if it is visible.
            if window.isVisible {
                let shouldAutoScroll = Int(log.bounds.maxY) == Int(log.visibleRect.maxY)
                if shouldAutoScroll {
                    log.scrollToEndOfDocument(nil)
                }
            }
        })

        return logMessage.message
    }
}
