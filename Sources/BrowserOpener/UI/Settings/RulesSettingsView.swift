import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 출처 앱 정보
struct SourceApp: Identifiable, Equatable {
    let id: String  // bundle identifier
    let name: String
}

/// URL 테스트 결과
struct TestURLResult {
    let rule: URLRule
    let ruleIndex: Int  // 1-based 순번
    let browserName: String
    let profileName: String?
}

struct RulesSettingsView: View {
    @EnvironmentObject var rulesStore: RulesStore
    @EnvironmentObject var browserStore: BrowserStore
    @State private var showingAddRule = false
    @State private var editingRule: URLRule?
    @State private var draggedRule: URLRule?
    @State private var pendingDeletionRule: URLRule?
    @State private var testURLString = ""
    @State private var testSourceAppBundleID = ""
    @State private var scrollToRuleID: UUID?
    @State private var showingBulkEdit = false
    @AppStorage("rulesTest.isExpanded") private var isTestSectionExpanded = true

    private var activeBrowsers: [Browser] {
        browserStore.browsers
            .filter { $0.isInstalled && $0.isEnabled && !$0.isHidden }
            .sorted { $0.name < $1.name }
    }

    private func browserAvailability(for rule: URLRule) -> RuleBrowserAvailability {
        guard let browser = browserForRule(rule) else {
            return .browserMissing
        }

        guard browser.isInstalled else {
            return .browserMissing
        }

        guard browser.isEnabled && !browser.isHidden else {
            return .browserDisabled
        }

        if let profileID = rule.browserProfileIdentifier {
            guard let profile = browser.profiles.first(where: { $0.id == profileID }) else {
                return .profileMissing
            }

            if !profile.isEnabled {
                return .profileDisabled
            }
        }

        return .available
    }

    private func browserForRule(_ rule: URLRule) -> Browser? {
        if let identifier = rule.browserIdentifier {
            return browserStore.browsers.first(where: { $0.id == identifier })
        }
        return browserStore.browsers.first(where: { $0.name == rule.browserName })
    }

    private func profileForRule(_ rule: URLRule) -> BrowserProfile? {
        guard let browser = browserForRule(rule),
              let profileID = rule.browserProfileIdentifier else {
            return nil
        }
        return browser.profiles.first(where: { $0.id == profileID })
    }

    private func destinationLabel(for rule: URLRule) -> String {
        let browserName = browserForRule(rule)?.name ?? rule.preferredBrowserName
        var profileName = profileForRule(rule)?.name ?? rule.browserProfileIdentifier

        // Req 3: '#' 이후 부분만 추출 (예: org.Chromium.Chromium#default -> default)
        if let name = profileName, let range = name.range(of: "#") {
            profileName = String(name[range.upperBound...])
        }

        if let profileName, !profileName.isEmpty {
            return "→ \(browserName) · \(profileName)"
        }
        return "→ \(browserName)"
    }

    private func sourceAppLabel(for rule: URLRule) -> String? {
        guard let sourceApp = rule.preferredSourceAppName else { return nil }
        return "출처: \(sourceApp)"
    }

    private var testURLResult: TestURLResult? {
        guard !testURLString.isEmpty else { return nil }

        // URL 형식 보정 (스킴이 없으면 https 추가)
        var urlString = testURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.contains("://") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString) else { return nil }

        let trimmedSourceApp = testSourceAppBundleID.trimmingCharacters(in: .whitespacesAndNewlines)

        // 매칭된 규칙과 인덱스 찾기
        for (index, rule) in rulesStore.rules.enumerated() {
            guard rule.isEnabled else { continue }
            guard urlMatchesRulePattern(url, rule: rule) else { continue }

            // 출처 앱 매칭 확인
            if let ruleSourceApp = rule.sourceAppBundleIdentifier, !ruleSourceApp.isEmpty {
                // 규칙에 출처 앱이 지정된 경우, 테스트 출처 앱과 일치해야 함
                guard !trimmedSourceApp.isEmpty && ruleSourceApp.lowercased() == trimmedSourceApp.lowercased() else {
                    continue
                }
            }

            guard let browser = browserForRule(rule),
                  browser.isInstalled && browser.isEnabled && !browser.isHidden else {
                continue
            }

            let profile: BrowserProfile?
            if let profileID = rule.browserProfileIdentifier {
                profile = browser.profiles.first(where: { $0.id == profileID })
                // Req: 테스트 시에도 프로필이 비활성화되었다면 매칭되지 않아야 함
                if let p = profile, !p.isEnabled {
                    continue
                }
            } else {
                profile = browser.defaultProfile
            }

            return TestURLResult(
                rule: rule,
                ruleIndex: index + 1,
                browserName: browser.name,
                profileName: profile?.name
            )
        }

