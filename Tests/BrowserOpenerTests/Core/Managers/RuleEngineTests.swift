import XCTest
@testable import BrowserOpener

final class RuleEngineTests: XCTestCase {

    func test_exactHostMatch_returnsExpectedBrowser() {
        let url = URL(string: "https://github.com/blood72")!
        let rules = [
            URLRule(pattern: "github.com", browserName: "Chrome")
        ]
        let installedBrowsers = [
            makePresetBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari"),
            makePresetBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
        ]

        let result = RuleEngine.pickBrowser(for: url, rules: rules, installedBrowsers: installedBrowsers)

        XCTAssertEqual(result?.0.name, "Chrome")
    }

    func test_subdomainWildcard_matchesSubdomainsAndRootDomain() {
        let subdomainURL = URL(string: "https://mail.google.com")!
        let rootURL = URL(string: "https://google.com")!
        let rules = [
            URLRule(pattern: "*.google.com", browserName: "Chrome")
        ]
        let installedBrowsers = [
            makePresetBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
        ]

        let subdomainResult = RuleEngine.pickBrowser(for: subdomainURL, rules: rules, installedBrowsers: installedBrowsers)
        let rootResult = RuleEngine.pickBrowser(for: rootURL, rules: rules, installedBrowsers: installedBrowsers)

        XCTAssertEqual(subdomainResult?.0.name, "Chrome")
        XCTAssertEqual(rootResult?.0.name, "Chrome", "bare 도메인 google.com 도 *.google.com 규칙에 매칭되어야 합니다.")
    }

    func test_localhostPortWildcard_matchesLocalhostWithAnyPort() {
        let urlWithPort = URL(string: "http://localhost:3000")!
        let urlWithoutPort = URL(string: "http://localhost")!
        let rules = [
            URLRule(pattern: "localhost:*", browserName: "Firefox")
        ]
        let installedBrowsers = [
            makePresetBrowser(name: "Firefox", bundleIdentifier: "org.mozilla.firefox")
        ]

        let resultWithPort = RuleEngine.pickBrowser(for: urlWithPort, rules: rules, installedBrowsers: installedBrowsers)
        let resultWithoutPort = RuleEngine.pickBrowser(for: urlWithoutPort, rules: rules, installedBrowsers: installedBrowsers)

        XCTAssertEqual(resultWithPort?.0.name, "Firefox")
        XCTAssertEqual(resultWithoutPort?.0.name, "Firefox")
    }

    func test_disabledRule_isSkipped_inFavorOfNextRule() {
        let url = URL(string: "https://example.com")!
        let rules = [
            URLRule(pattern: "example.com", browserName: "Chrome", isEnabled: false),
            URLRule(pattern: "example.com", browserName: "Safari", isEnabled: true)
        ]
        let installedBrowsers = [
            makePresetBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari"),
            makePresetBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
        ]

        let result = RuleEngine.pickBrowser(for: url, rules: rules, installedBrowsers: installedBrowsers)

        XCTAssertEqual(result?.0.name, "Safari")
    }

    func test_ruleWithUninstalledBrowser_isSkipped() {
        let url = URL(string: "https://dev.example.com")!
        let rules = [
            URLRule(pattern: "*.example.com", browserName: "Vivaldi"),
            URLRule(pattern: "*.example.com", browserName: "Safari")
        ]
        let installedBrowsers = [
            makePresetBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari")
            // Vivaldi 는 설치되지 않은 상태로 가정
        ]

        let result = RuleEngine.pickBrowser(for: url, rules: rules, installedBrowsers: installedBrowsers)

        XCTAssertEqual(result?.0.name, "Safari")
    }

    func test_defaultPortRule_onlyMatches80or443() {
        let urlHTTP = URL(string: "http://example.com")!
        let urlHTTPS = URL(string: "https://example.com")!
        let customPortURL = URL(string: "https://example.com:8443")!
        let rules = [
            URLRule(pattern: "example.com", browserName: "Safari")
        ]
        let browsers = [
            makePresetBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari")
        ]

        XCTAssertEqual(RuleEngine.pickBrowser(for: urlHTTP, rules: rules, installedBrowsers: browsers)?.0.name, "Safari")
        XCTAssertEqual(RuleEngine.pickBrowser(for: urlHTTPS, rules: rules, installedBrowsers: browsers)?.0.name, "Safari")
        XCTAssertNil(RuleEngine.pickBrowser(for: customPortURL, rules: rules, installedBrowsers: browsers))
    }

    func test_specificPortRule_matchesOnlyThatPort() {
        let matchURL = URL(string: "https://example.com:8443")!
        let missURL = URL(string: "https://example.com:8080")!
        let rules = [
            URLRule(pattern: "example.com:8443", browserName: "Chrome")
        ]
        let browsers = [
            makePresetBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
        ]

        XCTAssertEqual(RuleEngine.pickBrowser(for: matchURL, rules: rules, installedBrowsers: browsers)?.0.name, "Chrome")
        XCTAssertNil(RuleEngine.pickBrowser(for: missURL, rules: rules, installedBrowsers: browsers))
    }

