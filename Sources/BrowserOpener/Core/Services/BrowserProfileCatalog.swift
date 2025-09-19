import Foundation

protocol ProfileFileReader {
    func data(contentsOf url: URL) throws -> Data
    func string(contentsOf url: URL, encoding: String.Encoding) throws -> String
    var homeDirectoryForCurrentUser: URL { get }
}

struct DefaultProfileFileReader: ProfileFileReader {
    func data(contentsOf url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func string(contentsOf url: URL, encoding: String.Encoding) throws -> String {
        try String(contentsOf: url, encoding: encoding)
    }

    var homeDirectoryForCurrentUser: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
}

enum BrowserProfileCatalog {
    static func profiles(
        forBundleIdentifier bundleIdentifier: String,
        displayName: String,
        fileReader: ProfileFileReader = DefaultProfileFileReader()
    ) -> [BrowserProfile] {
        switch bundleIdentifier {
        case "com.apple.Safari":
            return safariProfiles(bundleIdentifier: bundleIdentifier)
        case "com.google.Chrome":
            return chromiumProfiles(
                bundleIdentifier: bundleIdentifier,
                appSupportSubPath: "Google/Chrome",
                privateDisplayName: "시크릿 창",
                incognitoArgument: "--incognito",
                fileReader: fileReader
            )
        case "org.mozilla.firefox":
            return firefoxProfiles(
                bundleIdentifier: bundleIdentifier,
                fileReader: fileReader
            )
        case "com.vivaldi.Vivaldi":
            return chromiumProfiles(
                bundleIdentifier: bundleIdentifier,
                appSupportSubPath: "Vivaldi",
                privateDisplayName: "시크릿 창",
                incognitoArgument: "--incognito",
                fileReader: fileReader
            )
        default:
            return [BrowserProfile.defaultProfile(forBundleIdentifier: bundleIdentifier)]
        }
    }
}

// MARK: - Safari
// Safari는 명령줄 인자를 지원하지 않아 기본 프로필만 제공

private func safariProfiles(bundleIdentifier: String) -> [BrowserProfile] {
    [BrowserProfile.defaultProfile(forBundleIdentifier: bundleIdentifier)]
}

// MARK: - Chromium family

private func chromiumProfiles(
    bundleIdentifier: String,
    appSupportSubPath: String,
    privateDisplayName: String,
    incognitoArgument: String,
    fileReader: ProfileFileReader
) -> [BrowserProfile] {
    var profiles = detectChromiumProfiles(
        bundleIdentifier: bundleIdentifier,
        appSupportSubPath: appSupportSubPath,
        fileReader: fileReader
    )

    if profiles.isEmpty {
        profiles = [BrowserProfile.defaultProfile(forBundleIdentifier: bundleIdentifier)]
    }

    let privateProfile = BrowserProfile(
        id: "\(bundleIdentifier)#incognito",
        name: privateDisplayName,
        launchArguments: [incognitoArgument],
        isDefault: false,
        kind: .privateMode
    )

    if !profiles.contains(where: { $0.id == privateProfile.id }) {
        profiles.insert(privateProfile, at: min(1, profiles.count))
    }

    return profiles
}

private func detectChromiumProfiles(
    bundleIdentifier: String,
    appSupportSubPath: String,
    fileReader: ProfileFileReader
) -> [BrowserProfile] {
    let baseURL = fileReader.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent(appSupportSubPath)

    let localStateURL = baseURL.appendingPathComponent("Local State")
    guard let data = try? fileReader.data(contentsOf: localStateURL) else {
        return []
    }

    let decoder = JSONDecoder()
    guard let localState = try? decoder.decode(ChromiumLocalState.self, from: data),
          let cache = localState.profile?.infoCache, !cache.isEmpty else {
        return []
    }

    let profiles: [BrowserProfile] = cache.map { key, profile in
        let isDefault = key.caseInsensitiveCompare("default") == .orderedSame
        let arguments = isDefault ? [] : ["--profile-directory=\(key)"]
        let identifier = "\(bundleIdentifier)#\(key)"
        return BrowserProfile(
            id: identifier,
            name: profile.name ?? key,
            launchArguments: arguments,
            isDefault: isDefault,
            kind: .detected
        )
    }

    return profiles.sorted { lhs, rhs in
        if lhs.isDefault != rhs.isDefault {
            return lhs.isDefault
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private struct ChromiumLocalState: Decodable {
    struct ProfileContainer: Decodable {
        struct ProfileInfo: Decodable {
            let name: String?

            enum CodingKeys: String, CodingKey {
                case name
            }
        }

        let infoCache: [String: ProfileInfo]

        enum CodingKeys: String, CodingKey {
            case infoCache = "info_cache"
        }
    }

    let profile: ProfileContainer?
}

// MARK: - Firefox

private func firefoxProfiles(
    bundleIdentifier: String,
    fileReader: ProfileFileReader
) -> [BrowserProfile] {
    let profilesFileURL = fileReader.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Application Support")
        .appendingPathComponent("Firefox")
        .appendingPathComponent("profiles.ini")

    guard let contents = try? fileReader.string(contentsOf: profilesFileURL, encoding: .utf8) else {
        return defaultFirefoxProfiles(bundleIdentifier: bundleIdentifier)
    }

    var parsedProfiles: [BrowserProfile] = []
    var currentSection: [String: String] = [:]

    func finalizeSection() {
        guard let name = currentSection["Name"], !name.isEmpty else { return }
        let isDefault = currentSection["Default"] == "1"
        let identifier = "\(bundleIdentifier)#\(name)"
        let profile = BrowserProfile(
            id: identifier,
            name: name,
            launchArguments: ["-P", name],
            isDefault: isDefault,
            kind: .detected
        )
        parsedProfiles.append(profile)
        currentSection.removeAll()
    }

    for rawLine in contents.components(separatedBy: .newlines) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") {
            continue
        }

        if line.hasPrefix("[Profile") {
            finalizeSection()
            currentSection = [:]
            continue
        }

        guard let separatorIndex = line.firstIndex(of: "=") else { continue }
        let key = String(line[..<separatorIndex])
        let valueIndex = line.index(after: separatorIndex)
        let value = String(line[valueIndex...])
        currentSection[key] = value
    }

    finalizeSection()

    var profiles = parsedProfiles
    if profiles.isEmpty {
        profiles = defaultFirefoxProfiles(bundleIdentifier: bundleIdentifier)
    }

    let privateProfile = BrowserProfile(
        id: "\(bundleIdentifier)#private",
        name: "프라이빗 창",
        launchArguments: ["-private-window"],
        isDefault: false,
        kind: .privateMode
    )

    if !profiles.contains(where: { $0.id == privateProfile.id }) {
        profiles.insert(privateProfile, at: min(1, profiles.count))
    }

    return profiles
}

private func defaultFirefoxProfiles(bundleIdentifier: String) -> [BrowserProfile] {
    [
        BrowserProfile(
            id: "\(bundleIdentifier)#default",
            name: "기본 프로필",
            launchArguments: [],
            isDefault: true,
            kind: .standard
        )
    ]
}