        return nil
    }

    /// URL이 규칙 패턴과 매칭되는지 확인 (테스트용)
    private func urlMatchesRulePattern(_ url: URL, rule: URLRule) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let loweredPattern = rule.pattern.lowercased()

        // 포트 패턴 분리
        let (hostPortPattern, pathPattern) = splitHostAndPath(from: loweredPattern)

        // 호스트 매칭
        if !hostMatches(host: host, pattern: hostPortPattern) {
            return false
        }

        // 경로 매칭
        if let pathPattern = pathPattern {
            return pathMatches(path: url.path.lowercased(), pattern: pathPattern)
        }

        return true
    }

    private func splitHostAndPath(from pattern: String) -> (hostPort: String, path: String?) {
        // 포트 와일드카드 처리
        var hostPart = pattern
        if hostPart.hasSuffix(":*") {
            hostPart = String(hostPart.dropLast(2))
        } else if let colonIndex = hostPart.lastIndex(of: ":") {
            hostPart = String(hostPart[..<colonIndex])
        }

        if let slashIndex = hostPart.firstIndex(of: "/") {
            let host = String(hostPart[..<slashIndex])
            let path = String(hostPart[slashIndex...])
            return (host, path)
        }
        return (hostPart, nil)
    }

    private func hostMatches(host: String, pattern: String) -> Bool {
        if pattern == "*" { return true }

        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(2))
            guard !suffix.isEmpty else { return false }
            return host == suffix || host.hasSuffix("." + suffix)
        }

        return host == pattern
    }

    private func pathMatches(path: String, pattern: String) -> Bool {
        if pattern == "/*" { return true }
        if pattern.hasSuffix("/*") {
            let prefix = String(pattern.dropLast(2))
            return path == prefix || path.hasPrefix(prefix + "/")
        }
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return path.hasPrefix(prefix)
        }
        return path == pattern
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            VStack(alignment: .leading, spacing: 4) {
                Text("규칙")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("특정 URL 패턴에 대해 기본 브라우저를 설정합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // 설정 내용
            VStack(alignment: .leading, spacing: 16) {
                // 규칙 관리 버튼들
                HStack {
                    Text("규칙 목록")
                        .font(.headline)

                    Spacer()

                    Button(action: {
                        showingAddRule = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("규칙 추가")
                        }
                        .font(.system(size: 13))
                    }
                    .disabled(activeBrowsers.isEmpty)

                    Button(action: {
                        showingBulkEdit = true
                    }) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 13))
                    }
                    .help("규칙을 JSON으로 일괄 편집")
                }
                if activeBrowsers.isEmpty {
                    Text("사용 가능한 브라우저가 없어 새로운 규칙을 추가할 수 없습니다.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // 규칙 목록
                ScrollViewReader { proxy in
                    ScrollView {
                        if rulesStore.rules.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.title2)
                                    .foregroundColor(.secondary)

                                Text("설정된 규칙이 없습니다")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                Text("특정 URL 패턴에 대해 기본 브라우저를 지정할 수 있습니다")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(rulesStore.rules.enumerated()), id: \.element.id) { index, rule in
                                    let availability = browserAvailability(for: rule)
                                    let destination = destinationLabel(for: rule)
                                    let sourceApp = sourceAppLabel(for: rule)

                                    URLRuleRowView(
                                        rule: rule,
                                        priority: index + 1,
                                        isDragging: draggedRule?.id == rule.id,
                                        availability: availability,
                                        destinationLabel: destination,
                                        sourceAppLabel: sourceApp,
                                        onToggle: { isEnabled in
                                            rulesStore.rules[index].isEnabled = isEnabled
                                        },
                                        onDuplicate: {
                                            duplicateRule(rule)
                                        },
                                        onEdit: {
                                            editingRule = rule
                                        },
                                        onDelete: {
                                            pendingDeletionRule = rule
                                        }
                                    )
                                    .id(rule.id)
                                    .onDrag {
                                        draggedRule = rule
                                        return NSItemProvider(object: "\(rule.id)" as NSString)
                                    } preview : {
                                        // Disable preview with onDrag
                                        //@see https://www.reddit.com/r/SwiftUI/comments/139xov9/disable_preview_with_ondrag/
                                        Color.gray.opacity(0.01)
                                    }
                                    .onDrop(of: [.text], delegate: DropViewDelegate(
                                        destinationItem: rule,
                                        rules: $rulesStore.rules,
                                        draggedItem: $draggedRule
                                    ))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(maxHeight: isTestSectionExpanded ? 320 : 480)
                    .onChange(of: scrollToRuleID) { targetID in
                        guard let targetID else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                        // 스크롤 후 초기화
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            scrollToRuleID = nil
                        }
                    }
                }

                Divider()

                // 규칙 테스트 & 패턴 예시 (접기/펼치기)
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isTestSectionExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isTestSectionExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 12)
                            Text("규칙 테스트")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isTestSectionExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            // 규칙 테스트
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    TextField("URL (예: github.com)", text: $testURLString)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12, design: .monospaced))

                                    HStack {
                                        TextField("출처 앱 (선택)", text: $testSourceAppBundleID)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, design: .monospaced))
                                            .frame(width: 180)
                                            .help("출처 앱의 Bundle ID (예: com.apple.mail)")
                                        Button("찾기...") {
                                            selectSourceAppFromFinder()
                                        }
                                        .font(.system(size: 11))
                                    }
                                }

                                if !testURLString.isEmpty {
                                    if let result = testURLResult {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 12))
                                            Button {
                                                scrollToRuleID = result.rule.id
                                            } label: {
                                                Text("#\(result.ruleIndex)")
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundColor(.blue)
                                                    .underline()
                                            }
                                            .buttonStyle(.plain)
                                            .help("클릭하여 해당 규칙으로 이동")

                                            Text("→ \(result.browserName)")
                                                .font(.system(size: 12, weight: .medium))
                                            if let profileName = result.profileName {
                                                Text("(\(profileName))")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12))
                                            Text("매칭되는 규칙이 없습니다")
                                                .font(.system(size: 12))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(4)
                                    }
                                }
                            }

                            Divider()

                            // 패턴 예시
                            VStack(alignment: .leading, spacing: 4) {
                                Text("패턴 예시")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    RuleExampleView(pattern: "github.com", description: "특정 도메인만 (80, 443 포트)")
                                    RuleExampleView(pattern: "localhost:*", description: "로컬 개발 서버 (모든 포트)")
                                    RuleExampleView(pattern: "*.dev", description: ".dev 도메인 모든 사이트")
                                    RuleExampleView(pattern: "*:*", description: "모든 도메인과 포트")
                                }
                            }
                        }
                        .padding(.leading, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .focusable(false)
        .sheet(isPresented: $showingAddRule) {
            AddRuleView(browsers: activeBrowsers) { newRule in
                withAnimation(.easeInOut(duration: 0.25)) {
                    rulesStore.rules.append(newRule)
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            EditRuleView(rule: rule, browsers: activeBrowsers) { updatedRule in
                if let index = rulesStore.rules.firstIndex(where: { $0.id == updatedRule.id }) {
                    rulesStore.rules[index] = updatedRule
                }
                editingRule = nil
            }
        }
        .alert(item: $pendingDeletionRule) { rule in
            Alert(
                title: Text("규칙 삭제"),
                message: Text("정말로 \"\(rule.pattern)\" 규칙을 삭제할까요?"),
                primaryButton: .destructive(Text("삭제")) {
                    deleteRule(rule)
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingBulkEdit) {
            BulkEditView(rules: rulesStore.rules) { updatedRules in
                rulesStore.rules = updatedRules
            }
        }
    }

    private func duplicateRule(_ rule: URLRule) {
        guard let index = rulesStore.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        let duplicatedRule = URLRule(
            pattern: rule.pattern,
            browserName: rule.browserName,
            isEnabled: rule.isEnabled,
            browserIdentifier: rule.browserIdentifier,
            browserProfileIdentifier: rule.browserProfileIdentifier,
            sourceAppBundleIdentifier: rule.sourceAppBundleIdentifier,
            sourceAppDisplayName: rule.sourceAppDisplayName
        )
        withAnimation(.easeInOut(duration: 0.25)) {
            rulesStore.rules.insert(duplicatedRule, at: min(index + 1, rulesStore.rules.count))
        }
    }

    private func deleteRule(_ rule: URLRule) {
        guard let index = rulesStore.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = rulesStore.rules.remove(at: index)
        }
    }

    private func selectSourceAppFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "규칙 테스트에 사용할 출처 앱을 선택하세요"
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            if let bundleID = bundle?.bundleIdentifier {
                testSourceAppBundleID = bundleID
            }
        }
    }
}

