import Foundation

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
}

public struct ZoneSettings: Codable, Equatable, Sendable {
    public var selectedDevice: SelectedDevice?
    public var lockThreshold: Int
    public var wakeThreshold: Int
    public var signalLossTimeout: TimeInterval
    public var slidingWindowSize: Int
    public var launchAtLogin: Bool

    public init(
        selectedDevice: SelectedDevice?,
        lockThreshold: Int,
        wakeThreshold: Int,
        signalLossTimeout: TimeInterval,
        slidingWindowSize: Int,
        launchAtLogin: Bool
    ) {
        self.selectedDevice = selectedDevice
        self.lockThreshold = lockThreshold
        self.wakeThreshold = wakeThreshold
        self.signalLossTimeout = signalLossTimeout
        self.slidingWindowSize = slidingWindowSize
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = ZoneSettings(
        selectedDevice: nil,
        lockThreshold: -85,
        wakeThreshold: -55,
        signalLossTimeout: 10,
        slidingWindowSize: 5,
        launchAtLogin: false
    )
}
