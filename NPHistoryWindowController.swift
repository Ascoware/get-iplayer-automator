import Cocoa

@objc(NPHistoryTableViewController)
public class NPHistoryTableViewController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var historyTable: NSTableView!

    var historyDisplayArray: [HistoryDisplay] = []

    public override func windowDidLoad() {
        loadDisplayData()
        NotificationCenter.default.addObserver(self, selector: #selector(loadDisplayData), name: NSNotification.Name("NewProgrammeDisplayFilterChanged"), object: nil)
    }

    @IBAction func changeFilter(_ sender: Any?) {
        loadDisplayData()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return historyDisplayArray.count
    }

    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let np = historyDisplayArray[row]
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        return np.value(forKey: identifier)
    }

    @objc func loadDisplayData() {
        var displayDate: String?
        var headerDate: String?
        var pageNumber = 0

        // Set up date for use in headings comparison
        var secondsSince1970 = Date().timeIntervalSince1970
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        let dateFormatterDayOfWeek = DateFormatter()
        dateFormatterDayOfWeek.dateFormat = "EEEE"

        var dayNames: [String: String] = [:]

        for i in 0..<7 {
            let keyValue: String
            if i == 0 {
                keyValue = "Today"
            } else if i == 1 {
                keyValue = "Yesterday"
            } else {
                keyValue = dateFormatterDayOfWeek.string(from: Date(timeIntervalSince1970: secondsSince1970))
            }
            let key = dateFormatter.string(from: Date(timeIntervalSince1970: secondsSince1970))
            dayNames[key] = keyValue
            secondsSince1970 -= 24 * 60 * 60
        }

        historyDisplayArray.removeAll()

        let programHistory = NewProgrammeHistory.sharedInstance().programmeHistoryArray
        for np in programHistory {
            if showSTVProgramme(np) || showBBCTVProgramme(np) || showBBCRadioProgramme(np) {
                if np.dateFound != displayDate {
                    displayDate = np.dateFound
                    headerDate = dayNames[np.dateFound] ?? "On : \(displayDate ?? "")"
                    historyDisplayArray.append(HistoryDisplay(itemString: nil, tvChannel: nil, lineNumber: 2, pageNumber: pageNumber))
                    historyDisplayArray.append(HistoryDisplay(itemString: headerDate, tvChannel: nil, lineNumber: 0, pageNumber: pageNumber + 1))
                    pageNumber += 1
                }
                let theItem = "     \(np.programmeName)"
                historyDisplayArray.append(HistoryDisplay(itemString: theItem, tvChannel: np.tvChannel, lineNumber: 1, pageNumber: pageNumber))
            }
        }

        historyDisplayArray.append(HistoryDisplay(itemString: nil, tvChannel: nil, lineNumber: 2, pageNumber: pageNumber))

        // Sort in to programme within reverse date order
        let sortDescriptors: [NSSortDescriptor] = [
            NSSortDescriptor(key: "pageNumber", ascending: false),
            NSSortDescriptor(key: "lineNumber", ascending: true),
            NSSortDescriptor(key: "programmeNameString", ascending: true),
            NSSortDescriptor(key: "networkNameString", ascending: true)
        ]
        historyDisplayArray = (historyDisplayArray as NSArray).sortedArray(using: sortDescriptors) as! [HistoryDisplay]

        historyTable?.reloadData()
    }

    func showSTVProgramme(_ np: ProgrammeHistoryObject) -> Bool {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "ShowITV") == false { return false }
        if np.networkName != "STV" && np.networkName != "ITV" { return false }
        if defaults.bool(forKey: "IgnoreAllTVNews") == true,
           np.programmeName.range(of: "news", options: .caseInsensitive) != nil {
            return false
        }
        return true
    }

    func showBBCTVProgramme(_ np: ProgrammeHistoryObject) -> Bool {
        let regionalChannels = [
            "BBC Alba", "BBC One Northern Ireland", "BBC One Scotland", "BBC One Wales",
            "BBC Scotland", "BBC Two England", "BBC Two Northern Ireland", "BBC Two Wales", "S4C"
        ]
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "ShowBBCTV") == false { return false }
        if np.networkName != "BBC TV" { return false }
        if defaults.bool(forKey: "IgnoreAllTVNews") == true,
           np.programmeName.range(of: "news", options: .caseInsensitive) != nil {
            return false
        }
        let channelChecks: [(String, String)] = [
            ("BBC Four", "BBCFour"),
            ("BBC News", "BBCNews"),
            ("BBC One", "BBCOne"),
            ("BBC Parliament", "BBCParliament"),
            ("BBC Two", "BBCTwo"),
            ("CBBC", "CBBC"),
            ("CBeebies", "CBeebies")
        ]
        for (channel, key) in channelChecks {
            if np.tvChannel == channel {
                return defaults.bool(forKey: key)
            }
        }
        let showRegionalTV = defaults.bool(forKey: "ShowRegionalTVStations")
        for region in regionalChannels {
            if np.tvChannel.contains(region) == true {
                return showRegionalTV
            }
        }
        return defaults.bool(forKey: "ShowLocalTVStations")
    }

    func showBBCRadioProgramme(_ np: ProgrammeHistoryObject) -> Bool {
        let regions = [
            "BBC Radio Cymru", "BBC Radio Foyle", "BBC Radio Nan Gaidheal",
            "BBC Radio Scotland", "BBC Radio Ulster", "BBC Radio Wales"
        ]
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "ShowBBCRadio") == false { return false }
        if np.networkName != "BBC Radio" { return false }
        if defaults.bool(forKey: "IgnoreAllRadioNews") == true,
           np.programmeName.range(of: "news", options: .caseInsensitive) != nil {
            return false
        }
        let channelChecks: [(String, String)] = [
            ("BBC Radio 1Xtra", "Radio1Xtra"),
            ("BBC Radio 1", "Radio1"),
            ("BBC Radio 2", "Radio2"),
            ("BBC Radio 3", "Radio3"),
            ("BBC Radio 4 Extra", "Radio4Extra"),
            ("BBC Radio 4", "Radio4"),
            ("BBC Radio 5 live", "Radio5Live"),
            ("BBC 5 live sports extra", "Radio5LiveSportsExtra"),
            ("BBC Radio 6 Music", "Radio6Music"),
            ("BBC Asian Network", "RadioAsianNetwork"),
            ("BBC World Service", "BBCWorldService")
        ]
        for (channel, key) in channelChecks {
            if np.tvChannel == channel {
                return defaults.bool(forKey: key)
            }
        }
        for region in regions {
            if np.tvChannel.contains(region) == true {
                return defaults.bool(forKey: "ShowRegionalRadioStations")
            }
        }
        return defaults.bool(forKey: "ShowLocalRadioStations")
    }
}
