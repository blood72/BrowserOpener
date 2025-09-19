import XCTest
@testable import BrowserOpener

final class BrowserStoreTests: XCTestCase {

    func test_addCustomBrowser_persistsBrowser() {
        let store = makeStore("addCustom")
        store.addCustomBrowser(name: "My Browser", bundleIdentifier: "com.example.mybrowser")

        XCTAssertTrue(store.browsers.contains { browser in
            browser.bundleIdentifier == "com.example.mybrowser" && browser.isCustom
        })
    }

    func test_setEnabled_persistsAcrossReloads() {
        let suiteName = "BrowserStoreTests.setEnabled"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create defaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        var store = BrowserStore(userDefaults: defaults)
        guard let safari = store.browsers.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) else {
            XCTFail("Safari preset missing")
            return
        }

        store.setEnabled(false, for: safari.id)

        store = BrowserStore(userDefaults: defaults)
        let updatedSafari = store.browsers.first(where: { $0.bundleIdentifier == "com.apple.Safari" })
        XCTAssertEqual(updatedSafari?.isEnabled, false)
    }

    func test_removeCustomBrowser_onlyAffectsCustomEntry() {
        let store = makeStore("removeCustom")
        store.addCustomBrowser(name: "Temp", bundleIdentifier: "com.example.temp")

        guard let custom = store.browsers.first(where: { $0.bundleIdentifier == "com.example.temp" }) else {
            XCTFail("Custom browser missing")
            return
        }

        store.removeCustomBrowser(id: custom.id)

        XCTAssertFalse(store.browsers.contains { $0.bundleIdentifier == "com.example.temp" })
    }

    func test_setHidden_onlyChangesPresetBrowsers() {
        let store = makeStore("setHidden")
        guard let safari = store.browsers.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) else {
            XCTFail("Safari preset missing")
            return
        }

        store.setHidden(true, for: safari.id)
        XCTAssertTrue(store.browser(withID: safari.id)?.isHidden ?? false)

        store.addCustomBrowser(name: "Custom", bundleIdentifier: "com.example.custom")
        guard let custom = store.browsers.first(where: { $0.bundleIdentifier == "com.example.custom" }) else {
            XCTFail("Custom missing")
            return
        }

        store.setHidden(true, for: custom.id)
        XCTAssertEqual(store.browser(withID: custom.id)?.isHidden, false)
    }

    func test_enabledRuleBrowsers_excludesHiddenOrDisabled() {
        let store = makeStore("enabledRuleBrowsers")
        guard let safari = store.browsers.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) else {
            XCTFail("Safari missing")
            return
        }

        XCTAssertTrue(store.enabledRuleBrowsers.contains { $0.id == safari.id })

        store.setHidden(true, for: safari.id)
        XCTAssertFalse(store.enabledRuleBrowsers.contains { $0.id == safari.id })

        store.setHidden(false, for: safari.id)
        store.setEnabled(false, for: safari.id)
        XCTAssertFalse(store.enabledRuleBrowsers.contains { $0.id == safari.id })
    }

    func test_updateBrowserMetadata_persistsDisplayNameAndProfiles() {
        let suiteName = "BrowserStoreTests.metadata"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create suite for \(suiteName)")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        var store = BrowserStore(userDefaults: defaults)
        guard let safari = store.browsers.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) else {
            XCTFail("Safari preset missing")
            return
        }

        let customProfiles = [
            BrowserProfile(id: "default", name: "기본", launchArguments: [], isDefault: true, kind: .standard),
            BrowserProfile(id: "work", name: "업무", launchArguments: ["--incognito"], isDefault: false, kind: .custom)
        ]

        store.updateBrowserMetadata(
            id: safari.id,
            displayName: "Safari+",
            bundleIdentifier: safari.bundleIdentifier,
            profiles: customProfiles,
            defaultProfileID: "work"
        )

        store = BrowserStore(userDefaults: defaults)
        guard let reloadedSafari = store.browsers.first(where: { $0.id == safari.id }) else {
            XCTFail("Safari missing after reload")
            return
        }

        XCTAssertEqual(reloadedSafari.name, "Safari+")
        XCTAssertEqual(reloadedSafari.profiles.count, 2)
        XCTAssertEqual(reloadedSafari.defaultProfile?.id, "work")
        XCTAssertEqual(reloadedSafari.profiles.last?.launchArguments, ["--incognito"])
    }

    private func makeStore(_ suffix: String) -> BrowserStore {
        let suiteName = "BrowserStoreTests.\(suffix)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create suite for \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return BrowserStore(userDefaults: defaults)
    }
}
