import SwiftUI
import UniformTypeIdentifiers

struct BrowserSettingsView: View {
    @EnvironmentObject private var browserStore: BrowserStore
    @EnvironmentObject private var rulesStore: RulesStore
    @AppStorage("browserList.showAll") private var showAllBrowsers = false
    @AppStorage("browserList.showHidden") private var showHiddenBrowsers = false
    @State private var showingAddBrowser = false
    @State private var pendingBrowserAction: BrowserActionConfirmation?
    @State private var editingBrowser: Browser?

    var body: some View {
        let browsers = displayedBrowsers

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더
            VStack(alignment: .leading, spacing: 4) {
                Text("브라우저")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("사용할 브라우저를 관리하고 우선순위를 설정합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // 설정 내용
            VStack(alignment: .leading, spacing: 16) {
                // 브라우저 표시 옵션
                VStack(alignment: .leading, spacing: 8) {
                    Text("표시 옵션")
                        .font(.headline)

                    Toggle("설치되지 않은 브라우저도 표시", isOn: $showAllBrowsers)
                        .toggleStyle(.switch)
                        .font(.system(size: 13))
                        .help("설치되지 않은 브라우저도 목록에 회색으로 표시합니다")

                    Toggle("가려진 브라우저도 표시", isOn: $showHiddenBrowsers)
                        .toggleStyle(.switch)
                        .font(.system(size: 13))
                        .help("숨긴 브라우저를 목록에 표시합니다")
                }

                Divider()

                // 브라우저 목록
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("브라우저 목록")
                            .font(.headline)

                        Spacer()

                        Button("브라우저 추가") {
                            showingAddBrowser = true
                        }
                        .font(.system(size: 13))

                        Button("새로고침") {
                            browserStore.refreshInstallationStatus()
                        }
                        .font(.system(size: 13))
                    }

                    if browsers.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundColor(.orange)

                            Text("표시할 브라우저가 없습니다")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(browsers) { browser in
                                    BrowserSettingsRowView(
                                        browser: browser,
                        onToggle: { isOn in
                            handleToggle(for: browser, isOn: isOn)
                        },
                        onDelete: browser.isCustom ? {
                            handleDeletion(for: browser)
                        } : nil,
                        onToggleVisibility: browser.isPreset ? { isHidden in
                            handleVisibility(for: browser, isHidden: isHidden)
                        } : nil,
                        onEdit: {
                            editingBrowser = browser
                        }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 320)
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
        .onAppear {
            browserStore.refreshInstallationStatus()
        }
        .sheet(isPresented: $showingAddBrowser) {
            AddBrowserView { name, bundleId in
                withAnimation {
                    browserStore.addCustomBrowser(name: name, bundleIdentifier: bundleId)
                }
            }
        }
        .sheet(item: $editingBrowser) { browser in
            BrowserEditView(browser: browser) { result in
                browserStore.updateBrowserMetadata(
                    id: browser.id,
                    displayName: result.displayName,
                    bundleIdentifier: result.bundleIdentifier,
                    profiles: result.profiles,
                    defaultProfileID: result.defaultProfileID
                )
            }
            .environmentObject(rulesStore)
        }
        .alert(item: $pendingBrowserAction) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                primaryButton: .destructive(Text(context.actionTitle)) {
                    context.action()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func handleToggle(for browser: Browser, isOn: Bool) {
        guard !browser.isHidden else { return }

        // Req 4: 브라우저 비활성화 시 규칙 경고 (규칙은 비활성화하지 않음)
        if !isOn {
            let affectedRules = allRuleIDs(for: browser)
            if !affectedRules.isEmpty {
                pendingBrowserAction = BrowserActionConfirmation(
                    title: "\(browser.name) 비활성화",
                    message: "이 브라우저를 사용하는 \(affectedRules.count)개의 규칙이 있습니다. 브라우저를 비활성화하면 해당 규칙들이 정상적으로 동작하지 않을 수 있습니다.",
                    actionTitle: "비활성화",
                    action: {
                        browserStore.setEnabled(false, for: browser.id)
                    }
                )
                return
            }
        }
        browserStore.setEnabled(isOn, for: browser.id)
    }

    private func handleVisibility(for browser: Browser, isHidden: Bool) {
        // Req 4: 브라우저 가리기(비활성화 포함) 시 규칙 경고
        if isHidden {
            let affectedRules = allRuleIDs(for: browser)
            if !affectedRules.isEmpty {
                pendingBrowserAction = BrowserActionConfirmation(
                    title: "\(browser.name) 가리기",
                    message: "이 브라우저를 사용하는 \(affectedRules.count)개의 규칙이 있습니다. 브라우저를 가리면(비활성화) 해당 규칙들이 정상적으로 동작하지 않을 수 있습니다.",
                    actionTitle: "가리기",
                    action: {
                        browserStore.setHidden(true, for: browser.id)
                        browserStore.setEnabled(false, for: browser.id)
                    }
                )
                return
            }
        }

        browserStore.setHidden(isHidden, for: browser.id)
        if isHidden {
            browserStore.setEnabled(false, for: browser.id)
        }
    }

    private func handleDeletion(for browser: Browser) {
        let allRules = allRuleIDs(for: browser)
        if allRules.isEmpty {
            withAnimation {
                browserStore.removeCustomBrowser(id: browser.id)
            }
        } else {
            // Req 5: 브라우저 삭제 시 규칙 경고 (규칙은 비활성화하지 않음)
            pendingBrowserAction = BrowserActionConfirmation(
                title: "\(browser.name) 삭제",
                message: "이 브라우저를 사용하는 \(allRules.count)개의 규칙이 있습니다. 브라우저를 삭제하면 해당 규칙들이 정상적으로 동작하지 않을 수 있습니다.",
                actionTitle: "삭제",
                action: {
                    withAnimation {
                        browserStore.removeCustomBrowser(id: browser.id)
                    }
                }
            )
        }
    }

    private var displayedBrowsers: [Browser] {
        browserStore.browsers
            .filter { showAllBrowsers || $0.isInstalled }
            .filter { showHiddenBrowsers || !$0.isHidden }
    }

    private func allRuleIDs(for browser: Browser) -> [UUID] {
        rulesStore.rules
            .filter { rule in
                let matchesIdentifier = rule.browserIdentifier == browser.id
                let legacyMatch = rule.browserIdentifier == nil && rule.browserName == browser.name
                return matchesIdentifier || legacyMatch
            }
            .map(\.id)
    }

    private func updateRules(_ ids: [UUID], enabled: Bool) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        for index in rulesStore.rules.indices {
            if idSet.contains(rulesStore.rules[index].id) {
                rulesStore.rules[index].isEnabled = enabled
            }
        }
    }
}

struct BrowserActionConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
}

struct BrowserSettingsRowView: View {
    let browser: Browser
    let onToggle: (Bool) -> Void
    let onDelete: (() -> Void)?
    let onToggleVisibility: ((Bool) -> Void)?
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 브라우저 아이콘
            if let icon = browser.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .opacity(browser.isInstalled ? 1.0 : 0.5)
            } else {
                Image(systemName: browser.isCustom ? "app.fill" : browser.iconName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .opacity(browser.isInstalled ? 1.0 : 0.5)
            }

            // 활성화 토글
            Toggle("", isOn: Binding(
                get: { browser.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
            .disabled(!browser.isInstalled || browser.isHidden)

            // 브라우저 이름 및 상태
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(browser.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(browser.isInstalled ? .primary : .secondary)

                    if browser.isCustom {
                        Text("(사용자 추가)")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if browser.isHidden {
                        Text("가려짐")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onToggleVisibility = onToggleVisibility {
                Button {
                    onToggleVisibility(!browser.isHidden)
                } label: {
                    Image(systemName: browser.isHidden ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundColor(browser.isHidden ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .help(browser.isHidden ? "브라우저 보이기" : "브라우저 가리기")
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("브라우저 수정")

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("브라우저 삭제")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .opacity(browser.isHidden ? 0.5 : 1.0)
    }

    private var statusText: String {
        if !browser.isInstalled {
            return "설치되지 않음"
        } else if browser.isHidden {
            return "가려진 상태"
        } else {
            return "설치됨"
        }
    }
}

struct AddBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var browserName = ""
    @State private var bundleIdentifier = ""
    @State private var requiresInstallConfirmation = false
    let onAdd: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            VStack(alignment: .leading, spacing: 4) {
                Text("브라우저 추가")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("새로운 브라우저를 수동으로 추가합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 입력 필드들
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("브라우저 이름")
                        .font(.headline)
                    TextField("예: My Browser", text: $browserName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bundle Identifier")
                        .font(.headline)
                    HStack {
                        TextField("예: com.company.mybrowser", text: $bundleIdentifier)
                            .textFieldStyle(.roundedBorder)
                        Button("찾기...") {
                            selectAppFromFinder()
                        }
                    }
                    Text("앱의 Bundle Identifier를 입력하세요. '찾기...' 버튼으로 앱을 선택하면 자동으로 입력됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 버튼들
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("추가") {
                    handleAdd()
                }
                .disabled(browserName.isEmpty || bundleIdentifier.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 400, height: 300)
        .alert("브라우저 확인", isPresented: $requiresInstallConfirmation) {
            Button("추가", role: .destructive) {
                onAdd(browserName, bundleIdentifier)
                dismiss()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("입력하신 브라우저를 확인할 수 없습니다. 그래도 추가하시겠습니까? (\"설치되지 않은 브라우저도 표시\" 옵션을 활성화해서 확인할 수 있습니다)")
        }
    }

    private func handleAdd() {
        guard !browserName.isEmpty, !bundleIdentifier.isEmpty else { return }
        if Browser.isAppInstalled(bundleId: bundleIdentifier) {
            onAdd(browserName, bundleIdentifier)
            dismiss()
        } else {
            requiresInstallConfirmation = true
        }
    }

    private func selectAppFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "브라우저로 사용할 앱을 선택하세요"
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            if let bundleID = bundle?.bundleIdentifier {
                bundleIdentifier = bundleID
            }
            if browserName.isEmpty {
                let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle?.infoDictionary?["CFBundleName"] as? String
                    ?? url.deletingPathExtension().lastPathComponent
                browserName = displayName
            }
        }
    }
}

struct BrowserSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserSettingsView()
            .environmentObject(BrowserStore())
            .environmentObject(RulesStore())
            .frame(width: 400, height: 300)
    }
}

struct BrowserEditResult {
    let displayName: String
    let bundleIdentifier: String
    let profiles: [BrowserProfile]
    let defaultProfileID: String?
}

struct BrowserEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rulesStore: RulesStore
    let browser: Browser
    let onSave: (BrowserEditResult) -> Void

    @State private var displayName: String
    @State private var bundleIdentifier: String
    @State private var profileDrafts: [EditableProfile]
    @State private var defaultProfileID: String?
    @State private var pendingProfileDeletion: ProfileDeletionContext?
    @State private var pendingProfileDisable: ProfileDisableContext?

    init(browser: Browser, onSave: @escaping (BrowserEditResult) -> Void) {
        self.browser = browser
        self.onSave = onSave
        _displayName = State(initialValue: browser.name)
        _bundleIdentifier = State(initialValue: browser.bundleIdentifier)
        _profileDrafts = State(initialValue: browser.profiles.map { EditableProfile(profile: $0) })
        _defaultProfileID = State(initialValue: browser.defaultProfile?.id ?? browser.profiles.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("브라우저 수정")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Text("표시 이름")
                    .font(.headline)
                TextField("예: 업무용 Chrome", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            if browser.isCustom {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bundle Identifier")
                        .font(.headline)
                    TextField("예: com.company.browser", text: $bundleIdentifier)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bundle Identifier")
                        .font(.headline)
                    Text(browser.bundleIdentifier)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("프로필")
                        .font(.headline)
                    Spacer()
                    if !browser.isUnsupportedBrowser {
                        Button {
                            addProfile()
                        } label: {
                            Label("프로필 추가", systemImage: "plus")
                                .labelStyle(.iconOnly)
                        }
                        .help("프로필 추가")
                    }
                }

                if browser.isUnsupportedBrowser {
                    Text("\(browser.name)은(는) 명령줄 인자를 지원하지 않아 프로필 편집이 제한됩니다.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if profileDrafts.isEmpty {
                    Text("최소 1개의 프로필이 필요합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(profileDrafts) { profile in
                                profileEditor(for: profileBinding(profile))
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }

            Spacer()

            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("저장") {
                    persistChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 480, height: 540)
        .alert(item: $pendingProfileDeletion) { context in
            Alert(
                title: Text("\(context.profileName) 삭제"),
                message: Text("\(context.affectedRuleCount)개의 규칙이 이 프로필을 사용 중입니다. 프로필을 삭제하면 해당 규칙들이 정상적으로 동작하지 않을 수 있습니다."),
                primaryButton: .destructive(Text("삭제")) {
                    performRemoveProfile(with: context.profileID)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $pendingProfileDisable) { context in
            Alert(
                title: Text("\(context.profileName) 비활성화"),
                message: Text("\(context.affectedRuleIDs.count)개의 규칙이 이 프로필을 사용 중입니다. 프로필을 비활성화하면 해당 규칙들이 정상적으로 동작하지 않을 수 있습니다."),
                primaryButton: .destructive(Text("프로필 비활성화")) {
                    // Req 6: 프로필 비활성화 시 규칙은 비활성화하지 않음
                    performDisableProfile(with: context.profileID)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBundleIdentifier: String {
        bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedDisplayName.isEmpty && !profileDrafts.isEmpty
    }

    private func persistChanges() {
        guard canSave else { return }
        let resolvedDefault = defaultProfileID ?? profileDrafts.first?.id
        let profiles = profileDrafts.map { draft -> BrowserProfile in
            draft.toBrowserProfile(isDefault: draft.id == resolvedDefault)
        }

        let result = BrowserEditResult(
            displayName: trimmedDisplayName,
            bundleIdentifier: browser.isCustom ? trimmedBundleIdentifier : browser.bundleIdentifier,
            profiles: profiles,
            defaultProfileID: resolvedDefault
        )

        onSave(result)
        dismiss()
    }

    private func addProfile() {
        let newProfile = EditableProfile(
            id: UUID().uuidString,
            name: "새 프로필",
            argumentText: "",
            kind: .custom
        )
        withAnimation {
            profileDrafts.append(newProfile)
        }
        if defaultProfileID == nil {
            defaultProfileID = newProfile.id
        }
    }

    private func requestRemoveProfile(with id: String) {
        guard profileDrafts.count > 1 else { return }

        // 해당 프로필을 사용하는 규칙 확인
        let affectedRules = rulesStore.rules.filter { rule in
            rule.browserIdentifier == browser.id && rule.browserProfileIdentifier == id
        }

        if affectedRules.isEmpty {
            // 영향받는 규칙 없음 - 바로 삭제
            performRemoveProfile(with: id)
        } else {
            // 영향받는 규칙 있음 - 경고 표시
            let profile = profileDrafts.first { $0.id == id }
            pendingProfileDeletion = ProfileDeletionContext(
                profileID: id,
                profileName: profile?.name ?? "프로필",
                affectedRuleCount: affectedRules.count
            )
        }
    }

    private func performRemoveProfile(with id: String) {
        withAnimation {
            profileDrafts.removeAll { $0.id == id }
        }
        if defaultProfileID == id {
            defaultProfileID = profileDrafts.first?.id
        }
    }

    private func requestDisableProfile(with id: String) {
        // 해당 프로필을 사용하는 활성화된 규칙 확인
        let affectedRules = rulesStore.rules.filter { rule in
            rule.browserIdentifier == browser.id && rule.browserProfileIdentifier == id && rule.isEnabled
        }

        if affectedRules.isEmpty {
            // 영향받는 규칙 없음 - 바로 비활성화
            performDisableProfile(with: id)
        } else {
            // 영향받는 규칙 있음 - 경고 표시
            let profile = profileDrafts.first { $0.id == id }
            pendingProfileDisable = ProfileDisableContext(
                profileID: id,
                profileName: profile?.name ?? "프로필",
                affectedRuleIDs: affectedRules.map(\.id)
            )
        }
    }

    private func performDisableProfile(with id: String) {
        guard let index = profileDrafts.firstIndex(where: { $0.id == id }) else { return }
        profileDrafts[index].isEnabled = false

        // 비활성화된 프로필이 기본 프로필이면 다음 활성화된 프로필로 변경
        if defaultProfileID == id {
            defaultProfileID = profileDrafts.first(where: { $0.isEnabled })?.id ?? profileDrafts.first?.id
        }
    }

    private func disableProfileAndRules(profileID: String, ruleIDs: [UUID]) {
        performDisableProfile(with: profileID)
        // Req 6: 규칙 비활성화 로직 제거
    }

    private func profileBinding(_ profile: EditableProfile) -> Binding<EditableProfile> {
        guard let index = profileDrafts.firstIndex(where: { $0.id == profile.id }) else {
            return .constant(profile)
        }
        return $profileDrafts[index]
    }

    @ViewBuilder
    private func profileEditor(for profile: Binding<EditableProfile>) -> some View {
        let isDefault = defaultProfileID == profile.wrappedValue.id
        // Req 6: 기본 프로필, 감지된 프로필, 개인 모드 프로필은 삭제 불가 (비활성화만 가능)
        let isProtectedProfile = profile.wrappedValue.kind == .standard ||
                               profile.wrappedValue.kind == .detected ||
                               profile.wrappedValue.kind == .privateMode ||
                               isDefault

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    defaultProfileID = profile.wrappedValue.id
                } label: {
                    Image(systemName: isDefault ? "smallcircle.filled.circle" : "circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(!profile.wrappedValue.isEnabled)

                TextField("프로필 이름", text: profile.name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!profile.wrappedValue.isEnabled)

                Text(kindLabel(for: profile.wrappedValue.kind))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)

                Spacer()

                if !browser.isUnsupportedBrowser {
                    // 1. 활성화 토글 (모든 프로필에 표시)
                    Toggle("", isOn: Binding(
                        get: { profile.wrappedValue.isEnabled },
                        set: { newValue in
                            if newValue {
                                profile.wrappedValue.isEnabled = true
                            } else {
                                requestDisableProfile(with: profile.wrappedValue.id)
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)

                    // 2. 삭제 버튼 (보호되지 않은 프로필이고, 프로필이 1개 이상일 때 표시)
                    if !isProtectedProfile && profileDrafts.count > 1 {
                        Button {
                            requestRemoveProfile(with: profile.wrappedValue.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("프로필 삭제")
                    }
                }
            }

            if !browser.isUnsupportedBrowser {
                TextField("시작 인자 (예: --incognito --profile-directory=Work)", text: profile.argumentText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .disabled(!profile.wrappedValue.isEnabled)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .opacity(profile.wrappedValue.isEnabled ? 1.0 : 0.6)
    }

    private func kindLabel(for kind: BrowserProfile.Kind) -> String {
        switch kind {
        case .standard:
            return "기본"
        case .detected:
            return "감지됨"
        case .privateMode:
            return "개인 모드"
        case .custom:
            return "사용자 정의"
        }
    }
}



private struct ProfileDeletionContext: Identifiable {
    let id = UUID()
    let profileID: String
    let profileName: String
    let affectedRuleCount: Int
}

private struct ProfileDisableContext: Identifiable {
    let id = UUID()
    let profileID: String
    let profileName: String
    let affectedRuleIDs: [UUID]
}

private struct RuleSyncConfirmation: Identifiable {
    let id = UUID()
    let browser: Browser
    let ruleIDs: [UUID]
}