    func test_anyPortRule_matchesAllPorts() {
        let url = URL(string: "https://example.com:9000")!
        let rules = [
            URLRule(pattern: "example.com:*", browserName: "Firefox")
        ]
        let browsers = [
            makePresetBrowser(name: "Firefox", bundleIdentifier: "org.mozilla.firefox")
        ]

        XCTAssertEqual(RuleEngine.pickBrowser(for: url, rules: rules, installedBrowsers: browsers)?.0.name, "Firefox")
    }

    func test_domainWildcardPattern_matchesRootAndNestedPaths() {
        let rootURL = URL(string: "https://focus.dev")!
        let nestedURL = URL(string: "https://focus.dev/docs/setup")!
        let rule = URLRule(pattern: "focus.dev/*", browserName: "Safari")
        let browsers = [
            makePresetBrowser(name: "Safari", bundleIdentifier: "com.apple.Safari")
        ]

        XCTAssertEqual(RuleEngine.pickBrowser(for: rootURL, rules: [rule], installedBrowsers: browsers)?.0.name, "Safari")
        XCTAssertEqual(RuleEngine.pickBrowser(for: nestedURL, rules: [rule], installedBrowsers: browsers)?.0.name, "Safari")
    }

    func test_segmentWildcardPattern_matchesSegmentItself() {
        let exactSegmentURL = URL(string: "https://focus.dev/v1")!
        let childURL = URL(string: "https://focus.dev/v1/changelog")!
        let rule = URLRule(pattern: "focus.dev/v1/*", browserName: "Chrome")
        let browsers = [
            makePresetBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
        ]

        XCTAssertEqual(RuleEngine.pickBrowser(for: exactSegmentURL, rules: [rule], installedBrowsers: browsers)?.0.name, "Chrome")
        XCTAssertEqual(RuleEngine.pickBrowser(for: childURL, rules: [rule], installedBrowsers: browsers)?.0.name, "Chrome")
    }

    func test_anyPortPathPattern_matchesCustomPortsWhileDefaultPatternDoesNot() {
        let customPortURL = URL(string: "https://focus.dev:9000/v1/docs")!
        let browsers = [
            makePresetBrowser(name: "Firefox", bundleIdentifier: "org.mozilla.firefox")
        ]

        let defaultRule = URLRule(pattern: "focus.dev/v1/*", browserName: "Firefox")
        XCTAssertNil(RuleEngine.pickBrowser(for: customPortURL, rules: [defaultRule], installedBrowsers: browsers))

        let anyPortRule = URLRule(pattern: "focus.dev:*/v1/*", browserName: "Firefox")
        XCTAssertEqual(RuleEngine.pickBrowser(for: customPortURL, rules: [anyPortRule], installedBrowsers: browsers)?.0.name, "Firefox")
    }

    func test_ruleWithProfile_returnsRequestedProfile() {
        let url = URL(string: "https://workspace.dev")!
        let profiles = [
            BrowserProfile(id: "default", name: "기본", launchArguments: [], isDefault: true, kind: .standard),
            BrowserProfile(id: "work", name: "업무", launchArguments: ["--profile-directory=Profile 2"], isDefault: false, kind: .custom)
        ]
        let browser = Browser(
            id: "com.example.chrome",
            name: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            iconName: "chrome",
            kind: .preset,
            isInstalled: true,
            profiles: profiles,
            defaultProfileID: "default"
        )
        let rule = URLRule(
            pattern: "workspace.dev",
            browserName: browser.name,
            isEnabled: true,
            browserIdentifier: browser.id,
            browserProfileIdentifier: "work",

        )

        let result = RuleEngine.pickBrowser(for: url, rules: [rule], installedBrowsers: [browser])

        XCTAssertEqual(result?.0.id, browser.id)
        XCTAssertEqual(result?.1?.id, "work")
    }

    func test_ruleWithMissingProfile_isSkipped() {
        let url = URL(string: "https://workspace.dev")!
        let profiles = [
            BrowserProfile(id: "default", name: "기본", launchArguments: [], isDefault: true, kind: .standard)
        ]
        let browser = Browser(
            id: "com.example.chrome",
            name: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            iconName: "chrome",
            kind: .preset,
            isInstalled: true,
            profiles: profiles,
            defaultProfileID: "default"
        )
        let rule = URLRule(
            pattern: "workspace.dev",
            browserName: browser.name,
            isEnabled: true,
            browserIdentifier: browser.id,
            browserProfileIdentifier: "ghost",

        )

        let result = RuleEngine.pickBrowser(for: url, rules: [rule], installedBrowsers: [browser])

        XCTAssertNil(result)
    }
}

private func makePresetBrowser(name: String, bundleIdentifier: String, isInstalled: Bool = true) -> Browser {
    Browser(
        id: bundleIdentifier,
        name: name,
        bundleIdentifier: bundleIdentifier,
        iconName: "app",
        kind: .preset,
        isInstalled: isInstalled
    )
}
