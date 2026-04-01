import Foundation
import ZoneCore

struct AppStrings {
    let language: AppLanguage

    private var isChinese: Bool {
        language == .simplifiedChinese
    }

    var settingsWindowTitle: String {
        isChinese ? "Zone 设置" : "Zone Settings"
    }

    var openSettingsButtonTitle: String {
        isChinese ? "打开设置" : "Open Settings"
    }

    var resumeMonitoringButtonTitle: String {
        isChinese ? "继续监测" : "Resume Monitoring"
    }

    var pauseMonitoringButtonTitle: String {
        isChinese ? "暂停监测" : "Pause Monitoring"
    }

    var lockNowButtonTitle: String {
        isChinese ? "立即锁屏" : "Lock Now"
    }

    var wakeDisplayNowButtonTitle: String {
        isChinese ? "唤醒屏幕" : "Wake Display Now"
    }

    var quitButtonTitle: String {
        isChinese ? "退出" : "Quit"
    }

    var rssiLabelTitle: String {
        "RSSI"
    }

    var deviceLabelTitle: String {
        isChinese ? "设备" : "Device"
    }

    var noneOptionTitle: String {
        isChinese ? "无" : "None"
    }

    var languageSectionTitle: String {
        isChinese ? "语言" : "Language"
    }

    var languagePickerTitle: String {
        isChinese ? "界面语言" : "App Language"
    }

    func languageOptionTitle(_ language: AppLanguage) -> String {
        switch language {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    var connectedDeviceSectionTitle: String {
        isChinese ? "已连接设备" : "Connected Device"
    }

    var useThisTokenLabel: String {
        isChinese ? "使用此信物" : "Use this token"
    }

    var refreshConnectedDevicesButtonTitle: String {
        isChinese ? "刷新已连接设备" : "Refresh Connected Devices"
    }

    var connectedDevicesEmptyHint: String {
        isChinese
            ? "Zone 只会列出当前被 macOS 识别为已连接的蓝牙设备。"
            : "Zone only lists Bluetooth devices that macOS currently sees as connected."
    }

    var liveSignalHint: String {
        isChinese
            ? "Zone 还需要一个有效的负数 RSSI 样本。如果它一直显示 --，请重新连接设备，或更换另一个已连接设备。"
            : "Zone still needs a live negative RSSI sample. If it stays --, reconnect the device or choose another connected device."
    }

    var thresholdsSectionTitle: String {
        isChinese ? "阈值" : "Thresholds"
    }

    func lockBelowTitle(_ value: Int) -> String {
        isChinese ? "低于此值锁屏：\(value) dBm" : "Lock below: \(value) dBm"
    }

    func wakeAboveTitle(_ value: Int) -> String {
        isChinese ? "高于此值唤醒：\(value) dBm" : "Wake above: \(value) dBm"
    }

    func signalLossTimeoutTitle(_ value: Int) -> String {
        isChinese ? "信号丢失超时：\(value) 秒" : "Signal loss timeout: \(value) s"
    }

    func slidingWindowTitle(_ value: Int) -> String {
        isChinese ? "滑动窗口：\(value)" : "Sliding window: \(value)"
    }

    var permissionsAndStartupSectionTitle: String {
        isChinese ? "权限与启动" : "Permissions & Startup"
    }

    func bluetoothAccessTitle(status: String) -> String {
        "\(isChinese ? "蓝牙权限" : "Bluetooth access"): \(localizedSystemStatus(status))"
    }

    func accessibilityTitle(status: String) -> String {
        "\(isChinese ? "辅助功能" : "Accessibility"): \(localizedSystemStatus(status))"
    }

    func loginItemTitle(status: String) -> String {
        "\(isChinese ? "登录项" : "Login item"): \(localizedSystemStatus(status))"
    }

    var bluetoothPermissionHelpText: String {
        isChinese
            ? "读取已连接设备列表和信号强度需要蓝牙权限。"
            : "Bluetooth permission is required to read your connected device list and signal strength."
    }

    var accessibilityPermissionHelpText: String {
        isChinese
            ? "没有辅助功能权限，Zone 就无法帮你触发 macOS 锁屏。"
            : "Without Accessibility access, Zone cannot trigger macOS lock for you."
    }

    var requestAccessibilityAccessButtonTitle: String {
        isChinese ? "请求辅助功能权限" : "Request Accessibility Access"
    }

    var launchAtLoginTitle: String {
        isChinese ? "登录时启动" : "Launch at login"
    }

    var diagnosticsSectionTitle: String {
        isChinese ? "诊断" : "Diagnostics"
    }

    var noDiagnosticsYetText: String {
        isChinese ? "还没有诊断信息。" : "No diagnostics yet."
    }

    func localizedAppStatus(_ raw: String) -> String {
        switch raw {
        case "Not Configured":
            return isChinese ? "未配置" : raw
        case "Monitoring":
            return isChinese ? "监测中" : raw
        case "Paused":
            return isChinese ? "已暂停" : raw
        case "Locked":
            return isChinese ? "已锁屏" : raw
        case "Device Unavailable":
            return isChinese ? "设备不可用" : raw
        default:
            return raw
        }
    }

    func localizedSystemStatus(_ raw: String) -> String {
        switch raw {
        case "Allowed":
            return isChinese ? "已允许" : raw
        case "Denied":
            return isChinese ? "已拒绝" : raw
        case "Restricted":
            return isChinese ? "受限制" : raw
        case "Not Determined":
            return isChinese ? "未决定" : raw
        case "Unknown":
            return isChinese ? "未知" : raw
        case "Needs Approval":
            return isChinese ? "需要授权" : raw
        case "Enabled":
            return isChinese ? "已启用" : raw
        case "Requires Approval":
            return isChinese ? "需要批准" : raw
        case "Not Found":
            return isChinese ? "未找到" : raw
        case "Not Registered":
            return isChinese ? "未注册" : raw
        default:
            return raw
        }
    }
}
