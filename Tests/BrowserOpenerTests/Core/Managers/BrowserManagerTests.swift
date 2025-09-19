import XCTest
@testable import BrowserOpener

final class BrowserManagerTests: XCTestCase {

    func test_availableBrowsers_containsAllExpectedBrowsers() {
        let expected: [(name: String, bundleId: String)] = [
            ("Safari", "com.apple.Safari"),
            ("Chrome", "com.google.Chrome"),
            ("Firefox", "org.mozilla.firefox"),
            ("Vivaldi", "com.vivaldi.Vivaldi")
        ]
        let presets = Browser.presetBrowsers()
        for item in expected {
            let exists = presets.contains { $0.name == item.name && $0.bundleIdentifier == item.bundleId }
            XCTAssertTrue(exists, "Missing expected browser: \(item.name) [\(item.bundleId)]")
        }
    }

    func test_availableBrowsers_bundleIdentifiersAreUniqueAndNonEmpty() {
        let ids = Browser.presetBrowsers().map { $0.bundleIdentifier }
        XCTAssertFalse(ids.contains(where: { $0.isEmpty }))
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_availableBrowsers_namesAndIconNamesAreNonEmpty() {
        XCTAssertFalse(Browser.presetBrowsers().contains { $0.name.isEmpty || $0.iconName.isEmpty })
    }

    func test_installedBrowsers_onlyContainItemsMarkedInstalled() {
        let manager = BrowserManager(browserStore: makeStore())
        XCTAssertTrue(manager.installedBrowsers.allSatisfy { $0.isInstalled })
    }

    func test_isAppInstalled_returnsFalseForNonexistentBundleId() {
        XCTAssertFalse(Browser.isAppInstalled(bundleId: "xyz.example.nonexistent.dev.app"))
    }

    func test_loadInstalledBrowsers_includesSafari() {
        let manager = BrowserManager(browserStore: makeStore())
        XCTAssertTrue(manager.installedBrowsers.contains { $0.bundleIdentifier == "com.apple.Safari" })
    }

    func test_appIcon_isNil_whenAppNotInstalled() {
        let browser = Browser(
            id: "dummy-app",
            name: "Dummy",
            bundleIdentifier: "xyz.example.nonexistent.dev.app",
            iconName: "app",
            kind: .custom,
            isInstalled: false
        )
        XCTAssertNil(browser.appIcon)
    }

    func test_updateURL_setsCurrentURL() {
        let manager = BrowserManager(browserStore: makeStore())
        manager.updateURL("https://example.com")
        XCTAssertEqual(manager.currentURL, "https://example.com")

        manager.updateURL("")
        manager.updateURL("https://first.example")
        manager.updateURL("https://second.example")
        XCTAssertEqual(manager.currentURL, "https://second.example")
    }

    func test_openURL_edgeInputs_returnEarly_withoutCrash() {
        let manager = BrowserManager(browserStore: makeStore())
        let dummy = Browser(
            id: "dummy",
            name: "Dummy",
            bundleIdentifier: "com.example.dummy",
            iconName: "app",
            kind: .custom,
            isInstalled: true
        )
        let inputs = ["", "   ", "\n", "not a url", "😃"]
        for input in inputs {
            manager.openURL(input, with: dummy)
        }
        XCTAssertTrue(true)
    }

    func test_openURL_validURL_withNonexistentBundle_returnsEarly_withoutCrash() {
        let manager = BrowserManager(browserStore: makeStore())
        let dummy = Browser(
            id: "dummy-nonexistent",
            name: "Dummy",
            bundleIdentifier: "xyz.example.nonexistent.dev.app",
            iconName: "app",
            kind: .custom,
            isInstalled: true
        )
        manager.openURL("https://example.com", with: dummy)
        XCTAssertTrue(true)
    }

    private func makeStore(_ name: String = #function) -> BrowserStore {
        let suiteName = "BrowserManagerTests.\(name)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create suite for tests")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return BrowserStore(userDefaults: defaults)
    }
}
