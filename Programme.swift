//  Converted to Swift 5.7 by Swiftify v5.7.28606 - https://swiftify.com/
//
//  Programme.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc enum ProgrammeType : Int {
    case tv
    case radio
    case itv
}

@objcMembers public class Programme : NSObject, NSSecureCoding {

    private var getNameRunning = false

    dynamic var tvNetwork: String = ""
    dynamic var showName: String = ""
    dynamic var pid: String = ""
    dynamic var status: String = ""
    dynamic var seriesName: String = ""
    dynamic var episodeName: String = ""
    dynamic var complete = false
    dynamic var successful = false
    dynamic var timeadded: NSNumber = 0
    dynamic var path: String = ""
    dynamic var season: Int = 0
    dynamic var episode: Int = 0
    var processedPID = false
    var radio = false
    var podcast = false
    var realPID: String = ""
    var subtitlePath: String = ""
    var reasonForFailure: String = ""
    var availableModes: String = ""
    var url: String = ""
    var desc: String = ""
    //Extended Metadata
    var extendedMetadataRetrieved = false
    var successfulRetrieval = false
    var duration: Int = 0
    var categories: String = ""

    // First broadcast: first time show was ever aired.
    // Optional because we only fetch this with getName or extended metadata.
    var firstBroadcast: Date?

    // Last broadcast: most recent airing. Can be nil for an older program.
    var lastBroadcast: Date?
    dynamic var lastBroadcastString: String = ""

    var modeSizes: [[String:String]] = []
    var thumbnailURLString: String = ""
    var thumbnail: NSImage?
    var getiPlayerProxy: GetiPlayerProxy?
    var addedByPVR = false

    var type: ProgrammeType {
        if radio {
            return .radio
        } else if tvNetwork.hasPrefix("ITV") {
            return .itv
        } else {
            return .tv
        }
    }

    var typeDescription: String {
        let dic = [
            NSNumber(value: ProgrammeType.tv.rawValue): "BBC TV",
            NSNumber(value: ProgrammeType.radio.rawValue): "BBC Radio",
            NSNumber(value: ProgrammeType.itv.rawValue): "ITV"
        ]

        return dic[NSNumber(value: type.rawValue)] ?? "Unknown"
    }

    public override init() {
        super.init()
        status = runDownloads.boolValue ? "Waiting…" : ""
    }

    public class var supportsSecureCoding: Bool {
        return true
    }

    public override var description: String {
        return "\(pid): \(showName)"
    }

    public func encode(with coder: NSCoder) {
        coder.encode(showName, forKey: "showName")
        coder.encode(pid, forKey: "pid")
        coder.encode(tvNetwork, forKey: "tvNetwork")
        coder.encode(status, forKey: "status")
        coder.encode(path, forKey: "path")
        coder.encode(seriesName, forKey: "seriesName")
        coder.encode(episodeName, forKey: "episodeName")
        coder.encode(timeadded, forKey: "timeadded")
        coder.encode(processedPID, forKey: "processedPID")
        coder.encode(radio, forKey: "radio")
        coder.encode(realPID, forKey: "realPID")
        coder.encode(url, forKey: "url")
        coder.encode(season, forKey: "season")
        coder.encode(episode, forKey: "episode")
        coder.encode(lastBroadcast, forKey: "lastBroadcast")
        coder.encode(lastBroadcastString, forKey: "lastBroadcastString")
    }

    public required init?(coder: NSCoder) {
        super.init()
        pid = coder.decodeObject(forKey: "pid") as? String ?? ""
        showName = coder.decodeObject(forKey: "showName") as? String ?? ""
        tvNetwork = coder.decodeObject(forKey: "tvNetwork") as? String ?? ""
        status = coder.decodeObject(forKey: "status") as? String ?? ""
        complete = false
        successful = false
        path = coder.decodeObject(forKey: "path") as? String ?? ""
        seriesName = coder.decodeObject(forKey: "seriesName") as? String ?? ""
        episodeName = coder.decodeObject(forKey: "episodeName") as? String ?? ""
        if let decodeObject = coder.decodeObject(forKey: "timeadded") as? NSNumber {
            timeadded = decodeObject
        }

        processedPID = coder.decodeBool(forKey: "processedPID")
        radio = coder.decodeBool(forKey: "radio")

        realPID = coder.decodeObject(forKey: "realPID") as? String ?? ""
        url = coder.decodeObject(forKey: "url") as? String ?? ""
        subtitlePath = ""
        reasonForFailure = ""
        availableModes = ""
        desc = ""
        getNameRunning = false
        addedByPVR = false
        season = coder.decodeInteger(forKey: "season")
        episode = coder.decodeInteger(forKey: "episode")
        lastBroadcast = coder.decodeObject(forKey: "lastBroadcast") as? Date ?? Date()
        lastBroadcastString = coder.decodeObject(forKey: "lastBroadcastString") as? String ?? ""
    }

