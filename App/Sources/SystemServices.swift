import Foundation

protocol SystemActionPerforming {
    func lockScreen() throws
    func wakeDisplay() throws
}

protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    var statusText: String { get }
}

protocol AccessibilityPermissionProviding {
    var isTrusted: Bool { get }
    func promptIfNeeded()
}

struct PreviewSystemActions: SystemActionPerforming {
    func lockScreen() throws {}
    func wakeDisplay() throws {}
}

struct PreviewLoginItemController: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {}
    var statusText: String { "Not Registered" }
}

struct PreviewAccessibilityPermission: AccessibilityPermissionProviding {
    var isTrusted: Bool { true }
    func promptIfNeeded() {}
}
