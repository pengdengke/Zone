import AppKit
import Foundation

enum ZoneReleaseConfiguration {
    static let repositoryOwner = "pengdengke"
    static let repositoryName = "Zone"
    static let apiVersion = "2022-11-28"
    static let userAgent = "Zone"
}

struct AppVersionInfo: Equatable {
    let marketingVersion: String
    let buildVersion: String

    var displayText: String {
        if buildVersion == marketingVersion {
            return marketingVersion
        }

        return "\(marketingVersion) (\(buildVersion))"
    }
}

@MainActor
protocol AppVersionProviding {
    func currentVersion() -> AppVersionInfo
}

struct BundleAppVersionProvider: AppVersionProviding {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func currentVersion() -> AppVersionInfo {
        let marketingVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let buildVersion = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedMarketingVersion = marketingVersion?.isEmpty == false ? marketingVersion! : "0.0.0"
        let resolvedBuildVersion = buildVersion?.isEmpty == false ? buildVersion! : resolvedMarketingVersion

        return AppVersionInfo(
            marketingVersion: resolvedMarketingVersion,
            buildVersion: resolvedBuildVersion
        )
    }
}

struct ReleaseVersion: Equatable, Comparable {
    let normalizedString: String
    private let components: [Int]

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let candidate: String
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            candidate = String(trimmed.dropFirst())
        } else {
            candidate = trimmed
        }

        let rawComponents = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard rawComponents.count >= 2, rawComponents.count <= 3 else { return nil }

        var parsedComponents: [Int] = []
        for component in rawComponents {
            guard let value = Int(component) else { return nil }
            parsedComponents.append(value)
        }

        while parsedComponents.count < 3 {
            parsedComponents.append(0)
        }

        components = parsedComponents
        normalizedString = parsedComponents.map(String.init).joined(separator: ".")
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

struct GitHubRelease: Equatable {
    let tagName: String
    let htmlURL: URL
    let publishedAt: Date?

    var version: ReleaseVersion? {
        ReleaseVersion(string: tagName)
    }

    var displayVersion: String {
        version?.normalizedString ?? tagName
    }
}

@MainActor
protocol ReleaseChecking {
    func fetchLatestRelease() async throws -> GitHubRelease
}

enum ReleaseCheckError: Error {
    case invalidResponse
    case unexpectedStatusCode(Int)
    case invalidReleasePayload
}

struct LiveGitHubReleaseChecker: ReleaseChecking {
    let repositoryOwner: String
    let repositoryName: String
    let session: URLSession

    init(
        repositoryOwner: String = ZoneReleaseConfiguration.repositoryOwner,
        repositoryName: String = ZoneReleaseConfiguration.repositoryName,
        session: URLSession = .shared
    ) {
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
        self.session = session
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(ZoneReleaseConfiguration.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(ZoneReleaseConfiguration.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReleaseCheckError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ReleaseCheckError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LatestReleaseResponse.self, from: data)

        guard payload.draft == false, payload.prerelease == false else {
            throw ReleaseCheckError.invalidReleasePayload
        }

        return GitHubRelease(
            tagName: payload.tagName,
            htmlURL: payload.htmlURL,
            publishedAt: payload.publishedAt
        )
    }

    private struct LatestReleaseResponse: Decodable {
        let tagName: String
        let htmlURL: URL
        let publishedAt: Date?
        let draft: Bool
        let prerelease: Bool

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case publishedAt = "published_at"
            case draft
            case prerelease
        }
    }
}

@MainActor
protocol ReleasePageOpening {
    func open(_ url: URL)
}

struct LiveReleasePageOpener: ReleasePageOpening {
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

enum AppUpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable
    case failed
    case comparisonUnavailable
}
