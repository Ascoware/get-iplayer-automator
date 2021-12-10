//
//  GIASearch.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/7/20.
//  Copyright © 2020 Ascoware LLC. All rights reserved.
//

import Foundation

class GIASearch {
    var completion: ((GIASearch)->Void)?
    var searchResults: [Program] = []
    
    let searchTerms: [String]
    let logger: Logging
    let allowHiding: Bool
    
    init(searchTerms: [String], allowHiding: Bool, logger: Logging) {
        self.searchTerms = searchTerms
        self.logger = logger
        self.allowHiding = allowHiding
    }
        
    public func start() {
        if searchTerms.count == 0 {
            return
        }

        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        task.executableURL = getIPlayerPath
        
        var args = [
            noWarningArg,
            cacheExpiryArgument,
            typeArgumentForCacheUpdate(includeITV: true),
            searchResultFormat,
            profileDirArgument,
            "--long",
            "--nopurge",
            "--search",
        ]

        args.append(contentsOf: searchTerms)
        
        if let showDownloadedPref = UserDefaults.standard.value(forKey: "ShowDownloadedInSearch") as? Bool, !showDownloadedPref, allowHiding {
            args.append("--hide")
        }

        args.forEach {
            logger.addToLog($0)
        }
        
        task.arguments = args;
        task.standardInput = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        let file = pipe.fileHandleForReading

        let environment = [
            "HOME": NSHomeDirectory(),
            "PERL_UNICODE": "AS",
            "PATH": perlEnvironmentPath.absoluteString
        ]
        
        task.environment = environment
        task.currentDirectoryURL = perlEnvironmentPath
        task.launch()
        let data = file.readDataToEndOfFile()
        processSearchData(data: data)
    }

    func processSearchData(data d: Data) {
        guard let stringData = String(data: d, encoding: .utf8), stringData.count > 0 else {
            return
        }

        let resultArray = stringData.components(separatedBy: .newlines)
        var programsFound = [Program]()

        let rawDateParser = DateFormatter()
        let enUSPOSIXLocale = Locale(identifier: "en_US_POSIX")
        rawDateParser.locale = enUSPOSIXLocale
        rawDateParser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        rawDateParser.timeZone = TimeZone(secondsFromGMT: 0)
    
        resultArray.forEach {
            if !$0.hasPrefix("SearchResult|") {
                if $0.hasPrefix("Unknown option:") || $0.hasPrefix("Option") || $0.hasPrefix("Usage") {
                    logger.addToLog($0)
                }
                return
            }
            let p = Program()
            let fields = $0.split(separator: "|", omittingEmptySubsequences: false)
            p.pid = String(fields[1])

            if let broadcastDate = rawDateParser.date(from: String(fields[2])) {
                p.lastBroadcast = broadcastDate
                p.standardizedDate = DateFormatter.localizedString(from: broadcastDate, dateStyle: .medium, timeStyle: .none)
            }
            
            //SearchResult|<pid>|<available>|<type>|<name>|<episode>|<channel>|<seriesnum>|<episodenum>|<desc>|<thumbnail>|<web>
            if fields[3] == "radio" {
                p.isRadio = true
            }
            
            p.title = String(fields[4])
            p.episodeTitle = String(fields[5])
            p.network = String(fields[6])
            p.season = Int(String(fields[7])) ?? 0
            p.episode = Int(String(fields[8])) ?? 0
            p.summary = String(fields[9])
            p.thumbnailURL = String(fields[10])
            
            //                p.thumbnail = Image( URL(string(p.thumbnailURL))
            p.url = String(fields[11])
            
            if p.pid.count == 0 || p.title.count == 0 || p.network.count == 0 || p.url.count == 0 {
                logger.addToLog("WARNING: Skipped invalid search result: \($0)")
            } else {
                programsFound.append(p)
            }
        }
        
        searchResults = programsFound
    }
}
