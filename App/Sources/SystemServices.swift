import ApplicationServices
import Foundation
import IOKit.pwr_mgt
import ServiceManagement

protocol SystemActionPerforming {
    func lockScreen() throws
    func wakeDisplay() throws
}

protocol LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws
    var statusText: String { get }
}

@MainActor
protocol AccessibilityPermissionProviding {
    var isTrusted: Bool { get }
    func promptIfNeeded()
}

enum SystemActionError: Error {
    case accessibilityDenied
    case eventSourceUnavailable
    case wakeFailed(Int32)
}

struct LiveSystemActions: SystemActionPerforming {
    func lockScreen() throws {
        guard AXIsProcessTrusted() else {
            throw SystemActionError.accessibilityDenied
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw SystemActionError.eventSourceUnavailable
        }

        let keyCode: CGKeyCode = 12
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = [.maskCommand, .maskControl]
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = [.maskCommand, .maskControl]

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    func wakeDisplay() throws {
        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionDeclareUserActivity(
            "Zone Wake Display" as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw SystemActionError.wakeFailed(result)
        }

        _ = IOPMAssertionRelease(assertionID)
    }
}

struct LiveAccessibilityPermission: AccessibilityPermissionProviding {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
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
