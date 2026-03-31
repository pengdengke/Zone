import Foundation

public final class ZoneSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "zone.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ZoneSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        return (try? JSONDecoder().decode(ZoneSettings.self, from: data)) ?? .default
    }

    public func save(_ settings: ZoneSettings) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}
