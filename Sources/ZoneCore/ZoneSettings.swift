import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english
    case simplifiedChinese

    public var id: String { rawValue }
}

public struct SelectedDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: String { stableID }

    public let stableID: String
    public let addressString: String
    public let displayName: String
    public let majorDeviceClass: UInt32?

    public init(
        stableID: String,
        addressString: String,
        displayName: String,
        majorDeviceClass: UInt32?
    ) {
        self.stableID = stableID
        self.addressString = addressString
        self.displayName = displayName
        self.majorDeviceClass = majorDeviceClass
    }

    private enum CodingKeys: String, CodingKey {
        case stableID
        case addressString
        case displayName
        case majorDeviceClass
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stableID = try container.decodeIfPresent(String.self, forKey: .stableID) ?? ""
        addressString = try container.decodeIfPresent(String.self, forKey: .addressString) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        majorDeviceClass = try container.decodeIfPresent(UInt32.self, forKey: .majorDeviceClass)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stableID, forKey: .stableID)
        try container.encode(addressString, forKey: .addressString)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(majorDeviceClass, forKey: .majorDeviceClass)
    }
}

public struct ZoneSettings: Codable, Equatable, Sendable {
    public var selectedDevice: SelectedDevice?
    public var language: AppLanguage
    public var lockThreshold: Int
    public var wakeThreshold: Int
    public var signalLossTimeout: TimeInterval
    public var slidingWindowSize: Int
    public var launchAtLogin: Bool

    public init(
        selectedDevice: SelectedDevice?,
        language: AppLanguage = .english,
        lockThreshold: Int,
        wakeThreshold: Int,
        signalLossTimeout: TimeInterval,
        slidingWindowSize: Int,
        launchAtLogin: Bool
    ) {
        self.selectedDevice = selectedDevice
        self.language = language
        self.lockThreshold = lockThreshold
        self.wakeThreshold = wakeThreshold
        self.signalLossTimeout = signalLossTimeout
        self.slidingWindowSize = slidingWindowSize
        self.launchAtLogin = launchAtLogin
    }

    private enum CodingKeys: String, CodingKey {
        case selectedDevice
        case language
        case lockThreshold
        case wakeThreshold
        case signalLossTimeout
        case slidingWindowSize
        case launchAtLogin
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSelectedDevice: SelectedDevice?
        do {
            decodedSelectedDevice = try container.decodeIfPresent(SelectedDevice.self, forKey: .selectedDevice)
        } catch {
            decodedSelectedDevice = nil
        }

        if let selectedDevice = decodedSelectedDevice,
           selectedDevice.stableID.isEmpty == false,
           selectedDevice.addressString.isEmpty == false,
           selectedDevice.displayName.isEmpty == false {
            self.selectedDevice = selectedDevice
        } else {
            self.selectedDevice = nil
        }
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? ZoneSettings.default.language
        lockThreshold = try container.decodeIfPresent(Int.self, forKey: .lockThreshold) ?? ZoneSettings.default.lockThreshold
        wakeThreshold = try container.decodeIfPresent(Int.self, forKey: .wakeThreshold) ?? ZoneSettings.default.wakeThreshold
        signalLossTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .signalLossTimeout) ?? ZoneSettings.default.signalLossTimeout
        slidingWindowSize = try container.decodeIfPresent(Int.self, forKey: .slidingWindowSize) ?? ZoneSettings.default.slidingWindowSize
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? ZoneSettings.default.launchAtLogin
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedDevice, forKey: .selectedDevice)
        try container.encode(language, forKey: .language)
        try container.encode(lockThreshold, forKey: .lockThreshold)
        try container.encode(wakeThreshold, forKey: .wakeThreshold)
        try container.encode(signalLossTimeout, forKey: .signalLossTimeout)
        try container.encode(slidingWindowSize, forKey: .slidingWindowSize)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
    }

    public static let `default` = ZoneSettings(
        selectedDevice: nil,
        language: .english,
        lockThreshold: -85,
        wakeThreshold: -55,
        signalLossTimeout: 10,
        slidingWindowSize: 5,
        launchAtLogin: false
    )
}
