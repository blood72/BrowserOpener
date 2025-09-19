import Foundation
import SwiftUI

struct EditableProfile: Identifiable {
    var id: String
    var name: String
    var argumentText: String
    var isEnabled: Bool
    var kind: BrowserProfile.Kind

    init(id: String = UUID().uuidString, name: String, argumentText: String, isEnabled: Bool = true, kind: BrowserProfile.Kind) {
        self.id = id
        self.name = name
        self.argumentText = argumentText
        self.isEnabled = isEnabled
        self.kind = kind
    }

    init(profile: BrowserProfile) {
        self.id = profile.id
        self.name = profile.name
        self.argumentText = EditableProfile.argumentString(from: profile.launchArguments)
        self.isEnabled = profile.isEnabled
        self.kind = profile.kind
    }

    func toBrowserProfile(isDefault: Bool) -> BrowserProfile {
        BrowserProfile(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "프로필" : name,
            launchArguments: EditableProfile.arguments(from: argumentText),
            isDefault: isDefault,
            isEnabled: isEnabled,
            kind: kind
        )
    }

    static func arguments(from text: String) -> [String] {
        var components: [String] = []
        var current = ""
        var insideQuotes = false

        for char in text {
            if char == "\"" {
                insideQuotes.toggle()
                continue
            }

            if char.isWhitespace && !insideQuotes {
                if !current.isEmpty {
                    components.append(current)
                    current.removeAll()
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            components.append(current)
        }

        return components
    }

    static func argumentString(from arguments: [String]) -> String {
        arguments.map { arg in
            if arg.contains(where: { $0.isWhitespace }) {
                return "\"\(arg)\""
            }
            return arg
        }.joined(separator: " ")
    }
}