struct URLRuleRowView: View {
    let rule: URLRule
    let priority: Int
    let isDragging: Bool
    let availability: RuleBrowserAvailability
    let destinationLabel: String
    let sourceAppLabel: String?
    let onToggle: (Bool) -> Void
    let onDuplicate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    /// 영역 비활성화 여부: 어떤 문제든 있으면 비활성화 표시 (토글은 항상 유지하여 사용자가 수정 가능)
    private var isAreaDisabled: Bool {
        availability != .available
    }

    var body: some View {
        HStack(spacing: 12) {
            // 우선순위 숫자
            Text("\(priority)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(rule.isEnabled && !isAreaDisabled ? Color.blue : Color.secondary)
                )

            // 활성화 토글 (availability 문제가 있어도 토글 유지 - 사용자가 수정 기회 가짐)
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: onToggle
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.pattern)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text(destinationLabel)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let sourceAppLabel {
                        Text(sourceAppLabel)
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                }

                if let warning = availability.warningText {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // 복제 버튼
            Button(action: onDuplicate) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("규칙 복제")

            // 수정 버튼
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("규칙 수정")

            // 삭제 버튼
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("규칙 삭제")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .opacity(rowOpacity)
        .onHover { hovering in
            isHovering = hovering
            updateCursor()
        }
        .onChange(of: isDragging) { _ in
            updateCursor()
        }
    }

    /// 행 전체의 투명도: 문제가 있거나 비활성화된 규칙은 흐리게 표시
    private var rowOpacity: Double {
        if isAreaDisabled {
            return 0.5
        }
        return rule.isEnabled ? 1.0 : 0.7
    }

    private func updateCursor() {
        guard isHovering else {
            NSCursor.arrow.set()
            return
        }
        if isDragging {
            NSCursor.closedHand.set()
        } else {
            NSCursor.openHand.set()
        }
    }
}

// 드래그&드롭 델리게이트
struct DropViewDelegate: DropDelegate {
    let destinationItem: URLRule
    @Binding var rules: [URLRule]
    @Binding var draggedItem: URLRule?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // 드롭 시점에는 상태만 정리하고, 실제 순서 변경은 드래그 중(dropEntered) 애니메이션으로 처리
        draggedItem = nil
        return true
    }

