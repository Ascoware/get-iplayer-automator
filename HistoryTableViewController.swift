//
//  HistoryWindowController.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 10/10/21.
//

import Foundation
import AppKit



class SwiftHistoryDisplay: NSObject {
    let programmeName: String
    let networkName: String
    let lineNumber: Int
    let pageNumber: Int

    public init(programmeName: String, networkName: String, lineNumber: Int, pageNumber: Int) {
        self.programmeName = programmeName
        self.networkName = networkName
        self.lineNumber = lineNumber
        self.pageNumber = pageNumber
    }

}

class HistoryTableViewController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet var historyTable: NSTableView!
    let historyController = NewProgrammeHistory.sharedInstance()
    var historyDisplayArray = [SwiftHistoryDisplay]()

    override public init(window: NSWindow?) {
        super.init(window: window)
        loadDisplayData()
        NotificationCenter.default.addObserver(self, selector: #selector(loadDisplayData), name: NSNotification.Name(rawValue: "NewProgrammeDisplayFilterChanged"), object: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @IBAction func changeFilter(sender: Any) {
        loadDisplayData()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return historyDisplayArray.count
    }

    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let program = historyDisplayArray[row]
        if let tableColumn = tableColumn {
            return program.value(forKey: tableColumn.identifier.rawValue)
        }

        return nil

    }

    @objc public func loadDisplayData()
    {
        // Set up date for use in headings comparison
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd"
        let dateFormatterDayOfWeek = DateFormatter()
        dateFormatterDayOfWeek.dateFormat = "EEEE"

        var dayNames = [String: String]()

        for i in 0...7 {
            let secondsSince1970 = Date().timeIntervalSince1970 - TimeInterval(i * 24*60*60)
            let keyValue =
            i == 0 ? "Today" :
            i == 1 ? "Yesterday" :
            dateFormatterDayOfWeek.string(from: Date(timeIntervalSince1970:secondsSince1970))
            let key = dateFormatter.string(from: Date(timeIntervalSince1970:secondsSince1970))
            dayNames[key] = keyValue;
        }

        var pageNumber = 1
        historyDisplayArray = []
        let programHistory = historyController.programmeHistoryArray
        for np in programHistory {
            var displayDate = ""
            if showITVProgramme(np) || showBBCTVProgramme(np) || showBBCRadioProgramme(np)  {
                if np.dateFound != displayDate {
                    displayDate = np.dateFound;
                    let headerDate = dayNames[np.dateFound] ?? "On : " + displayDate

                    historyDisplayArray.append(SwiftHistoryDisplay(programmeName: "", networkName: "", lineNumber: 2, pageNumber: pageNumber))

                    historyDisplayArray.append(SwiftHistoryDisplay(programmeName: headerDate, networkName: "", lineNumber: 0, pageNumber: pageNumber))
                    pageNumber += 1
                }

                historyDisplayArray.append(SwiftHistoryDisplay(programmeName:"     " + np.programmeName, networkName:np.tvChannel, lineNumber:1, pageNumber:pageNumber))
            }
        }

        historyDisplayArray.append(SwiftHistoryDisplay(programmeName: "", networkName: "", lineNumber: 2, pageNumber: pageNumber))

        /* Sort in to programme within reverse date order */

        let sort4 = NSSortDescriptor(key: "networkName", ascending: true)
        let sort3 = NSSortDescriptor(key: "programmeName", ascending: true)
        let sort2 = NSSortDescriptor(key: "lineNumber", ascending:true)
        let sort1 = NSSortDescriptor(key: "pageNumber", ascending:false)
        historyDisplayArray.sort(sortDescriptors: [sort4, sort3, sort2, sort1])

        historyTable.reloadData()
    }

    func showITVProgramme(_ np: ProgrammeHistoryObject) -> Bool
    {
        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: "ShowITV") {
            return false
        }

        if np.networkName != "ITV" {
            return false
        }

        if defaults.bool(forKey: "IgnoreAllTVNews") {
            if np.programmeName.localizedCaseInsensitiveContains("news") {
                return false
            }
        }

        return true
    }

    func showBBCTVProgramme(_ np: ProgrammeHistoryObject) -> Bool
    {
        /*
         'p00fzl6b' => 'BBC Four', # bbcfour/programmes/schedules
         'p00fzl6g' => 'BBC News', # bbcnews/programmes/schedules
         'p00fzl6n' => 'BBC One', # bbcone/programmes/schedules/hd
         'p00fzl73' => 'BBC Parliament', # bbcparliament/programmes/schedules
         'p015pksy' => 'BBC Two', # bbctwo/programmes/schedules/hd
         'p00fzl9r' => 'CBBC', # cbbc/programmes/schedules
         'p00fzl9s' => 'CBeebies', # cbeebies/programmes/schedules
         */
        /*
         'p00fzl67' => 'BBC Alba', # bbcalba/programmes/schedules
         'p00fzl6q' => 'BBC One Northern Ireland', # bbcone/programmes/schedules/ni
         'p00zskxc' => 'BBC One Northern Ireland', # bbcone/programmes/schedules/ni_hd
         'p00fzl6v' => 'BBC One Scotland', # bbcone/programmes/schedules/scotland
         'p013blmc' => 'BBC One Scotland', # bbcone/programmes/schedules/scotland_hd
         'p00fzl6z' => 'BBC One Wales', # bbcone/programmes/schedules/wales
         'p013bkc7' => 'BBC One Wales', # bbcone/programmes/schedules/wales_hd
         'p06kvypx' => 'BBC Scotland', # bbcscotland/programmes/schedules
         'p06p396y' => 'BBC Scotland', # bbcscotland/programmes/schedules/hd
         'p00fzl97' => 'BBC Two England', # bbctwo/programmes/schedules/england
         'p00fzl99' => 'BBC Two Northern Ireland', # bbctwo/programmes/schedules/ni
         'p06ngcbm' => 'BBC Two Northern Ireland', # bbctwo/programmes/schedules/ni_hd
         'p00fzl9d' => 'BBC Two Wales', # bbctwo/programmes/schedules/wales
         'p06ngc52' => 'BBC Two Wales', # bbctwo/programmes/schedules/wales_hd
         'p020dmkf' => 'S4C', # s4c/programmes/schedules
         */
        let regionalChannels = [
            "BBC Alba",
            "BBC One Northern Ireland",
            "BBC One Scotland",
            "BBC One Wales",
            "BBC Scotland",
            "BBC Two England",
            "BBC Two Northern Ireland",
            "BBC Two Wales",
            "S4C"]

        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: "ShowBBCTV") {
            return false
        }

        if np.networkName.contains("BBC TV") {
            return false
        }

        if defaults.bool(forKey: "IgnoreAllTVNews") {
            if np.programmeName.localizedCaseInsensitiveContains("news") {
                return false
            }
        }

        if np.tvChannel == "BBC Four"{
            return defaults.bool(forKey:"BBCFour")
        }

        if np.tvChannel == "BBC News" {
            return defaults.bool(forKey:"BBCNews")
        }

        if np.tvChannel == "BBC One" {
            return defaults.bool(forKey:"BBCOne")
        }

        if np.tvChannel == "BBC Parliament" {
            return defaults.bool(forKey:"BBCParliament")
        }

        if np.tvChannel == "BBC Two" {
            return defaults.bool(forKey:"BBCTwo")
        }

        if np.tvChannel == "CBBC" {
            return defaults.bool(forKey:"CBBC")
        }

        if np.tvChannel == "CBeebies" {
            return defaults.bool(forKey:"CBeebies")
        }

        // Next, filter out regional channels
        let showRegionalTV = defaults.bool(forKey:"ShowRegionalTVStations")
        for region in regionalChannels {
            if np.tvChannel.contains(region) {
                return showRegionalTV;
            }
        }

        /* Otherwise must be local */
        return defaults.bool(forKey:"ShowLocalTVStations")
    }

    func showBBCRadioProgramme(_ np: ProgrammeHistoryObject) -> Bool
    {
        /*
         'p00fzl7b' => 'BBC Radio Cymru', # radiocymru/programmes/schedules
         'p00fzl7m' => 'BBC Radio Foyle', # radiofoyle/programmes/schedules
         'p00fzl81' => 'BBC Radio Nan Gaidheal', # radionangaidheal/programmes/schedules
         'p00fzl8d' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/fm
         'p00fzl8g' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/mw
         'p00fzl8b' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/orkney
         'p00fzl8j' => 'BBC Radio Scotland', # radioscotland/programmes/schedules/shetland
         'p00fzl8w' => 'BBC Radio Ulster', # radioulster/programmes/schedules
         'p00fzl8y' => 'BBC Radio Wales', # radiowales/programmes/schedules/fm
         'p00fzl8x' => 'BBC Radio Wales', # radiowales/programmes/schedules/mw
         */

        /*
         'national' => {
         'p00fzl64' => 'BBC Radio 1Xtra', # 1xtra/programmes/schedules
         'p00fzl7g' => 'BBC Radio 5 live', # 5live/programmes/schedules
         'p00fzl7h' => 'BBC Radio 5 live sports extra', # 5livesportsextra/programmes/schedules
         'p00fzl65' => 'BBC Radio 6 Music', # 6music/programmes/schedules
         'p00fzl68' => 'BBC Asian Network', # asiannetwork/programmes/schedules
         'p00fzl86' => 'BBC Radio 1', # radio1/programmes/schedules
         'p00fzl8v' => 'BBC Radio 2', # radio2/programmes/schedules
         'p00fzl8t' => 'BBC Radio 3', # radio3/programmes/schedules
         'p00fzl7j' => 'BBC Radio 4', # radio4/programmes/schedules/fm
         'p00fzl7k' => 'BBC Radio 4', # radio4/programmes/schedules/lw
         'p00fzl7l' => 'BBC Radio 4 Extra', # radio4extra/programmes/schedules
         'p02zbmb3' => 'BBC World Service', # worldserviceradio/programmes/schedules/uk
         },
         */

        let regions = [
            "BBC Radio Cymru",
            "BBC Radio Foyle",
            "BBC Radio Nan Gaidheal",
            "BBC Radio Scotland",
            "BBC Radio Ulster",
            "BBC Radio Wales",
        ];

        let defaults = UserDefaults.standard

        /* Filter out if not radio or news and news not wanted */
        if !defaults.bool(forKey:"ShowBBCRadio") {
            return false
        }

        if np.networkName != "BBC Radio" {
            return false;
        }

        if defaults.bool(forKey: "IgnoreAllRadioNews") {
            if np.programmeName.localizedCaseInsensitiveContains("news") {
                return false
            }
        }

        /* Filter each of the nationals in turn */

        if np.tvChannel == "BBC Radio 1Xtra" {
            return defaults.bool(forKey:"Radio1Xtra")
        }

        if np.tvChannel == "BBC Radio 1" {
            return defaults.bool(forKey:"Radio1")
        }

        if np.tvChannel == "BBC Radio 2" {
            return defaults.bool(forKey:"Radio2")
        }

        if np.tvChannel == "BBC Radio 3" {
            return defaults.bool(forKey:"Radio3")
        }

        if np.tvChannel == "BBC Radio 4" {
            return defaults.bool(forKey:"Radio4")
        }

        if np.tvChannel == "BBC Radio 4 Extra" {
            return defaults.bool(forKey:"Radio4Extra")
        }

        if np.tvChannel == "BBC Radio 5 live" {
            return defaults.bool(forKey:"Radio5Live")
        }

        if np.tvChannel == "BBC 5 live sports extra" {
            return defaults.bool(forKey:"Radio5LiveSportsExtra")
        }

        if np.tvChannel == "BBC Radio 6 Music" {
            return defaults.bool(forKey:"Radio6Music")
        }

        if np.tvChannel == "BBC Asian Network" {
            return defaults.bool(forKey:"RadioAsianNetwork")
        }

        if np.tvChannel == "BBC World Service" {
            return defaults.bool(forKey:"BBCWorldService")
        }

        /* Filter for regionals */

        for region in regions {
            if np.tvChannel.contains(region) {
                return defaults.bool(forKey: "ShowRegionalRadioStations")
            }
        }

        /* Otherwise must be local */
        return defaults.bool(forKey:"ShowLocalRadioStations")

    }
}

extension MutableCollection where Self : RandomAccessCollection {
    /// Sort `self` in-place using criteria stored in a NSSortDescriptors array
    public mutating func sort(sortDescriptors theSortDescs: [NSSortDescriptor]) {
        sort { by:
            for sortDesc in theSortDescs {
                switch sortDesc.compare($0, to: $1) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return false
        }

    }
}

extension Sequence where Iterator.Element : AnyObject {
    /// Return an `Array` containing the sorted elements of `source`
    /// using criteria stored in a NSSortDescriptors array.

    public func sorted(sortDescriptors theSortDescs: [NSSortDescriptor]) -> [Self.Iterator.Element] {
        return sorted {
            for sortDesc in theSortDescs {
                switch sortDesc.compare($0, to: $1) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return false
        }
    }
}
