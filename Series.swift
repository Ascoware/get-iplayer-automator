import Foundation

@objc(Series)
@objcMembers public class Series: NSObject, NSSecureCoding {
    var showName: String?
    var added: NSNumber?
    var tvNetwork: String?
    var lastFound: Date?

    public override init() {

    }

    public func encode(with coder: NSCoder) {
        coder.encode(showName, forKey: "showName")
        coder.encode(added, forKey: "added")
        coder.encode(tvNetwork, forKey: "tvNetwork")
        coder.encode(lastFound, forKey: "lastFound")
    }

    required public init?(coder: NSCoder) {
        showName = coder.decodeObject(forKey: "showName") as? String
        added = coder.decodeObject(forKey: "added") as? NSNumber
        tvNetwork = coder.decodeObject(forKey: "tvNetwork") as? String
        lastFound = coder.decodeObject(forKey: "lastFound") as? Date
    }

    public class var supportsSecureCoding: Bool {
        return true
    }

    override public var description: String {
        return "\(showName ?? "") (\(tvNetwork ?? ""))"
    }
}
