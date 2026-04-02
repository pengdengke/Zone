import XCTest
@testable import Zone

final class AppUpdateSupportTests: XCTestCase {
    func testReleaseVersionParsesVPrefixedSemanticVersion() {
        let version = ReleaseVersion(string: "v1.2.3")

        XCTAssertEqual(version?.normalizedString, "1.2.3")
    }

    func testReleaseVersionComparisonUsesNumericOrdering() {
        let newer = ReleaseVersion(string: "1.10.0")
        let older = ReleaseVersion(string: "1.2.9")

        XCTAssertTrue(newer! > older!)
    }

    func testGitHubReleaseDisplayVersionFallsBackToTagWhenVersionCannotBeParsed() {
        let release = GitHubRelease(
            tagName: "release-2026-04-02",
            htmlURL: URL(string: "https://github.com/pengdengke/Zone/releases/tag/release-2026-04-02")!,
            publishedAt: nil
        )

        XCTAssertEqual(release.displayVersion, "release-2026-04-02")
        XCTAssertNil(release.version)
    }
}
