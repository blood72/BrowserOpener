import XCTest
@testable import BrowserOpener

final class RulesStoreTests: XCTestCase {

    func test_saveAndLoad_roundTripsRules() {
        let suiteName = "RulesStoreTests.saveAndLoad"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // given: 초기 스토어에 규칙을 설정
        var store: RulesStore? = RulesStore(userDefaults: defaults, storageKey: "URLRulesTest")
        store?.rules = [
            URLRule(pattern: "*.google.com", browserName: "Chrome"),
            URLRule(pattern: "github.com", browserName: "Safari", isEnabled: false)
        ]

        // when: 새 인스턴스로 다시 로드
        store = nil
        let reloadedStore = RulesStore(userDefaults: defaults, storageKey: "URLRulesTest")

        XCTAssertEqual(reloadedStore.rules.count, 2)
        XCTAssertEqual(reloadedStore.rules[0].pattern, "*.google.com")
        XCTAssertEqual(reloadedStore.rules[0].browserName, "Chrome")
        XCTAssertTrue(reloadedStore.rules[0].isEnabled)

        XCTAssertEqual(reloadedStore.rules[1].pattern, "github.com")
        XCTAssertEqual(reloadedStore.rules[1].browserName, "Safari")
        XCTAssertFalse(reloadedStore.rules[1].isEnabled)
    }

    func test_load_withCorruptedData_resetsToEmpty() {
        let suiteName = "RulesStoreTests.corruptedData"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // 손상된 데이터 저장
        defaults.set(Data([0x00, 0x01, 0x02, 0x03]), forKey: "URLRulesCorrupted")

        let store = RulesStore(userDefaults: defaults, storageKey: "URLRulesCorrupted")

        XCTAssertEqual(store.rules.count, 0)
    }

    func test_saveAndLoad_preservesBrowserMetadata() {
        let suiteName = "RulesStoreTests.metadata"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        var store: RulesStore? = RulesStore(userDefaults: defaults, storageKey: "URLRulesMeta")
        store?.rules = [
            URLRule(
                pattern: "workspace.dev",
                browserName: "Chrome",
                isEnabled: true,
                browserIdentifier: "chrome-id",
                browserProfileIdentifier: "profile-id"
            )
        ]

        store = nil

        let reloadedStore = RulesStore(userDefaults: defaults, storageKey: "URLRulesMeta")
        let rule = reloadedStore.rules.first

        XCTAssertEqual(rule?.browserIdentifier, "chrome-id")
        XCTAssertEqual(rule?.browserProfileIdentifier, "profile-id")
    }
}
