import XCTest
@testable import BrowserOpener

final class URLRuleTests: XCTestCase {
    // MARK: - Initialization Tests

    func test_initialization() {
        let rule = URLRule(
            pattern: "*.example.com",
            browserName: "Safari",
            browserIdentifier: "com.apple.Safari",
            browserProfileIdentifier: "default",
            sourceAppBundleIdentifier: "com.apple.mail",
            sourceAppDisplayName: "Mail"
        )

        XCTAssertEqual(rule.pattern, "*.example.com")
        XCTAssertEqual(rule.browserName, "Safari")
        XCTAssertTrue(rule.isEnabled)
        XCTAssertEqual(rule.browserIdentifier, "com.apple.Safari")
        XCTAssertEqual(rule.browserProfileIdentifier, "default")
        XCTAssertEqual(rule.sourceAppBundleIdentifier, "com.apple.mail")
        XCTAssertEqual(rule.sourceAppDisplayName, "Mail")
    }

    func test_initialization_withDefaults() {
        let rule = URLRule(pattern: "example.com", browserName: "Chrome")

        XCTAssertNotNil(rule.id)
        XCTAssertEqual(rule.pattern, "example.com")
        XCTAssertEqual(rule.browserName, "Chrome")
        XCTAssertTrue(rule.isEnabled)
        XCTAssertNil(rule.browserIdentifier)
        XCTAssertNil(rule.browserProfileIdentifier)
        XCTAssertNil(rule.sourceAppBundleIdentifier)
        XCTAssertNil(rule.sourceAppDisplayName)
    }

    func test_initialization_withCustomID() {
        let customID = UUID()
        let rule = URLRule(id: customID, pattern: "test.com", browserName: "Firefox")

        XCTAssertEqual(rule.id, customID)
    }

    // MARK: - Computed Properties Tests

    func test_preferredBrowserName_withBrowserIdentifier() {
        let rule = URLRule(
            pattern: "example.com",
            browserName: "Safari",
            browserIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(rule.preferredBrowserName, "com.apple.Safari")
    }

    func test_preferredBrowserName_withoutBrowserIdentifier() {
        let rule = URLRule(pattern: "example.com", browserName: "Safari")

        XCTAssertEqual(rule.preferredBrowserName, "Safari")
    }

    func test_preferredSourceAppName_withDisplayName() {
        let rule = URLRule(
            pattern: "example.com",
            browserName: "Safari",
            sourceAppBundleIdentifier: "com.apple.mail",
            sourceAppDisplayName: "Mail"
        )

        XCTAssertEqual(rule.preferredSourceAppName, "Mail")
    }

    func test_preferredSourceAppName_withOnlyBundleIdentifier() {
        let rule = URLRule(
            pattern: "example.com",
            browserName: "Safari",
            sourceAppBundleIdentifier: "com.apple.mail"
        )

        XCTAssertEqual(rule.preferredSourceAppName, "com.apple.mail")
    }

    func test_preferredSourceAppName_withNoSourceApp() {
        let rule = URLRule(pattern: "example.com", browserName: "Safari")

        XCTAssertNil(rule.preferredSourceAppName)
    }

    // MARK: - Sample Rules Tests

    func test_sampleRules() {
        let samples = URLRule.sampleRules

        XCTAssertEqual(samples.count, 3)
        XCTAssertTrue(samples.contains { $0.pattern == "*.google.com" && $0.browserName == "Chrome" })
        XCTAssertTrue(samples.contains { $0.pattern == "*.github.com" && $0.browserName == "Safari" })
        XCTAssertTrue(samples.contains { $0.pattern == "localhost:*" && $0.browserName == "Firefox" })
    }

    // MARK: - Equatable Tests

    func test_equatable() {
        let id = UUID()
        let rule1 = URLRule(id: id, pattern: "example.com", browserName: "Safari")
        let rule2 = URLRule(id: id, pattern: "example.com", browserName: "Safari")
        let rule3 = URLRule(pattern: "example.com", browserName: "Safari") // 다른 ID

        XCTAssertEqual(rule1, rule2)
        XCTAssertNotEqual(rule1, rule3) // ID가 다르므로 다름
    }

    // MARK: - Codable Tests

    func test_encode() throws {
        let rule = URLRule(
            pattern: "*.test.com",
            browserName: "Chrome",
            browserIdentifier: "com.google.Chrome",
            browserProfileIdentifier: "profile1",
            sourceAppBundleIdentifier: "com.app.source",
            sourceAppDisplayName: "Source App"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["pattern"] as? String, "*.test.com")
        XCTAssertEqual(json?["browserName"] as? String, "Chrome")
        XCTAssertEqual(json?["browserIdentifier"] as? String, "com.google.Chrome")
        XCTAssertEqual(json?["browserProfileIdentifier"] as? String, "profile1")
        XCTAssertEqual(json?["sourceAppBundleIdentifier"] as? String, "com.app.source")
        XCTAssertEqual(json?["sourceAppDisplayName"] as? String, "Source App")
        XCTAssertNil(json?["id"]) // ID는 인코딩에서 제외됨
    }

    func test_decode() throws {
        let json = """
        {
            "pattern": "*.decoded.com",
            "browserName": "Firefox",
            "isEnabled": false,
            "browserIdentifier": "org.mozilla.firefox"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let rule = try decoder.decode(URLRule.self, from: json)

        XCTAssertEqual(rule.pattern, "*.decoded.com")
        XCTAssertEqual(rule.browserName, "Firefox")
        XCTAssertFalse(rule.isEnabled)
        XCTAssertEqual(rule.browserIdentifier, "org.mozilla.firefox")
        XCTAssertNotNil(rule.id) // 디코딩 시 새 ID 생성
    }

    func test_decode_withDefaultIsEnabled() throws {
        let json = """
        {
            "pattern": "example.com",
            "browserName": "Safari"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let rule = try decoder.decode(URLRule.self, from: json)

        XCTAssertTrue(rule.isEnabled) // 기본값 true
    }
}
