import XCTest
import SwiftUI
@testable import BrowserOpener

final class WindowManagerTests: XCTestCase {

    var windowManager: WindowManager!
    var browserStore: BrowserStore!
    var rulesStore: RulesStore!
    var userDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        // Create an isolated UserDefaults suite
        suiteName = "WindowManagerTests_\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        browserStore = BrowserStore(userDefaults: userDefaults)
        rulesStore = RulesStore(userDefaults: userDefaults)
        windowManager = WindowManager(browserStore: browserStore, rulesStore: rulesStore)
    }

    override func tearDown() {
        windowManager = nil
        browserStore = nil
        rulesStore = nil
        if let name = suiteName {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        userDefaults = nil
        super.tearDown()
    }

    func test_init_setsStores() {
        XCTAssertNotNil(windowManager)
    }

    func test_showPicker_createsWindow() {
        // Since we are running in unit tests (likely headless or without full AppKit loop),
        // we mainly assume that the method runs without crashing.
        // We can inspect internal state if we expose browserManagers properly or mock them.
        // For now, we trust the side effect of showPicker which appends to browserManagers.

        let url = URL(string: "https://example.com")!

        // This execution might trigger UI logic. In a pure unit test environment without a host application,
        // UI tests (NSWindow creation) might be flaky. However, we proceed to verify logic execution.
        windowManager.showPicker(for: url, sourceAppBundleID: nil)

        // Access private property using Mirror if needed,
        // but looking at WindowManager.swift, browserManagers is private.
        // We can check if application windows count increased, but that's global state.

        // Reflection to check browserManagers count
        let mirror = Mirror(reflecting: windowManager!)
        if let browserManagers = mirror.children.first(where: { $0.label == "browserManagers" })?.value as? [BrowserManager] {
            XCTAssertEqual(browserManagers.count, 1)
        } else {
            XCTFail("Could not access browserManagers via Mirror")
        }
    }

    func test_showSettings_createsWindow() {
        windowManager.showSettings()

        // Reflection to check settingsWindow
        let mirror = Mirror(reflecting: windowManager!)
        if let settingsWindow = mirror.children.first(where: { $0.label == "settingsWindow" })?.value as? NSWindow {
            XCTAssertNotNil(settingsWindow)
            XCTAssertEqual(settingsWindow.title, "설정")
        } else {
            XCTFail("Could not access settingsWindow via Mirror")
        }
    }
}
