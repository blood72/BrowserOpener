import Foundation

/// 규칙 목록을 영속화하는 간단한 저장소.
/// - 구현 목표:
///   - `[URLRule]`를 `Codable`로 직렬화해 `UserDefaults`에 저장/로드
///   - 깨진 데이터가 있을 경우 조용히 초기화 (빈 배열)
final class RulesStore: ObservableObject {
    @Published var rules: [URLRule] = [] {
        didSet {
            save()
        }
    }

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "URLRules") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        load()
    }

    /// 저장된 규칙을 로드합니다. 실패 시 빈 배열로 초기화합니다.
    func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            rules = []
            return
        }

        do {
            // 1. V1 스키마 시도
            let schema = try JSONDecoder().decode(RulesSchema.self, from: data)
            rules = schema.data
        } catch {
            // 2. 레거시 포맷 (단순 배열) 시도
            if let legacyRules = try? JSONDecoder().decode([URLRule].self, from: data) {
                rules = legacyRules
                // 즉시 마이그레이션 저장
                save()
            } else {
                // 깨진 데이터는 조용히 무시하고 초기화
                rules = []
            }
        }
    }

    /// 현재 규칙 배열을 저장합니다.
    private func save() {
        do {
            let schema = RulesSchema(data: rules)
            let data = try JSONEncoder().encode(schema)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // v1에서는 실패를 조용히 무시 (추후 로깅 여지)
        }
    }
}

struct RulesSchema: Codable {
    let ruleVersion: String
    var data: [URLRule]

    static let currentVersion = "1"

    init(data: [URLRule]) {
        self.ruleVersion = Self.currentVersion
        self.data = data
    }
}


