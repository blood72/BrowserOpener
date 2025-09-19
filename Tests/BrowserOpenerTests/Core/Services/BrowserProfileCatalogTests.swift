import XCTest
@testable import BrowserOpener

// Mock FileReader
class MockProfileFileReader: ProfileFileReader {
    var files: [String: Data] = [:]
    var simulatedHomeDirectory: URL = URL(fileURLWithPath: "/Users/mockuser")

    var homeDirectoryForCurrentUser: URL {
        simulatedHomeDirectory
    }

    func data(contentsOf url: URL) throws -> Data {
        if let data = files[url.path] {
            return data
        }
        throw NSError(domain: "MockProfileFileReader", code: 404, userInfo: nil)
    }

    func string(contentsOf url: URL, encoding: String.Encoding) throws -> String {
        guard let data = try? data(contentsOf: url) else {
            throw NSError(domain: "MockProfileFileReader", code: 404, userInfo: nil)
        }
        return String(data: data, encoding: encoding) ?? ""
    }
}

final class BrowserProfileCatalogTests: XCTestCase {

    var mockReader: MockProfileFileReader!

    override func setUp() {
        super.setUp()
        mockReader = MockProfileFileReader()
    }

    // Test 1: Safari - Always returns default profile
    func test_profiles_safari_returnsDefaultProfile() {
        let profiles = BrowserProfileCatalog.profiles(
            forBundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            fileReader: mockReader
        )

        XCTAssertEqual(profiles.count, 1)
        XCTAssertTrue(profiles.first?.isDefault ?? false)
        XCTAssertEqual(profiles.first?.id, "com.apple.Safari#default")
    }

    // Test 2: Unknown Browser - Returns default profile
    func test_profiles_unknownBrowser_returnsDefaultProfile() {
        let profiles = BrowserProfileCatalog.profiles(
            forBundleIdentifier: "com.example.Browser",
            displayName: "Example Browser",
            fileReader: mockReader
        )

        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.id, "com.example.Browser#default")
    }

    // Test 3: Chromium (e.g. Chrome) - Detects profiles from Local State
    func test_profiles_chromium_returnsDetectedProfiles() {
        // Setup mock "Local State" file
        let jsonString = """
        {
            "profile": {
                "info_cache": {
                    "Default": { "name": "Person 1" },
                    "Profile 2": { "name": "Work" }
                }
            }
        }
        """
        let chromePath = mockReader.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/Local State")
            .path

        mockReader.files[chromePath] = jsonString.data(using: .utf8)

        let profiles = BrowserProfileCatalog.profiles(
            forBundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            fileReader: mockReader
        )

        // Expected: Default, Work, and Incognito (added by logic)
        // Note: Default profile logic in detectChromiumProfiles handles "default" case-insensitively for isDefault.
        // And chromiumProfiles adds "Incognito" if not present.

        XCTAssertTrue(profiles.count >= 3)

        let defaultProfile = profiles.first { $0.id == "com.google.Chrome#Default" }
        XCTAssertNotNil(defaultProfile)
        XCTAssertEqual(defaultProfile?.name, "Person 1")
        XCTAssertTrue(defaultProfile?.isDefault ?? false)

        let workProfile = profiles.first { $0.id == "com.google.Chrome#Profile 2" }
        XCTAssertNotNil(workProfile)
        XCTAssertEqual(workProfile?.name, "Work")

        let incognito = profiles.first { $0.kind == .privateMode }
        XCTAssertNotNil(incognito)
    }

    // Test 4: Firefox - Detects profiles from profiles.ini
    func test_profiles_firefox_returnsDetectedProfiles() {
        let iniString = """
        [Profile0]
        Name=default-release
        Default=1

        [Profile1]
        Name=dev-edition-default
        Default=0
        """

        let firefoxPath = mockReader.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Firefox/profiles.ini")
            .path

        mockReader.files[firefoxPath] = iniString.data(using: .utf8)

        let profiles = BrowserProfileCatalog.profiles(
            forBundleIdentifier: "org.mozilla.firefox",
            displayName: "Firefox",
            fileReader: mockReader
        )

        // Expected: default-release, dev-edition-default, and Private
        XCTAssertTrue(profiles.count >= 3)

        let defaultProfile = profiles.first { $0.id == "org.mozilla.firefox#default-release" }
        XCTAssertNotNil(defaultProfile)
        XCTAssertTrue(defaultProfile?.isDefault ?? false)

        let devProfile = profiles.first { $0.id == "org.mozilla.firefox#dev-edition-default" }
        XCTAssertNotNil(devProfile)

        let privateProfile = profiles.first { $0.kind == .privateMode }
        XCTAssertNotNil(privateProfile)
    }

    // Test 5: Chromium - Missing file returns default + incognito
    func test_profiles_chromium_missingFile_returnsDefaultAndIncognito() {
        let profiles = BrowserProfileCatalog.profiles(
            forBundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            fileReader: mockReader
        )

        // Should contain default fallback and incognito
        XCTAssertTrue(profiles.contains { $0.kind == .standard }) // Fallback default
        XCTAssertTrue(profiles.contains { $0.kind == .privateMode })
    }
}
