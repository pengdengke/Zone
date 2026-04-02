import XCTest
@testable import Zone
import ZoneCore

final class AppStringsTests: XCTestCase {
    func testSimplifiedChineseStringsReturnTranslatedLabels() {
        let strings = AppStrings(language: .simplifiedChinese)

        XCTAssertEqual(strings.connectedDeviceSectionTitle, "已连接设备")
        XCTAssertEqual(strings.languageSectionTitle, "语言")
        XCTAssertEqual(strings.openSettingsButtonTitle, "打开设置")
        XCTAssertEqual(strings.bluetoothAccessLabelTitle, "蓝牙权限")
        XCTAssertEqual(strings.lockBelowLabelTitle, "低于此值锁屏")
        XCTAssertEqual(strings.lockThresholdValueTitle(-57), "-57 dBm")
    }

    func testEnglishStringsKeepExistingLabels() {
        let strings = AppStrings(language: .english)

        XCTAssertEqual(strings.connectedDeviceSectionTitle, "Connected Device")
        XCTAssertEqual(strings.languageSectionTitle, "Language")
        XCTAssertEqual(strings.openSettingsButtonTitle, "Open Settings")
        XCTAssertEqual(strings.bluetoothAccessLabelTitle, "Bluetooth access")
        XCTAssertEqual(strings.lockBelowLabelTitle, "Lock below")
        XCTAssertEqual(strings.signalLossTimeoutValueTitle(8), "8 s")
    }
}
