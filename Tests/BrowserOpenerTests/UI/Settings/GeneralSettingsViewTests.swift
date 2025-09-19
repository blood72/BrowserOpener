import XCTest
import SwiftUI
import ViewInspector
@testable import BrowserOpener


final class GeneralSettingsViewTests: XCTestCase {

    func test_body_showsToggles() throws {
        let sut = GeneralSettingsView()
        let toggles = try sut.inspect().findAll(ViewType.Toggle.self)
        // 규칙 사용 토글 + 프로필 목록 펼치기 토글 = 2개
        XCTAssertEqual(toggles.count, 2)
    }

    // MARK: - Import/Export Logic Tests

    func test_importExport_roundTrip() throws {
        // Setup isolated UserDefaults
        let suiteName = "GeneralSettingsViewTests_RoundTrip_\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create user defaults")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        // 1. Populate initial data
        defaults.set(true, forKey: "useRulesForAutomaticOpening")
        defaults.set(true, forKey: "browserList.showAll")

        // Populate Rules
        let rules = [URLRule(id: UUID(), pattern: "example.com", browserName: "Safari", isEnabled: true, browserIdentifier: "com.apple.Safari", sourceAppBundleIdentifier: nil)]
        let rulesSchema = RulesSchema(data: rules)
        let rulesData = try JSONEncoder().encode(rulesSchema)
        defaults.set(rulesData, forKey: "URLRules")

        // 2. Export
        let manager = SettingsImportExportManager.shared
        let exportedData = try manager.exportSettings(defaults: defaults)

        // Verify JSON structure
        let json = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["useRulesForAutomaticOpening"] as? Bool, true)

        // 3. Clear data
        defaults.removePersistentDomain(forName: suiteName)
        XCTAssertFalse(defaults.bool(forKey: "useRulesForAutomaticOpening")) // Default is false usually for bool(forKey:) if not set? No, strictly it's false.

        // 4. Import
        try manager.importSettings(from: exportedData, to: defaults)

        // 5. Verify restored
        XCTAssertTrue(defaults.bool(forKey: "useRulesForAutomaticOpening"))
        XCTAssertTrue(defaults.bool(forKey: "browserList.showAll"))

        let restoredRulesData = defaults.data(forKey: "URLRules")
        XCTAssertNotNil(restoredRulesData)
        if let restoredRulesData = restoredRulesData {
            let restoredSchema = try JSONDecoder().decode(RulesSchema.self, from: restoredRulesData)
            XCTAssertEqual(restoredSchema.data.first?.pattern, "example.com")
        }
    }
}
