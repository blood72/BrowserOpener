import Foundation

struct URLRule: Identifiable, Codable, Equatable {
    let id: UUID
    var pattern: String
    var browserName: String
    var isEnabled: Bool
    var browserIdentifier: String?
    var browserProfileIdentifier: String?
    var sourceAppBundleIdentifier: String?  // nil = 모든 앱
    var sourceAppDisplayName: String?

    init(
        id: UUID = UUID(),
        pattern: String,
        browserName: String,
        isEnabled: Bool = true,
        browserIdentifier: String? = nil,
        browserProfileIdentifier: String? = nil,
        sourceAppBundleIdentifier: String? = nil,
        sourceAppDisplayName: String? = nil
    ) {
        self.id = id
        self.pattern = pattern
        self.browserName = browserName
        self.isEnabled = isEnabled
        self.browserIdentifier = browserIdentifier
        self.browserProfileIdentifier = browserProfileIdentifier
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
        self.sourceAppDisplayName = sourceAppDisplayName
    }

    private enum CodingKeys: String, CodingKey {
        case pattern, browserName, isEnabled, browserIdentifier, browserProfileIdentifier, sourceAppBundleIdentifier, sourceAppDisplayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // ID는 로컬에서만 사용, JSON에는 포함하지 않음
        self.pattern = try container.decode(String.self, forKey: .pattern)
        self.browserName = try container.decode(String.self, forKey: .browserName)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.browserIdentifier = try container.decodeIfPresent(String.self, forKey: .browserIdentifier)
        self.browserProfileIdentifier = try container.decodeIfPresent(String.self, forKey: .browserProfileIdentifier)
        self.sourceAppBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleIdentifier)
        self.sourceAppDisplayName = try container.decodeIfPresent(String.self, forKey: .sourceAppDisplayName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pattern, forKey: .pattern)
        try container.encode(browserName, forKey: .browserName)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(browserIdentifier, forKey: .browserIdentifier)
        try container.encode(browserProfileIdentifier, forKey: .browserProfileIdentifier)
        try container.encode(sourceAppBundleIdentifier, forKey: .sourceAppBundleIdentifier)
        try container.encode(sourceAppDisplayName, forKey: .sourceAppDisplayName)
    }

    static let sampleRules: [URLRule] = [
        URLRule(pattern: "*.google.com", browserName: "Chrome"),
        URLRule(pattern: "*.github.com", browserName: "Safari"),
        URLRule(pattern: "localhost:*", browserName: "Firefox")
    ]

    /// 브라우저 이름 (browserIdentifier 또는 browserName)
    var preferredBrowserName: String {
        browserIdentifier ?? browserName
    }

    var preferredSourceAppName: String? {
        sourceAppDisplayName ?? sourceAppBundleIdentifier
    }
}
