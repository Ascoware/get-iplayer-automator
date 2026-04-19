import Foundation

@objc(RadioFormat)
class RadioFormat: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    @objc dynamic var format: String

    override init() {
        self.format = ""
        super.init()
    }

    @objc init(format: String) {
        self.format = format
        super.init()
    }

    required init?(coder: NSCoder) {
        guard let format = coder.decodeObject(forKey: "format") as? String else {
            self.format = ""
            super.init()
            return nil
        }
        self.format = format
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(format, forKey: "format")
    }
}
