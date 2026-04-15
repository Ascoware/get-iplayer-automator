//
//  DownloadHistoryController.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 7/10/25.
//

import Cocoa
import CocoaLumberjackSwift

@objc public class DownloadHistoryController: NSObject {
    @IBOutlet weak var historyArrayController: NSArrayController!
    @IBOutlet weak var historyWindow: NSWindow!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!

    var runDownloads: Bool = false

    public override func awakeFromNib() {
        super.awakeFromNib()
        readHistory()
        NotificationCenter.default.addObserver(self, selector: #selector(addToHistory(_:)), name: NSNotification.Name("AddProgToHistory"), object: nil)
    }

    private var historyFilePath: String? {
        guard let dir = FileManager.default.applicationSupportDirectory() else { return nil }
        return (dir as NSString).appendingPathComponent("download_history")
    }

    func readHistory() {
        DDLogVerbose("Read History")
        guard let historyFilePath = historyFilePath else { return }

        if let existing = historyArrayController.content as? [Any], !existing.isEmpty {
            historyArrayController.remove(contentsOf: existing)
        }

        guard let historyFile = FileHandle(forReadingAtPath: historyFilePath) else { return }
        let historyFileData = historyFile.readDataToEndOfFile()
        guard let historyFileInfo = String(data: historyFileData, encoding: .utf8), !historyFileInfo.isEmpty else { return }

        let historyEntries = historyFileInfo.components(separatedBy: .newlines)
        for entry in historyEntries where !entry.isEmpty {
            let components = entry.components(separatedBy: "|")
            guard components.count >= 7 else { continue }
            let historyEntry = DownloadHistoryEntry()
            historyEntry.pid = components[0]
            historyEntry.showName = components[1]
            historyEntry.episodeName = components[2]
            historyEntry.type = components[3]
            historyEntry.someNumber = components[4]
            historyEntry.downloadFormat = components[5]
            historyEntry.downloadPath = components[6]
            historyArrayController.addObject(historyEntry)
        }
        DDLogVerbose("End read history")
    }

    @IBAction func writeHistory(_ sender: Any?) {
        if !runDownloads {
            DDLogVerbose("Write History to File")
            guard let currentHistory = historyArrayController.arrangedObjects as? [DownloadHistoryEntry] else { return }
            let historyString = currentHistory.map { $0.entryString }.joined(separator: "\n") + "\n"
            guard let historyPath = historyFilePath else {
                return
            }
            guard let historyData = historyString.data(using: .utf8) else { return }
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: historyPath) {
                if !fileManager.createFile(atPath: historyPath, contents: historyData, attributes: nil) {
                    let alert = NSAlert()
                    alert.informativeText = "Please submit a bug report saying that the history file could not be created."
                    alert.messageText = "Could not create history file!"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    DDLogWarn("\(String(describing: self)): Could not create history file!")
                }
            } else {
                do {
                    try historyData.write(to: URL(fileURLWithPath: historyPath), options: .atomic)
                } catch {
                    let alert = NSAlert()
                    alert.informativeText = "Please submit a bug report saying that the history file could not be written to."
                    alert.messageText = "Could not write to history file!"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        } else {
            let alert = NSAlert()
            alert.informativeText = "Your changes have been discarded."
            alert.messageText = "Download History cannot be edited while downloads are running."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            historyWindow.close()
        }
        saveButton.isEnabled = false
        historyWindow.isDocumentEdited = false
    }

    @IBAction func showHistoryWindow(_ sender: Any?) {
        if !runDownloads {
            if !(historyWindow.isDocumentEdited) {
                readHistory()
            }
            historyWindow.makeKeyAndOrderFront(self)
            saveButton.isEnabled = historyWindow.isDocumentEdited
        } else {
            let alert = NSAlert()
            alert.messageText = "Download History cannot be edited while downloads are running."
            alert.runModal()
        }
    }

    @IBAction func removeSelectedFromHistory(_ sender: Any?) {
        if !runDownloads {
            saveButton.isEnabled = true
            historyWindow.isDocumentEdited = true
            historyArrayController.remove(sender)
        } else {
            let alert = NSAlert()
            alert.messageText = "Download History cannot be edited while downloads are running."
            alert.runModal()
            historyWindow.close()
        }
    }

    @IBAction func cancelChanges(_ sender: Any?) {
        historyWindow.isDocumentEdited = false
        saveButton.isEnabled = false
        historyWindow.close()
    }

    @objc func addToHistory(_ note: Notification) {
        readHistory()
        guard let userInfo = note.userInfo,
              let programs = userInfo["Programmes"] as? [Programme] else { return }
        let now = Int(Date().timeIntervalSince1970)
        for prog in programs {
            let entry = DownloadHistoryEntry()
            entry.pid = prog.pid
            entry.showName = prog.seriesName
            entry.episodeName = prog.episodeName
            entry.someNumber = "\(now)"
            entry.type = prog.typeDescription
            entry.downloadFormat = "flashhigh"
            entry.downloadPath = prog.path
            historyArrayController.addObject(entry)
        }
        writeHistory(self)
    }
}
