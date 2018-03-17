//
//  ProgrammeData.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/16/18.
//

@objc public class ProgrammeData: NSObject, NSCoding {
    public var afield: Int = 0
    public var seriesNumber: Int = 0
    public var episodeNumber: Int = 0
    public var isNew = false
    public var programmeName: String?
    public var productionId: String?
    public var programmeURL = ""
    public var numberEpisodes: Int = 0
    public var forceCacheUpdate: Bool = false
    public var timeDateLastAired: TimeInterval? = nil
    public var timeAdded: TimeInterval? = nil
    
    init(name: String, pid: String, url: String, numberEpisodes: Int, timeDateLastAired: TimeInterval) {
        super.init()
        let programmeName = name.replacingOccurrences(of: "-", with: " ")
        self.programmeName = programmeName.capitalized
        self.productionId = pid
        self.programmeURL = url
        self.numberEpisodes = numberEpisodes
        self.timeDateLastAired = timeDateLastAired
    }
    
    func addProgrammeSeriesInfo(_ aSeriesNumber: Int, aEpisodeNumber: Int) {
        seriesNumber = aSeriesNumber
        episodeNumber = aEpisodeNumber
    }
    
    public func encode(with encoder: NSCoder) {
        NSKeyedArchiver.setClassName("ProgrammeData", for: ProgrammeData.self)
        encoder.encode(programmeName, forKey: "programmeName")
        encoder.encode(productionId, forKey: "productionId")
        encoder.encode(programmeURL, forKey: "programmeURL")
        encoder.encode(numberEpisodes, forKey: "numberEpisodes")
        encoder.encode(seriesNumber, forKey: "seriesNumber")
        encoder.encode(episodeNumber, forKey: "episodeNumber")
        encoder.encode(isNew, forKey: "isNewBool")
        encoder.encode(forceCacheUpdate, forKey: "forceCacheUpdate")
        encoder.encode(timeDateLastAired, forKey: "timeIntDateLastAired")
        encoder.encode(timeAdded, forKey: "timeAdded")
    }
    
    required public init?(coder: NSCoder) {
        NSKeyedUnarchiver.setClass(ProgrammeData.self, forClassName: "ProgrammeData")
        programmeName = coder.decodeObject(forKey: "programmeName") as? String ?? ""
        productionId = coder.decodeObject(forKey: "productionId") as? String ?? ""
        programmeURL = coder.decodeObject(forKey: "programmeURL") as? String ?? ""
        numberEpisodes = coder.decodeObject(forKey: "numberEpisodes") as? Int ?? 0
        seriesNumber = coder.decodeObject(forKey: "seriesNumber") as? Int ?? 0
        episodeNumber = coder.decodeObject(forKey: "episodeNumber") as? Int ?? 0
        isNew = coder.decodeObject(forKey: "isNew") as? Bool ?? false
        forceCacheUpdate = coder.decodeObject(forKey: "forceCacheUpdate") as? Bool ?? false
        timeDateLastAired =  coder.decodeObject(forKey: "timeIntDateLastAired") as? Double ?? 0.0
        
        if coder.containsValue(forKey: "timeAddedInt") {
            let oldValue = coder.decodeObject(forKey: "timeAddedInt") as? Int ?? 0
            timeAdded = Double(oldValue)
        } else {
            timeAdded = coder.decodeObject(forKey: "timeAdded") as? Double ?? 0.0
        }
        
        super.init()
    }
    
    public override var hash: Int {
        return programmeName?.hashValue ?? 0
    }
}

