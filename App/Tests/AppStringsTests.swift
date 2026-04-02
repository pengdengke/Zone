import XCTest
@testable import Zone
import ZoneCore

final class AppStringsTests: XCTestCase {
    func testSimplifiedChineseStringsReturnTranslatedLabels() {
        let strings = AppStrings(language: .simplifiedChinese)

        XCTAssertEqual(strings.connectedDeviceSectionTitle, "已连接设备")
        XCTAssertEqual(strings.languageSectionTitle, "语言")
        XCTAssertEqual(strings.versionSectionTitle, "版本与更新")
        XCTAssertEqual(strings.openSettingsButtonTitle, "打开设置")
        XCTAssertEqual(strings.bluetoothAccessLabelTitle, "蓝牙权限")
        XCTAssertEqual(strings.currentVersionLabelTitle, "当前版本")
        XCTAssertEqual(strings.checkForUpdatesButtonTitle, "检查更新")
        XCTAssertEqual(strings.lockBelowLabelTitle, "低于此值锁屏")
        XCTAssertEqual(strings.lockThresholdValueTitle(-57), "-57 dBm")
    }

    func testEnglishStringsKeepExistingLabels() {
        let strings = AppStrings(language: .english)

        XCTAssertEqual(strings.connectedDeviceSectionTitle, "Connected Device")
        XCTAssertEqual(strings.languageSectionTitle, "Language")
        XCTAssertEqual(strings.versionSectionTitle, "Version & Updates")
        XCTAssertEqual(strings.openSettingsButtonTitle, "Open Settings")
        XCTAssertEqual(strings.bluetoothAccessLabelTitle, "Bluetooth access")
        XCTAssertEqual(strings.currentVersionLabelTitle, "Current version")
        XCTAssertEqual(strings.checkForUpdatesButtonTitle, "Check for Updates")
        XCTAssertEqual(strings.lockBelowLabelTitle, "Lock below")
        XCTAssertEqual(strings.signalLossTimeoutValueTitle(8), "8 s")
    }
}
