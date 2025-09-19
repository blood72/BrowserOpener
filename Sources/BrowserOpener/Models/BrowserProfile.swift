import Foundation
import AppKit

struct BrowserProfile: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case standard
        case detected
        case privateMode
        case custom
    }

    var id: String
    var name: String
    var launchArguments: [String]
    var isDefault: Bool
    var isEnabled: Bool
    var kind: Kind

    init(
        id: String = UUID().uuidString,
        name: String,
        launchArguments: [String] = [],
        isDefault: Bool = false,
        isEnabled: Bool = true,
        kind: Kind = .standard
    ) {
        self.id = id
        self.name = name
        self.launchArguments = launchArguments
        self.isDefault = isDefault
        self.isEnabled = isEnabled
        self.kind = kind
    }
}

extension BrowserProfile {
    static func defaultProfile(forBundleIdentifier bundleIdentifier: String) -> BrowserProfile {
        BrowserProfile(
            id: "\(bundleIdentifier)#default",
            name: "기본 프로필",
            launchArguments: [],
            isDefault: true,
            kind: .standard
        )
    }
}
