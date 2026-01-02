import Cocoa

@objc
class GiASearch: NSObject {
    private var task: Process?
    private var pipe: Pipe?
    private var errorPipe: Pipe?
    private var data = ""
    private var allowHidingOfDownloadedItems: Bool
    private var searchTerms: String
    private var completion: (([Programme]) -> Void)?

    @objc
    init(searchTerms: String, allowHidingOfDownloadedItems: Bool, completion: @escaping ([Programme]) -> Void) {
        self.searchTerms = searchTerms
        self.allowHidingOfDownloadedItems = allowHidingOfDownloadedItems
        self.completion = completion
        super.init()
        startSearch()
    }

    private func startSearch() {
        guard !searchTerms.isEmpty else {
            fatalError("The search arguments string provided was nil or empty.")
        }

        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        // Build arguments
        let argsController = GetiPlayerArguments.shared
        var args: [String] = [
            ApplicationPaths.getiPlayerPath,
            argsController.noWarningArg,
            argsController.cacheExpiryArg,
            argsController.typeArgument(forCacheUpdate: false),
            "--listformat",
            "SearchResult|<pid>|<available>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>|<available>",
            "--long",
            "--search",
            searchTerms,
            argsController.profileDirArg
        ]

        if !UserDefaults.standard.bool(forKey: "ShowDownloadedInSearch") && allowHidingOfDownloadedItems {
            args.append("--hide")
        }

        for arg in args {
            print(arg) // Replace with DDLogVerbose if needed
        }

        task.launchPath = ApplicationPaths.perlBinaryPath
        task.arguments = args
        task.standardOutput = pipe
        task.standardError = errorPipe

        // Set environment
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSString(string: "~").expandingTildeInPath
        env["PERL_UNICODE"] = "AS"
        env["PATH"] = ApplicationPaths.perlEnvironmentPath
        task.environment = env

        // Observe output
        NotificationCenter.default.addObserver(self, selector: #selector(searchDataReadyNotification(_:)), name: FileHandle.readCompletionNotification, object: pipe.fileHandleForReading)
        pipe.fileHandleForReading.readInBackgroundAndNotify()

        NotificationCenter.default.addObserver(self, selector: #selector(searchDataReadyNotification(_:)), name: FileHandle.readCompletionNotification, object: errorPipe.fileHandleForReading)
        errorPipe.fileHandleForReading.readInBackgroundAndNotify()

        NotificationCenter.default.addObserver(self, selector: #selector(searchFinished(_:)), name: Process.didTerminateNotification, object: task)

        self.task = task
        self.pipe = pipe
        self.errorPipe = errorPipe

        do {
            try task.run()
        } catch {
            print("Failed to launch task: \(error)")
        }
    }

    @objc private func searchDataReadyNotification(_ notification: Notification) {
        guard let d = notification.userInfo?[NSFileHandleNotificationDataItem] as? Data, d.count > 0 else { return }
        if let s = String(data: d, encoding: .utf8) {
            data.append(s)
        }
            if let fh = notification.object as? FileHandle {
                fh.readInBackgroundAndNotify()
            }
            }

    @objc private func searchFinished(_ notification: Notification) {
        let array = data.components(separatedBy: .newlines)
        var resultsArray: [Programme] = []
        let rawDateParser = ISO8601DateFormatter()
        rawDateParser.timeZone = TimeZone(secondsFromGMT: 0)

        self.task = nil
        self.pipe = nil
        self.errorPipe = nil

        for string in array {
            if string.hasPrefix("SearchResult|") {
                let fields = string.components(separatedBy: "|")
                guard fields.count > 11 else { continue }
                let p = Programme()
                p.processedPID = true
                p.pid = fields[1]
                let broadcastDate = rawDateParser.date(from: fields[2])
                p.lastBroadcast = broadcastDate
                if let date = broadcastDate {
                    p.lastBroadcastString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                }
                p.radio = (fields[3] == "radio")
                p.seriesName = fields[4]
                p.episodeName = fields[5]
                p.tvNetwork = fields[6]
                p.season = Int(fields[7]) ?? 0
                p.episode = Int(fields[8]) ?? 0
                p.desc = fields[9]
                p.showName = !p.seriesName.isEmpty ? p.seriesName : p.episodeName
                if let url = URL(string: fields[10]) {
                    p.thumbnail = NSImage(byReferencing: url)
                }
                p.url = fields[11]

                if p.pid.isEmpty || p.showName.isEmpty || p.tvNetwork.isEmpty || p.url.isEmpty {
                    print("Skipped invalid search result: \(string)")
                    continue
                }
                resultsArray.append(p)
            } else if string.hasPrefix("Unknown option:") || string.hasPrefix("Option") || string.hasPrefix("Usage") {
                print("Unknown option: \(string)")
            }
        }
        completion?(resultsArray)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
