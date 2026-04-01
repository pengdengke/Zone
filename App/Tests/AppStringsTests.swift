import XCTest
@testable import Zone
import ZoneCore

final class AppStringsTests: XCTestCase {
    func testSimplifiedChineseStringsReturnTranslatedLabels() {
        let strings = AppStrings(language: .simplifiedChinese)

        XCTAssertEqual(strings.connectedDeviceSectionTitle, "已连接设备")
        XCTAssertEqual(strings.languageSectionTitle, "语言")
        XCTAssertEqual(strings.openSettingsButtonTitle, "打开设置")
    }

    func testEnglishStringsKeepExistingLabels() {
        let strings = AppStrings(language: .english)

        XCTAssertEqual(strings.connectedDeviceSectionTitle, "Connected Device")
        XCTAssertEqual(strings.languageSectionTitle, "Language")
        XCTAssertEqual(strings.openSettingsButtonTitle, "Open Settings")
    }
}