    func retrieveExtendedMetadata() {
        DDLogInfo("Retrieving Extended Metadata")
        getiPlayerProxy = GetiPlayerProxy()
        getiPlayerProxy?.loadInBackground(for: #selector(getRemoteMetadata(_:proxyDict:)), with: nil, onTarget: self, silently: false)
    }

    // Look for 'field:' at the beginning of a line in 'lines'. If found, and 'secondField' is empty, return the rest
    // of the line after the whitespace beyond the 'field:'.
    // If secondField is provided, treat the value portion of the line as a new key/value pair
    // and look for 'secondField:'. Then return the rest of the line.
    func scanField(_ field: String, lines: [String], secondField: String = "") -> String {
        var value: String? = nil

        for line in lines {
            if line.hasPrefix("\(field):") {
                let scanner = Scanner(string: line)
                scanner.scanUpTo("\(field):", into: nil)
                scanner.scanString("\(field):", into: nil)
                scanner.scanCharacters(from: .whitespaces, into: nil)
                value = scanner.scanUpToCharactersFromSet(set: .newlines)

                if !secondField.isEmpty, let lineRemainder = value, lineRemainder.hasPrefix(secondField) {
                    let remainder = Scanner(string: lineRemainder)
                    remainder.scanUpTo("\(secondField):", into: nil)
                    remainder.scanString("\(secondField):", into: nil)
                    remainder.scanCharacters(from: .whitespaces, into: nil)
                    value = remainder.scanUpToCharactersFromSet(set: .newlines)
                    break
                }

            }
        }
        return value ?? ""
    }

    func cancelMetadataRetrieval() {
//        if metadataTask?.isRunning ?? false {
//            metadataTask?.interrupt()
//            DDLogInfo("Metadata retrieval cancelled for \(description)");
//        }
//
//        taskOutput = ""
//        metadataTask = nil
//        pipe = nil
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? Programme {
            return other.showName == showName && other.pid == pid
        } else {
            return false
        }
    }

    func getNameSynchronous() {
        getName()
        while getNameRunning {
            Thread.sleep(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    func getName() {
        autoreleasepool {
            getNameRunning = true

            let getNameTask = Process()
            let getNamePipe = Pipe()
            let listArgument = "--listformat=<index>|<pid>|<type>|<name>|<seriesnum>|<episode>|<channel>|<available>|<web>"
            let fieldsArgument = "--fields=index,pid"
            let wantedID = pid
            let args = [
                AppController.shared().getiPlayerPath,
                GetiPlayerArguments.sharedController().noWarningArg,
                GetiPlayerArguments.sharedController().cacheExpiryArg,
                "--nopurge",
                GetiPlayerArguments.sharedController().typeArgument(forCacheUpdate: false),
                listArgument,
                GetiPlayerArguments.sharedController().profileDirArg,
                fieldsArgument,
                wantedID
            ]
            getNameTask.arguments = args
            getNameTask.launchPath = AppController.shared().perlBinaryPath

            getNameTask.standardOutput = getNamePipe
            let getNameFh = getNamePipe.fileHandleForReading

            var envVariableDictionary = [String : String]()
            envVariableDictionary["HOME"] = (("~") as NSString).expandingTildeInPath
            envVariableDictionary["PERL_UNICODE"] = "AS"
            envVariableDictionary["PATH"] = AppController.shared().perlEnvironmentPath
            getNameTask.environment = envVariableDictionary
            getNameTask.launch()

            let data = getNameFh.readDataToEndOfFile()
            if let stringData = String(data: data, encoding: .utf8) {
                processGetNameDataFromSearch(stringData)
            }
        }
    }

    @objc func processGetNameDataFromSearch(_ getNameData: String) {
        let array = getNameData.components(separatedBy: .newlines)
        let wantedID = self.pid
        var found = false

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"

        for string in array {
            // TODO: remove use of index in future version
            let elements = string.components(separatedBy: "|")
            if elements.count < 9 {
                continue
            }

            var pid = "", showName = "", episode = "", index = "", type = "", tvNetwork = "", url = "", dateAired = "", season = ""

            if elements.count == 9 {
                index = elements[0]
                pid = elements[1]
                type = elements[2]
                showName = elements[3]
                season = elements[4]
                episode = elements[5]
                tvNetwork = elements[6]
                dateAired = elements[7]
                url = elements[8]
            } else {
                let getNameException = NSAlert()
                getNameException.addButton(withTitle: "OK")
                getNameException.messageText = "Unknown Error!"
                getNameException.informativeText = "An unknown error occured whilst trying to parse Get_iPlayer output (processGetNameData)."
                getNameException.alertStyle = .warning
                getNameException.runModal()
            }

            if (wantedID == pid) || (wantedID == index) {
                found = true

                self.showName = showName
                episodeName = episode
                if let date = dateFormatter.date(from: dateAired) {
                    lastBroadcast = date
                    lastBroadcastString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                }

                if !pid.isEmpty {
                    self.pid = pid
                }

                if !tvNetwork.isEmpty {
                    self.tvNetwork = tvNetwork
                }

                if !url.isEmpty {
                    self.url = url
                }

                if !season.isEmpty, let seasonNum = Int(season) {
                    self.season = seasonNum
                }

                status = runDownloads.boolValue ? "Waiting…" : "Available"

                if type == "radio" {
                    radio = true
                }
            }

            break
        }

        processedPID = found

        if !found {
            status = "Not in cache"

            if self.tvNetwork.hasPrefix("BBC") {
                showName = "Retrieving Metadata..."
                getNameFromPID()
            } else {
                getNameRunning = false
            }
        } else {
            getNameRunning = false
        }
    }

    func getNameFromPID() {
        DDLogInfo("Retrieving Metadata For PID \(pid)")
        getiPlayerProxy = GetiPlayerProxy()
        getiPlayerProxy?.loadInBackground(for: #selector(getRemoteMetadata(_:proxyDict:)), with: nil, onTarget: self, silently: false)
    }

    @objc func getRemoteMetadata(_ sender: Any?, proxyDict: [AnyHashable : Any]) {
        performSelector(inBackground: #selector(getRemoteMetadataThreadWithProxy(proxyDict:)), with: proxyDict)
    }

    @objc func getRemoteMetadataThreadWithProxy(proxyDict: [AnyHashable : Any]) {
        autoreleasepool {
            getiPlayerProxy = nil

            if let error = proxyDict["error"] as? NSError, error.code == kProxyLoadCancelled {
                return
            }

            let metadataTask = Process()
            let metadataPipe = Pipe()

            var args = [
                AppController.shared().getiPlayerPath,
                "--nopurge",
                GetiPlayerArguments.sharedController().noWarningArg,
                GetiPlayerArguments.sharedController().cacheExpiryArg,
                GetiPlayerArguments.sharedController().profileDirArg,
                "--info",
                "--pid",
                pid]

            // Only add a --versions parameter for audio described or signed. Otherwise, let get_iplayer figure it out.
            var needVersions = false
            var nonDefaultVersions: [String] = []

            if UserDefaults.standard.bool(forKey: "AudioDescribedNew") {
                nonDefaultVersions.append("audiodescribed")
                needVersions = true
            }
            if UserDefaults.standard.bool(forKey: "SignedNew") {
                nonDefaultVersions.append("signed")
                needVersions = true
            }

            if needVersions {
                nonDefaultVersions.append("default")
                var versionArg = "--versions="
                versionArg += nonDefaultVersions.joined(separator: ",")
                args.append(versionArg)
            }

            if let httpProxy = proxyDict["proxy"] as? HTTPProxy {
                args.append("-p\(httpProxy.url)")

                if UserDefaults.standard.bool(forKey: "AlwaysUseProxy") == false {
                    args.append("--partial-proxy")
                }
            }

            DDLogVerbose("get metadata args:")
            for arg in args {
                DDLogVerbose("\(arg)")
            }

            metadataTask.arguments = args
            metadataTask.launchPath = AppController.shared().perlBinaryPath
            metadataTask.standardOutput = metadataPipe
            let getNameFh = metadataPipe.fileHandleForReading

            var envVariableDictionary = [String : String]()
            envVariableDictionary["HOME"] = (("~") as NSString).expandingTildeInPath
            envVariableDictionary["PERL_UNICODE"] = "AS"
            envVariableDictionary["PATH"] = AppController.shared().perlEnvironmentPath
            metadataTask.environment = envVariableDictionary

            metadataTask.launch()
            let data = getNameFh.readDataToEndOfFile()

            if let stringData = String(data: data, encoding: .utf8) {
                processMetadataTaskOutput(stringData)
            }

            getNameRunning = false
        }
    }

    func processMetadataTaskOutput(_ output: String) {

        let outputLines = output.components(separatedBy: .newlines)
        var validOutput: [String] = []

        for line in outputLines {
            if line.hasPrefix("INFO:") || line.hasPrefix("WARNING:") || line.isEmpty {
                continue
            }

            validOutput.append(line)
        }

        // If the PID is valid and the show exists it will have a 'versions:' line.
        // If that's not there no need to go any further.
        var default_version: String? = nil
        let info_versions = scanField("versions", lines: validOutput)

        if info_versions.isEmpty {
            status = "Not Available"
            return
        }

        let versions = info_versions.components(separatedBy: ",")
        for version in versions {
            if (version == "default") || ((version == "original") && (default_version != "default")) || (default_version == nil && (version != "signed") && (version != "audiodescribed")) {
                default_version = version
            }
        }

        status = runDownloads.boolValue ? "Waiting…" : "Available"

        categories = scanField("categories", lines: validOutput)

        desc = scanField("desc", lines: validOutput)

        let durationStr = scanField("runtime", lines: validOutput)
        duration = Int(durationStr) ?? 0

        let broadcast = scanField("firstbcast", lines: validOutput)
        if !broadcast.isEmpty {
            firstBroadcast = ISO8601DateFormatter().date(from: broadcast)
        }

        seriesName = scanField("nameshort", lines: validOutput)
        episodeName = scanField("episodeshort", lines: validOutput)
        showName = scanField("longname", lines: validOutput)
        let seasonNumber = scanField("seriesnum", lines: validOutput)
        season = Int(seasonNumber) ?? 0

        let episodeNumber = scanField("episodenum", lines: validOutput)
        episode = Int(episodeNumber) ?? 0

        // parse mode sizes
        modeSizes.removeAll()
        for version in versions {
            var group: String? = nil
            switch version {
            case default_version:
                group = "A"
            case "signed":
                group = "C"
            case "audiodescribed":
                group = "D"
            default:
                group = "B"
            }

            var modePairs: [[String: String]] = []
            var allSizes = scanField("modesizes", lines: validOutput, secondField: version)

            if allSizes.isEmpty {
                allSizes = scanField("qualitysizes", lines: validOutput, secondField: version)
            }

            let sizePairs = allSizes.components(separatedBy: ",")

            if !sizePairs.isEmpty {
                for sizePair in sizePairs {
                    let components = sizePair.components(separatedBy: "=")
                    let mode = components[0]
                    let size = components[1]
                    var info: [String : String] = [:]
                    info["mode"] = mode
                    info["size"] = size
                    info["group"] = group
                    info["version"] = version == default_version ? "default" : version
                    modePairs.append(info)
                }
            }
            modeSizes.append(contentsOf: modePairs)
        }

        let thumbURL = scanField("thumbnail", lines: validOutput)
        DDLogDebug("Thumbnail URL: \(thumbURL)")
        if let anUrl = URL(string: thumbURL) {
            let request = URLRequest(url: anUrl)
            let dataTask = URLSession.shared.dataTask(with: request) { [self] data, response, error in
                thumbnailRequestFinished(data)
            }
            dataTask.resume()
        } else {
            thumbnailRequestFinished(nil)
        }

    }

    func thumbnailRequestFinished(_ thumbnailData: Data?) {
        if let thumbnailData {
            if let data = NSImage(data: thumbnailData) {
                thumbnail = data
            }
        }
        successfulRetrieval = true
        extendedMetadataRetrieved = true
        NotificationCenter.default.post(name: NSNotification.Name("ExtendedInfoRetrieved"), object: self)
        processedPID = true
    }

}

extension Programme : Comparable {

    public static func < (lhs: Programme, rhs: Programme) -> Bool {
        return lhs.showName < rhs.showName
    }

}
