import XCTest
@testable import BrowserOpener

final class BrowserTests: XCTestCase {
    // MARK: - Initialization Tests

    func test_initialization() {
        let browser = Browser(
            id: "test",
            name: "Test Browser",
            bundleIdentifier: "com.test.browser",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )

        XCTAssertEqual(browser.id, "com.test.browser") // ID는 항상 bundleIdentifier 사용
        XCTAssertEqual(browser.name, "Test Browser")
        XCTAssertEqual(browser.bundleIdentifier, "com.test.browser")
        XCTAssertEqual(browser.iconName, "icon")
        XCTAssertEqual(browser.kind, .custom)
        XCTAssertTrue(browser.isInstalled)
        XCTAssertTrue(browser.isEnabled)
        XCTAssertFalse(browser.isHidden)
    }

    func test_initialization_withDefaults() {
        let browser = Browser(
            name: "Default Browser",
            bundleIdentifier: "com.default.browser",
            iconName: "default-icon",
            kind: .preset,
            isInstalled: true
        )

        XCTAssertEqual(browser.id, "com.default.browser")
        XCTAssertTrue(browser.isEnabled)
        XCTAssertFalse(browser.isHidden)
        XCTAssertFalse(browser.profiles.isEmpty)
        XCTAssertNotNil(browser.defaultProfileID)
    }

    func test_initialization_disabledWhenNotInstalled() {
        let browser = Browser(
            name: "Not Installed Browser",
            bundleIdentifier: "com.notinstalled",
            iconName: "icon",
            kind: .custom,
            isInstalled: false,
            isEnabled: true // 설치되지 않으면 isEnabled가 false가 되어야 함
        )

        XCTAssertFalse(browser.isInstalled)
        XCTAssertFalse(browser.isEnabled) // 설치되지 않으면 항상 비활성화
    }

    // MARK: - Kind Enum Tests

    func test_kindEnum() {
        XCTAssertEqual(Browser.Kind.preset.rawValue, "preset")
        XCTAssertEqual(Browser.Kind.custom.rawValue, "custom")
    }

    // MARK: - Computed Properties Tests

    func test_isPreset() {
        let presetBrowser = Browser(
            name: "Preset",
            bundleIdentifier: "com.preset",
            iconName: "icon",
            kind: .preset,
            isInstalled: true
        )

        XCTAssertTrue(presetBrowser.isPreset)
        XCTAssertFalse(presetBrowser.isCustom)
    }

    func test_isCustom() {
        let customBrowser = Browser(
            name: "Custom",
            bundleIdentifier: "com.custom",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )

        XCTAssertTrue(customBrowser.isCustom)
        XCTAssertFalse(customBrowser.isPreset)
    }

    func test_isUnsupportedBrowser() {
        let safari = Browser(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            iconName: "safari",
            kind: .preset,
            isInstalled: true
        )
        let chrome = Browser(
            name: "Chrome",
            bundleIdentifier: "com.google.Chrome",
            iconName: "chrome",
            kind: .preset,
            isInstalled: true
        )

        XCTAssertTrue(safari.isUnsupportedBrowser)
        XCTAssertFalse(chrome.isUnsupportedBrowser)
    }

    // MARK: - Default Profile Tests

    func test_defaultProfile_returnsFirstEnabledProfile() {
        let profile1 = BrowserProfile(id: "p1", name: "Profile 1", isDefault: false, isEnabled: false)
        let profile2 = BrowserProfile(id: "p2", name: "Profile 2", isDefault: false, isEnabled: true)
        let browser = Browser(
            name: "Browser",
            bundleIdentifier: "com.test",
            iconName: "icon",
            kind: .custom,
            isInstalled: true,
            profiles: [profile1, profile2]
        )

        XCTAssertEqual(browser.defaultProfile?.id, "p2")
    }

    func test_defaultProfile_prefersDefaultProfileID() {
        let profile1 = BrowserProfile(id: "p1", name: "Profile 1", isDefault: true, isEnabled: true)
        let profile2 = BrowserProfile(id: "p2", name: "Profile 2", isDefault: false, isEnabled: true)
        let browser = Browser(
            name: "Browser",
            bundleIdentifier: "com.test",
            iconName: "icon",
            kind: .custom,
            isInstalled: true,
            profiles: [profile1, profile2],
            defaultProfileID: "p2"
        )

        XCTAssertEqual(browser.defaultProfile?.id, "p2")
    }

    // MARK: - Equatable Tests

    func test_equatable() {
        let browser1 = Browser(
            name: "Browser",
            bundleIdentifier: "com.same",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )
        let browser2 = Browser(
            name: "Browser",
            bundleIdentifier: "com.same",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )
        let browser3 = Browser(
            name: "Browser",
            bundleIdentifier: "com.different",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )

        XCTAssertEqual(browser1, browser2)
        XCTAssertNotEqual(browser1, browser3)
    }

    // MARK: - Sorting Rule Tests

    func test_sortingRule_installedFirst() {
        let installed = Browser(
            name: "Installed",
            bundleIdentifier: "com.installed",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )
        let notInstalled = Browser(
            name: "Not Installed",
            bundleIdentifier: "com.notinstalled",
            iconName: "icon",
            kind: .custom,
            isInstalled: false
        )

        XCTAssertTrue(Browser.sortingRule(installed, notInstalled))
        XCTAssertFalse(Browser.sortingRule(notInstalled, installed))
    }

    func test_sortingRule_presetFirst() {
        let preset = Browser(
            name: "Preset",
            bundleIdentifier: "com.preset",
            iconName: "icon",
            kind: .preset,
            isInstalled: true
        )
        let custom = Browser(
            name: "Custom",
            bundleIdentifier: "com.custom",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )

        XCTAssertTrue(Browser.sortingRule(preset, custom))
        XCTAssertFalse(Browser.sortingRule(custom, preset))
    }

    func test_sortingRule_alphabeticalOrder() {
        let browserA = Browser(
            name: "Alpha",
            bundleIdentifier: "com.alpha",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )
        let browserB = Browser(
            name: "Beta",
            bundleIdentifier: "com.beta",
            iconName: "icon",
            kind: .custom,
            isInstalled: true
        )

        XCTAssertTrue(Browser.sortingRule(browserA, browserB))
        XCTAssertFalse(Browser.sortingRule(browserB, browserA))
    }

    // MARK: - Preset Browsers Tests

    func test_presetBrowsers() {
        let presets = Browser.presetBrowsers()

        XCTAssertEqual(presets.count, 4)
        XCTAssertTrue(presets.allSatisfy { $0.isPreset })
        XCTAssertTrue(presets.contains { $0.bundleIdentifier == "com.apple.Safari" })
        XCTAssertTrue(presets.contains { $0.bundleIdentifier == "com.google.Chrome" })
        XCTAssertTrue(presets.contains { $0.bundleIdentifier == "org.mozilla.firefox" })
        XCTAssertTrue(presets.contains { $0.bundleIdentifier == "com.vivaldi.Vivaldi" })
    }
}