    func dropEnded(info: DropInfo) {
        // 드래그가 취소되거나 종료된 경우에도 항상 상태를 원복
        draggedItem = nil
    }

    func dropEntered(info: DropInfo) {
        // 드래그 중에 행 위를 지날 때마다 실시간으로 순서를 업데이트해서 자연스러운 애니메이션 제공
        guard let draggedItem = draggedItem else { return }

        let fromIndex = rules.firstIndex(of: draggedItem)
        let toIndex = rules.firstIndex(of: destinationItem)

        if let fromIndex = fromIndex, let toIndex = toIndex, fromIndex != toIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                let item = rules[fromIndex]
                rules.remove(at: fromIndex)
                rules.insert(item, at: toIndex)
            }
        }
    }
}

struct RuleExampleView: View {
    let pattern: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Text(pattern)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(0.1))
                )

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct AddRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pattern = ""
    @State private var selectedBrowserID: String?
    @State private var selectedProfileID: String?
    @State private var sourceAppBundleID = ""

    let browsers: [Browser]
    let onAdd: (URLRule) -> Void

    init(
        browsers: [Browser],
        initialPattern: String = "",
        initialSourceAppBundleID: String = "",
        onAdd: @escaping (URLRule) -> Void
    ) {
        self.browsers = browsers
        self.onAdd = onAdd
        self._pattern = State(initialValue: initialPattern)
        self._sourceAppBundleID = State(initialValue: initialSourceAppBundleID)
        self._selectedBrowserID = State(initialValue: browsers.first?.id)
        self._selectedProfileID = State(initialValue: browsers.first?.defaultProfile?.id)
    }

    private var selectedBrowser: Browser? {
        guard let id = selectedBrowserID else { return nil }
        return browsers.first { $0.id == id }
    }

    private var selectedProfile: BrowserProfile? {
        guard let browser = selectedBrowser else { return nil }
        if let profileID = selectedProfileID,
           let profile = browser.profiles.first(where: { $0.id == profileID }) {
            return profile
        }
        return browser.defaultProfile
    }

    private var canSubmit: Bool {
        !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedBrowser != nil
    }

    private var resolvedSourceApp: (bundleID: String?, displayName: String?) {
        let trimmed = sourceAppBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }
        let displayName = resolveAppDisplayName(for: trimmed)
        return (trimmed, displayName)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("새 규칙 추가")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL 패턴")
                        .font(.system(size: 13, weight: .medium))

                    TextField("예: *.example.com", text: $pattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("출처 앱 (선택)")
                        .font(.system(size: 13, weight: .medium))

                    HStack {
                        TextField("Bundle Identifier (예: com.apple.mail)", text: $sourceAppBundleID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        Button("찾기...") {
                            selectSourceAppFromFinder()
                        }
                    }

                    Text("특정 앱에서 열린 링크에만 이 규칙을 적용합니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("브라우저")
                        .font(.system(size: 13, weight: .medium))

                    if browsers.isEmpty {
                        Text("활성화된 브라우저가 없습니다. 브라우저 설정에서 ON 상태로 전환해주세요.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("브라우저 선택", selection: Binding(
                            get: { selectedBrowserID ?? "" },
                            set: { newValue in selectedBrowserID = newValue.isEmpty ? nil : newValue }
                        )) {
                            ForEach(browsers) { browser in
                                Text(browser.name).tag(browser.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if let browser = selectedBrowser {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("프로필")
                            .font(.system(size: 13, weight: .medium))

                        if browser.profiles.isEmpty {
                            Text("사용 가능한 프로필이 없습니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let enabledProfiles = browser.profiles.filter { $0.isEnabled }
                            Picker("프로필 선택", selection: Binding(
                                get: { selectedProfileID ?? browser.defaultProfile?.id ?? "" },
                                set: { newValue in selectedProfileID = newValue.isEmpty ? nil : newValue }
                            )) {
                                ForEach(enabledProfiles) { profile in
                                    Text(profile.name).tag(profile.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }

            HStack {
                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Button("추가") {
                    guard let browser = selectedBrowser else { return }
                    let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
                    let profile = selectedProfile
                let sourceApp = resolvedSourceApp

                // Req 5: 사용자 지정 브라우저의 경우 Bundle Identifier를 우선 사용
                let browserIdentifier = browser.bundleIdentifier

                let newRule = URLRule(
                    pattern: trimmedPattern,
                    browserName: browser.name,
                    browserIdentifier: browserIdentifier,
                    browserProfileIdentifier: profile?.id,
                    sourceAppBundleIdentifier: sourceApp.bundleID,
                    sourceAppDisplayName: sourceApp.displayName
                )
                    onAdd(newRule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onChange(of: selectedBrowserID) { _ in
            syncProfileSelection()
        }
    }

    private func syncProfileSelection() {
        guard let browser = selectedBrowser else {
            selectedProfileID = nil
            return
        }
        let enabledProfiles = browser.profiles.filter { $0.isEnabled }
        selectedProfileID = browser.defaultProfile?.id ?? enabledProfiles.first?.id
    }

    private func selectSourceAppFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "출처로 사용할 앱을 선택하세요"
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            if let bundleID = bundle?.bundleIdentifier {
                sourceAppBundleID = bundleID
            }
        }
    }
}

struct EditRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pattern: String
    @State private var selectedBrowserID: String?
    @State private var selectedProfileID: String?
    @State private var sourceAppBundleID: String
    private let originalRule: URLRule
    private let browsers: [Browser]
    private let missingBrowserName: String?
    private let missingProfileName: String?
    let onSave: (URLRule) -> Void

    init(rule: URLRule, browsers: [Browser], onSave: @escaping (URLRule) -> Void) {
        self._pattern = State(initialValue: rule.pattern)
        self.originalRule = rule
        self.browsers = browsers
        let matchedBrowser: Browser?
        if let identifier = rule.browserIdentifier {
            matchedBrowser = browsers.first { $0.id == identifier }
        } else {
            matchedBrowser = browsers.first { $0.name == rule.browserName }
        }
        self._selectedBrowserID = State(initialValue: matchedBrowser?.id)
        if let browser = matchedBrowser,
           let profileID = rule.browserProfileIdentifier,
           browser.profiles.contains(where: { $0.id == profileID }) {
            // 프로필이 존재하는 경우
            self._selectedProfileID = State(initialValue: profileID)
            self.missingProfileName = nil
        } else if matchedBrowser == nil {
            // 브라우저를 찾을 수 없는 경우
            self._selectedProfileID = State(initialValue: nil)
            self.missingProfileName = rule.browserProfileIdentifier
        } else if rule.browserProfileIdentifier != nil {
            // 브라우저는 있지만 프로필을 찾을 수 없는 경우 -> 빈 상태로 표시
            self._selectedProfileID = State(initialValue: nil)
            self.missingProfileName = rule.browserProfileIdentifier
        } else {
            // 프로필 지정이 없는 경우 -> 기본 프로필 선택
            // self._selectedProfileID = State(initialValue: matchedBrowser?.defaultProfile?.id)
            self._selectedProfileID = State(initialValue: nil)
            self.missingProfileName = nil
        }
        self.missingBrowserName = matchedBrowser == nil ? rule.browserName : nil
        // 출처 앱 초기화
        self._sourceAppBundleID = State(initialValue: rule.sourceAppBundleIdentifier ?? "")
        self.onSave = onSave
    }

    private var selectedBrowser: Browser? {
        guard let id = selectedBrowserID else { return nil }
        return browsers.first { $0.id == id }
    }

    private var selectedProfile: BrowserProfile? {
        guard let browser = selectedBrowser else { return nil }
        if let profileID = selectedProfileID,
           let profile = browser.profiles.first(where: { $0.id == profileID }) {
            return profile
        }
        return browser.defaultProfile
    }

    private var canSubmit: Bool {
        !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedBrowser != nil
    }

    private var shouldShowMissingBrowserWarning: Bool {
        guard missingBrowserName != nil else { return false }
        return selectedBrowser == nil
    }

    private var shouldShowMissingProfileWarning: Bool {
        guard missingProfileName != nil else { return false }
        guard let browser = selectedBrowser else { return true }
        if let identifier = originalRule.browserIdentifier {
            return browser.id == identifier
        }
        return browser.name == originalRule.browserName
    }

    private var resolvedSourceApp: (bundleID: String?, displayName: String?) {
        let trimmed = sourceAppBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil) }
        let displayName = resolveAppDisplayName(for: trimmed)
        return (trimmed, displayName)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("규칙 수정")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL 패턴")
                        .font(.system(size: 13, weight: .medium))

                    TextField("예: *.example.com", text: $pattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("출처 앱 (선택)")
                        .font(.system(size: 13, weight: .medium))

                    HStack {
                        TextField("Bundle Identifier (예: com.apple.mail)", text: $sourceAppBundleID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        Button("찾기...") {
                            selectSourceAppFromFinder()
                        }
                    }

                    Text("특정 앱에서 열린 링크에만 이 규칙을 적용합니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("브라우저")
                        .font(.system(size: 13, weight: .medium))

                    if browsers.isEmpty {
                        Text("사용할 수 있는 브라우저가 없어 규칙을 수정할 수 없습니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("브라우저 선택", selection: Binding(
                            get: { selectedBrowserID ?? "" },
                            set: { newValue in selectedBrowserID = newValue.isEmpty ? nil : newValue }
                        )) {
                            ForEach(browsers) { browser in
                                Text(browser.name).tag(browser.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if shouldShowMissingBrowserWarning, let missingBrowserName {
                        Text("선택된 브라우저(\(missingBrowserName))를 사용할 수 없어 규칙이 비활성화되었습니다.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if let browser = selectedBrowser {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("프로필")
                            .font(.system(size: 13, weight: .medium))

                        if browser.profiles.isEmpty {
                            Text("사용 가능한 프로필이 없습니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let enabledProfiles = browser.profiles.filter { $0.isEnabled }
                            Picker("프로필 선택", selection: Binding(
                                get: { selectedProfileID ?? "" },
                                set: { newValue in selectedProfileID = newValue.isEmpty ? nil : newValue }
                            )) {
                                ForEach(enabledProfiles) { profile in
                                    Text(profile.name).tag(profile.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if shouldShowMissingProfileWarning, let missingProfileName {
                            Text("선택된 프로필(\(missingProfileName))을 찾을 수 없습니다. 새 프로필을 선택하세요.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            HStack {
                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                Button("저장") {
                    guard let browser = selectedBrowser else { return }
                    let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
                    let profile = selectedProfile
                    let sourceApp = resolvedSourceApp

                    // Req 5: 사용자 지정 브라우저의 경우 Bundle Identifier를 우선 사용 (재설치 시 규칙 유지)
                    // Browser.id가 UUID인 경우(custom)에도 bundleIdentifier는 존재함
                    // Preset 브라우저는 id == bundleIdentifier
                    let browserIdentifier = browser.bundleIdentifier

                    let updatedRule = URLRule(
                        id: originalRule.id,
                        pattern: trimmedPattern,
                        browserName: browser.name,
                        isEnabled: originalRule.isEnabled,
                        browserIdentifier: browserIdentifier,
                        browserProfileIdentifier: profile?.id,
                        sourceAppBundleIdentifier: sourceApp.bundleID,
                        sourceAppDisplayName: sourceApp.displayName
                    )
                    onSave(updatedRule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onChange(of: selectedBrowserID) { _ in
            syncProfileSelection()
        }
    }

    private func syncProfileSelection() {
        guard let browser = selectedBrowser else {
            selectedProfileID = nil
            return
        }
        let enabledProfiles = browser.profiles.filter { $0.isEnabled }
        selectedProfileID = browser.defaultProfile?.id ?? enabledProfiles.first?.id
    }

    private func selectSourceAppFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "출처로 사용할 앱을 선택하세요"
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            if let bundleID = bundle?.bundleIdentifier {
                sourceAppBundleID = bundleID
            }
        }
    }
}

struct RulesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        RulesSettingsView()
            .environmentObject(RulesStore())
            .environmentObject(BrowserStore())
            .frame(width: 400, height: 300)
    }
}

enum RuleBrowserAvailability: Equatable {
    case available
    case browserDisabled
    case browserMissing
    case profileDisabled
    case profileMissing

    var warningText: String? {
        switch self {
        case .available:
            return nil
        case .browserDisabled:
            return "해당 브라우저는 비활성화되었습니다"
        case .browserMissing:
            return "해당 브라우저를 확인할 수 없습니다"
        case .profileDisabled:
            return "해당 프로필은 비활성화되었습니다"
        case .profileMissing:
            return "선택한 프로필을 찾을 수 없습니다"
        }
    }
}

/// Bundle Identifier로부터 앱 표시 이름을 가져옵니다.
/// 설치되지 않은 경우 bundle identifier를 그대로 반환합니다.
private func resolveAppDisplayName(for bundleIdentifier: String) -> String {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
          let bundle = Bundle(url: appURL) else {
        return bundleIdentifier
    }
    return bundle.infoDictionary?["CFBundleDisplayName"] as? String
        ?? bundle.infoDictionary?["CFBundleName"] as? String
        ?? bundleIdentifier
}

// MARK: - Bulk Edit View

/// V1 규칙 스키마

struct BulkEditView: View {
    @Environment(\.dismiss) private var dismiss
    let rules: [URLRule]
    let onSave: ([URLRule]) -> Void

    @State private var jsonText: String = ""
    @State private var errorMessage: String?
    @State private var showingConfirmation = false
    @State private var showingBackupWarning = true

    init(rules: [URLRule], onSave: @escaping ([URLRule]) -> Void) {
        self.rules = rules
        self.onSave = onSave
        _jsonText = State(initialValue: Self.rulesToJSON(rules))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("규칙 텍스트 편집")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // 경고 메시지
            if showingBackupWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("이 기능은 고급 사용자를 위한 것입니다. 변경 전 설정을 백업하는 것을 권장합니다.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button {
                        withAnimation {
                            showingBackupWarning = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            // 에러 메시지
            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }

            // JSON 편집기
            TextEditor(text: $jsonText)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .padding()

            Divider()

            // 하단 버튼
            HStack {
                Button("포맷 정리") {
                    formatJSON()
                }
                .help("JSON 형식을 정리합니다")

                Button("초기화") {
                    jsonText = Self.rulesToJSON(rules)
                    errorMessage = nil
                }
                .help("원래 규칙으로 되돌립니다")

                Spacer()

                Text("\(countRules()) 개 규칙")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("적용") {
                    validateAndApply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .alert("규칙 적용", isPresented: $showingConfirmation) {
            Button("취소", role: .cancel) { }
            Button("적용", role: .destructive) {
                applyChanges()
            }
        } message: {
            Text("규칙을 적용하시겠습니까?")
        }
    }
    private func countRules() -> Int {
        guard let data = jsonText.data(using: .utf8),
              let rules = try? JSONDecoder().decode([URLRule].self, from: data) else {
            return 0
        }
        return rules.count
    }

    private func formatJSON() {
        guard let data = jsonText.data(using: .utf8),
              let rules = try? JSONDecoder().decode([URLRule].self, from: data) else {
            errorMessage = "JSON 형식이 올바르지 않습니다."
            return
        }
        jsonText = Self.rulesToJSON(rules)
        errorMessage = nil
    }

    private func validateAndApply() {
        guard let data = jsonText.data(using: .utf8) else {
            errorMessage = "텍스트를 읽을 수 없습니다."
            return
        }

        do {
            // Raw Array 파싱 시도
            let rules = try JSONDecoder().decode([URLRule].self, from: data)

            // 중복 ID 검사 (ID는 로컬에서 생성되므로 JSON에는 없지만, 디코딩 후에는 UUID가 생성됨)
            // 사실상 JSON 편집 시 ID를 직접 다루지 않으므로 중복 검사는 큰 의미가 없을 수 있으나,
            // 패턴 중복 등을 검사하는 것이 더 유용할 수 있음.
            // 여기서는 기본 유효성 검사만 수행.

            // 기본 유효성 검사
            for (index, rule) in rules.enumerated() {
                if rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errorMessage = "규칙 #\(index + 1): 패턴이 비어 있습니다."
                    return
                }
                if rule.browserIdentifier == nil && rule.browserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errorMessage = "규칙 #\(index + 1): 브라우저 식별자가 없습니다."
                    return
                }
            }

            errorMessage = nil
            showingConfirmation = true
        } catch let error as DecodingError {
            switch error {
            case .dataCorrupted(let context):
                errorMessage = "데이터 손상: \(context.debugDescription)"
            case .keyNotFound(let key, _):
                errorMessage = "필수 키 누락: \(key.stringValue)"
            case .typeMismatch(_, let context):
                errorMessage = "타입 불일치: \(context.debugDescription)"
            case .valueNotFound(_, let context):
                errorMessage = "값 누락: \(context.debugDescription)"
            @unknown default:
                errorMessage = "알 수 없는 디코딩 오류"
            }
        } catch {
            errorMessage = "JSON 파싱 오류: \(error.localizedDescription)"
        }
    }

    private func applyChanges() {
        guard let data = jsonText.data(using: .utf8),
              let rules = try? JSONDecoder().decode([URLRule].self, from: data) else {
            return
        }
        onSave(rules)
        dismiss()
    }

    private static func rulesToJSON(_ rules: [URLRule]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(rules),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }
}
