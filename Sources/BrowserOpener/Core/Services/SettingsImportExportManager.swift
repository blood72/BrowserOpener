import Foundation

struct ExportedSettings: Codable {
    let version: Int
    let browsers: [Browser]
    let rules: [URLRule]
    let preferences: [String: BrowserPreference]
}

class SettingsImportExportManager {
    static let shared = SettingsImportExportManager()

    func exportSettings(defaults: UserDefaults) throws -> Data {
        var exportData: [String: Any] = [:]

        // 브라우저 설정
        if let preferencesData = defaults.data(forKey: "BrowserPreferences"),
           let jsonArray = try? JSONSerialization.jsonObject(with: preferencesData) {
            exportData["browserPreferences"] = jsonArray
        }

        // 규칙
        if let rulesData = defaults.data(forKey: "URLRules") {
            let rules: [URLRule]
            // RulesSchema or [URLRule] decoding logic
            if let schema = try? JSONDecoder().decode(RulesSchema.self, from: rulesData) {
                rules = schema.data
            } else if let legacyRules = try? JSONDecoder().decode([URLRule].self, from: rulesData) {
                rules = legacyRules
            } else {
                rules = []
            }

            if !rules.isEmpty {
                let rulesEncoder = JSONEncoder()
                rulesEncoder.outputFormatting = [.sortedKeys]
                if let jsonArray = try? JSONSerialization.jsonObject(with: rulesEncoder.encode(rules)) {
                    exportData["rules"] = jsonArray
                }
            }
        }

        // 일반 설정
        exportData["version"] = "1"
        exportData["useRulesForAutomaticOpening"] = defaults.bool(forKey: "useRulesForAutomaticOpening")
        exportData["browserList.showAll"] = defaults.bool(forKey: "browserList.showAll")
        exportData["browserList.showHidden"] = defaults.bool(forKey: "browserList.showHidden")

        return try JSONSerialization.data(withJSONObject: exportData, options: [.sortedKeys, .prettyPrinted])
    }

    func importSettings(from data: Data, to defaults: UserDefaults) throws {
        guard let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "BrowserOpener", code: 1, userInfo: [NSLocalizedDescriptionKey: "잘못된 파일 형식입니다."])
        }

        // 브라우저 설정
        if let customBrowsers = importData["customBrowsers"] as? [[String: Any]],
           let jsonData = try? JSONSerialization.data(withJSONObject: customBrowsers),
           let _ = try? JSONDecoder().decode([Browser].self, from: jsonData) {
            defaults.set(jsonData, forKey: "CustomBrowsers")
        }

        if let preferences = importData["browserPreferences"],
           let jsonData = try? JSONSerialization.data(withJSONObject: preferences) {
            defaults.set(jsonData, forKey: "BrowserPreferences")
        }

        // 규칙
        if let rulesArray = importData["rules"] as? [[String: Any]],
           let _ = try? JSONSerialization.data(withJSONObject: rulesArray) {
             let schema = ["ruleVersion": "1", "data": rulesArray] as [String : Any]
             if let schemaData = try? JSONSerialization.data(withJSONObject: schema) {
                 defaults.set(schemaData, forKey: "URLRules")
             }
        } else if let urlRules = importData["urlRules"] as? [String: Any] {
             if let schemaData = try? JSONSerialization.data(withJSONObject: urlRules) {
                 defaults.set(schemaData, forKey: "URLRules")
             }
        }

        // 일반 설정
        if let useRules = importData["useRulesForAutomaticOpening"] as? Bool {
            defaults.set(useRules, forKey: "useRulesForAutomaticOpening")
        }
        if let showAll = importData["browserList.showAll"] as? Bool {
            defaults.set(showAll, forKey: "browserList.showAll")
        }
        if let showHidden = importData["browserList.showHidden"] as? Bool {
            defaults.set(showHidden, forKey: "browserList.showHidden")
        }
    }
}
