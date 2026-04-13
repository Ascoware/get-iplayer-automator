//
//  ASDownloadShows.swift
//  Get_iPlayer_Automator
//
//  Scott Kovatch, 04-Aug-2025
//

import Foundation

@objc(ASDownloadShows)
public class ASDownloadShows: NSScriptCommand {
    public override func execute() -> Any? {
        NotificationCenter.default.post(name: Notification.Name("StartDownloads"), object: self)
        return nil
    }
}
