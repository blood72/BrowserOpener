import Foundation
import AppKit

struct Browser: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case preset
        case custom
    }

    var id: String
    var name: String
    var bundleIdentifier: String
    var iconName: String
    var kind: Kind
    var isInstalled: Bool
    var isEnabled: Bool
    var isHidden: Bool
    var profiles: [BrowserProfile]
    var defaultProfileID: String?

    var isPreset: Bool { kind == .preset }
    var isCustom: Bool { kind == .custom }

    /// 현재 프로젝트에서 프로필 편집을 지원하지 않는 브라우저인지 여부
    /// V1: Safari는 명령줄 인자를 지원하지 않아 지원하지 않음
    var isUnsupportedBrowser: Bool {
        bundleIdentifier == "com.apple.Safari"
    }

    var defaultProfile: BrowserProfile? {
        let enabledProfiles = profiles.filter { $0.isEnabled }
        if let defaultProfileID,
           let matchedProfile = enabledProfiles.first(where: { $0.id == defaultProfileID }) {
            return matchedProfile
        }
        return enabledProfiles.first(where: { $0.isDefault }) ?? enabledProfiles.first
    }

    init(
        id: String? = nil,
        name: String,
        bundleIdentifier: String,
        iconName: String,
        kind: Kind,
        isInstalled: Bool,
        isEnabled: Bool = true,
        isHidden: Bool = false,
        profiles: [BrowserProfile]? = nil,
        defaultProfileID: String? = nil
    ) {
        self.id = bundleIdentifier // ID는 항상 Bundle Identifier를 사용
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.iconName = iconName
        self.kind = kind
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled && isInstalled
        self.isHidden = isHidden
        let resolvedProfiles = profiles ?? BrowserProfileCatalog.profiles(
            forBundleIdentifier: bundleIdentifier,
            displayName: name
        )
        self.profiles = resolvedProfiles.isEmpty
            ? [BrowserProfile.defaultProfile(forBundleIdentifier: bundleIdentifier)]
            : resolvedProfiles
        if let defaultProfileID {
            self.defaultProfileID = defaultProfileID
        } else {
            self.defaultProfileID = self.profiles.first(where: { $0.isDefault })?.id ?? self.profiles.first?.id
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) {
            self.id = bundleIdentifier
        } else if let decodedID = try container.decodeIfPresent(String.self, forKey: .id) {
            // Legacy: ID가 있으면 그것을 사용하되, bundleIdentifier가 없으면 ID를 bundleIdentifier로 가정
            self.id = decodedID
        } else {
            self.id = UUID().uuidString
        }
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Browser"
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? ""
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "app.fill"

        if let decodedKind = try container.decodeIfPresent(Kind.self, forKey: .kind) {
            self.kind = decodedKind
        } else {
            let legacyIsCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
            self.kind = legacyIsCustom ? .custom : .preset
        }

        let decodedInstalled = try container.decodeIfPresent(Bool.self, forKey: .isInstalled)
        let computedInstalled = Browser.isAppInstalled(bundleId: bundleIdentifier)
        self.isInstalled = decodedInstalled ?? computedInstalled
        let decodedEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled)
        self.isEnabled = (decodedEnabled ?? self.isInstalled) && self.isInstalled
        self.isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        if let decodedProfiles = try container.decodeIfPresent([BrowserProfile].self, forKey: .profiles),
           !decodedProfiles.isEmpty {
            self.profiles = decodedProfiles
        } else {
            self.profiles = BrowserProfileCatalog.profiles(forBundleIdentifier: bundleIdentifier, displayName: name)
        }
        self.defaultProfileID = try container.decodeIfPresent(String.self, forKey: .defaultProfileID)
            ?? self.profiles.first(where: { $0.isDefault })?.id
            ?? self.profiles.first?.id
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(kind, forKey: .kind)
        try container.encode(isInstalled, forKey: .isInstalled)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(defaultProfileID, forKey: .defaultProfileID)
    }

    var appIcon: NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    static func isAppInstalled(bundleId: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case bundleIdentifier
        case iconName
        case kind
        case isInstalled
        case isEnabled
        case isHidden
        case profiles
        case defaultProfileID
        case isCustom
    }
}

extension Browser {
    static func presetBrowsers() -> [Browser] {
        [
            Browser.preset(name: "Safari", bundleIdentifier: "com.apple.Safari", iconName: "safari", assumesInstalled: true),
            Browser.preset(name: "Chrome", bundleIdentifier: "com.google.Chrome", iconName: "chrome"),
            Browser.preset(name: "Firefox", bundleIdentifier: "org.mozilla.firefox", iconName: "firefox"),
            Browser.preset(name: "Vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi", iconName: "vivaldi"),
        ]
    }

    static func sortingRule(_ lhs: Browser, _ rhs: Browser) -> Bool {
        if lhs.isInstalled != rhs.isInstalled {
            return lhs.isInstalled && !rhs.isInstalled
        }
        if lhs.isPreset != rhs.isPreset {
            return lhs.isPreset && !rhs.isPreset
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func preset(
        name: String,
        bundleIdentifier: String,
        iconName: String,
        assumesInstalled: Bool = false
    ) -> Browser {
        Browser(
            id: bundleIdentifier,
            name: name,
            bundleIdentifier: bundleIdentifier,
            iconName: iconName,
            kind: .preset,
            isInstalled: assumesInstalled ? true : Browser.isAppInstalled(bundleId: bundleIdentifier),
            isEnabled: true,
            isHidden: false
        )
    }
}
