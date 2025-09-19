import Foundation

struct RuleEngine {
    /// 규칙 목록과 설치된 브라우저 목록을 기반으로, 주어진 URL을 열 브라우저와 프로필을 선택합니다.
    /// - Parameters:
    ///   - url: 열려는 URL
    ///   - rules: 규칙 목록
    ///   - installedBrowsers: 설치된 브라우저 목록
    ///   - sourceAppBundleID: URL을 보낸 앱의 bundle identifier (nil이면 출처 제한 없음)
    /// - Returns: 규칙과 설치 상태를 모두 만족하는 첫 번째 브라우저와 선택된 프로필, 없으면 `nil`.
    static func pickBrowser(
        for url: URL,
        rules: [URLRule],
        installedBrowsers: [Browser],
        sourceAppBundleID: String? = nil
    ) -> (Browser, BrowserProfile?)? {
        let activeRules = rules.filter { $0.isEnabled }

        for rule in activeRules {
            // 출처 앱 매칭: 규칙에 출처 앱이 지정된 경우, 송신자와 일치해야 함
            if let ruleSourceApp = rule.sourceAppBundleIdentifier {
                guard ruleSourceApp == sourceAppBundleID else { continue }
            }

            guard urlMatchesRule(url, rule: rule) else { continue }

            guard let browser = resolveBrowser(for: rule, within: installedBrowsers) else {
                continue
            }

            if let profileID = rule.browserProfileIdentifier {
                guard let profile = browser.profiles.first(where: { $0.id == profileID }) else {
                    continue
                }

                // Req 1: 프로필이 비활성화된 경우 규칙 무시
                guard profile.isEnabled else { continue }

                return (browser, profile)
            }

            // 특정 프로필이 지정되지 않은 경우, 기본 프로필 사용
            if let profile = browser.defaultProfile {
                // defaultProfile은 이미 enabled 상태인 것만 반환함
                return (browser, profile)
            }

            // 기본 프로필조차 사용할 수 없으면(모두 비활성화 등) 이 브라우저는 건너뜀
            continue
        }

        return nil
    }

    private static func resolveBrowser(for rule: URLRule, within browsers: [Browser]) -> Browser? {
        if let identifier = rule.browserIdentifier {
            if let browser = browsers.first(where: { $0.id == identifier }) {
                return browser
            }
            // Fallback: Bundle Identifier로 검색 (재설치 등으로 ID가 변경된 경우 대응)
            if let browser = browsers.first(where: { $0.bundleIdentifier == identifier }) {
                return browser
            }
        }

        return browsers.first(where: { $0.name == rule.browserName && $0.isInstalled })
    }

    // MARK: - 내부 매칭 로직

    private static func urlMatchesRule(_ url: URL, rule: URLRule) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let loweredPattern = rule.pattern.lowercased()
        let (hostPortPattern, pathPattern) = splitHostAndPath(from: loweredPattern)
        let parsedHostPort = parseHostPortPattern(hostPortPattern)

        guard hostMatches(host: host, pattern: parsedHostPort.hostPattern) else { return false }
        guard portMatches(url: url, match: parsedHostPort.portMatch) else { return false }

        if let pathPattern = pathPattern {
            return pathMatches(path: url.path.lowercased(), pattern: pathPattern)
        }

        return true
    }

    private static func splitHostAndPath(from pattern: String) -> (hostPort: String, path: String?) {
        if let slashIndex = pattern.firstIndex(of: "/") {
            let hostPort = String(pattern[..<slashIndex])
            let path = String(pattern[slashIndex...])
            return (hostPort, path)
        }
        return (pattern, nil)
    }

    private enum PortMatch {
        case any
        case specific(Int)
        case defaultWeb
    }

    private static func parseHostPortPattern(_ pattern: String) -> (hostPattern: String, portMatch: PortMatch) {
        if pattern.hasSuffix(":*") {
            let hostPattern = String(pattern.dropLast(2))
            return (hostPattern, .any)
        }

        if let colonIndex = pattern.lastIndex(of: ":") {
            let hostPart = String(pattern[..<colonIndex])
            let portPart = String(pattern[pattern.index(after: colonIndex)...])
            if let port = Int(portPart) {
                return (hostPart, .specific(port))
            }
        }

        return (pattern, .defaultWeb)
    }

    private static func portMatches(url: URL, match: PortMatch) -> Bool {
        let effectivePort = url.port ?? defaultPort(forScheme: url.scheme)

        switch match {
        case .any:
            return true
        case .specific(let port):
            guard let effectivePort = effectivePort else { return false }
            return effectivePort == port
        case .defaultWeb:
            guard let effectivePort = effectivePort else { return false }
            return effectivePort == 80 || effectivePort == 443
        }
    }

    private static func defaultPort(forScheme scheme: String?) -> Int? {
        switch scheme?.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }

    private static func hostMatches(host: String, pattern: String) -> Bool {
        // 전체 와일드카드 (현재 스펙에서는 사용하지 않지만 방어적으로 처리)
        if pattern == "*" {
            return true
        }

        // 서브도메인 와일드카드: *.google.com, *.dev 등
        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(2))
            guard !suffix.isEmpty else { return false }

            // bare 도메인(google.com, dev)과 모든 서브도메인(sub.google.com / a.b.dev 등)을 모두 매칭
            return host == suffix || host.hasSuffix("." + suffix)
        }

        // 단순 호스트 일치 (github.com 등)
        return host == pattern
    }

    private static func pathMatches(path: String, pattern: String) -> Bool {
        // 기본적으로 패턴은 "/"로 시작한다고 가정 (예: "/*")
        if pattern == "/*" {
            return true
        }

        // "/foo/*" 처럼 특정 경로 이하 전체를 의미하는 패턴
        if pattern.hasSuffix("/*") {
            let rawPrefix = String(pattern.dropLast(2)) // "/*" 제거
            // "/v1/" 형태로 끝나는 패턴을 "/v1"로 정규화해 "/v1" 자체도 매칭되도록 처리
            let normalizedPrefix = rawPrefix.hasSuffix("/")
                ? String(rawPrefix.dropLast())
                : rawPrefix

            if normalizedPrefix.isEmpty || normalizedPrefix == "/" {
                return true
            }

            return path == normalizedPrefix || path.hasPrefix(normalizedPrefix + "/")
        }

        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast()) // '*' 제거
            return path == prefix || path.hasPrefix(prefix)
        }

        return path == pattern
    }
}
