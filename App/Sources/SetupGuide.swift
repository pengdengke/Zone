import Foundation

struct SetupBanner: Equatable {
    enum Kind: Equatable {
        case bluetoothPermission
        case accessibilityPermission
        case deviceSelection
        case signal
    }

    let kind: Kind
    let title: String
    let message: String
    let symbolName: String
}
