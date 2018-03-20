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
    public var programmeName = ""
    public var productionId = ""
    public var programmeURL = ""
    public var numberEpisodes: Int = 0
    public var forceCacheUpdate: Bool = false
    public var timeDateLastAired: Date? = nil
    public var timeAdded: Date? = nil
    public var thumbnailURL = ""
    public var programDescription = ""
    
    init(name: String, pid: String, url: String, numberEpisodes: Int, timeDateLastAired: Date?, programDescription: String, thumbnailURL: String) {
        super.init()
        self.programmeName = name
        self.productionId = pid
        self.programmeURL = url
        self.numberEpisodes = numberEpisodes
        self.timeDateLastAired = timeDateLastAired
        self.programDescription = programDescription
        self.thumbnailURL = thumbnailURL
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
        timeDateLastAired =  coder.decodeObject(forKey: "timeIntDateLastAired") as? Date
        timeAdded = coder.decodeObject(forKey: "timeAdded") as? Date
        super.init()
    }
    
    public override var hash: Int {
        return programmeName.hashValue
    }
}

