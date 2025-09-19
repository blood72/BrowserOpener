import XCTest
@testable import BrowserOpener

final class BrowserProfileTests: XCTestCase {
    func test_initialization() {
        let profile = BrowserProfile(
            id: "test-id",
            name: "Test Profile",
            launchArguments: ["--new-window"],
            isDefault: true,
            isEnabled: false,
            kind: .custom
        )

        XCTAssertEqual(profile.id, "test-id")
        XCTAssertEqual(profile.name, "Test Profile")
        XCTAssertEqual(profile.launchArguments, ["--new-window"])
        XCTAssertTrue(profile.isDefault)
        XCTAssertFalse(profile.isEnabled)
        XCTAssertEqual(profile.kind, .custom)
    }

    func test_initialization_withDefaults() {
        let profile = BrowserProfile(name: "Default Test")

        XCTAssertFalse(profile.id.isEmpty)
        XCTAssertEqual(profile.name, "Default Test")
        XCTAssertEqual(profile.launchArguments, [])
        XCTAssertFalse(profile.isDefault)
        XCTAssertTrue(profile.isEnabled)
        XCTAssertEqual(profile.kind, .standard)
    }

    func test_defaultProfile() {
        let bundleId = "com.apple.Safari"
        let profile = BrowserProfile.defaultProfile(forBundleIdentifier: bundleId)

        XCTAssertEqual(profile.id, "\(bundleId)#default")
        XCTAssertEqual(profile.name, "기본 프로필")
        XCTAssertEqual(profile.launchArguments, [])
        XCTAssertTrue(profile.isDefault)
        XCTAssertTrue(profile.isEnabled)
        XCTAssertEqual(profile.kind, .standard)
    }

    func test_kindEnum() {
        XCTAssertEqual(BrowserProfile.Kind.standard.rawValue, "standard")
        XCTAssertEqual(BrowserProfile.Kind.detected.rawValue, "detected")
        XCTAssertEqual(BrowserProfile.Kind.privateMode.rawValue, "privateMode")
        XCTAssertEqual(BrowserProfile.Kind.custom.rawValue, "custom")
    }

    func test_equatable() {
        let profile1 = BrowserProfile(
            id: "same-id",
            name: "Profile",
            launchArguments: [],
            isDefault: false,
            isEnabled: true,
            kind: .standard
        )
        let profile2 = BrowserProfile(
            id: "same-id",
            name: "Profile",
            launchArguments: [],
            isDefault: false,
            isEnabled: true,
            kind: .standard
        )
        let profile3 = BrowserProfile(
            id: "different-id",
            name: "Profile",
            launchArguments: [],
            isDefault: false,
            isEnabled: true,
            kind: .standard
        )

        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }
}
