import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
    @AppStorage("useRulesForAutomaticOpening") private var useRulesForAutomaticOpening = true
    @AppStorage("expandProfilesOnBrowserSelect") private var expandProfilesOnBrowserSelect = true
    @State private var showingResetConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var showingImportConfirmation = false
    @State private var pendingImportURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            VStack(alignment: .leading, spacing: 4) {
                Text("일반")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("URL을 열 때 규칙을 사용할지 여부를 설정합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // 설정 내용
            VStack(alignment: .leading, spacing: 20) {
                // 규칙 사용 방식
                VStack(alignment: .leading, spacing: 8) {
                    Text("동작 방식")
                        .font(.headline)

                    Toggle("규칙을 우선 사용 (매칭 실패 시 팝업)", isOn: $useRulesForAutomaticOpening)
                        .toggleStyle(.switch)
                        .font(.system(size: 13))
                        .help("규칙에 매칭되는 경우 바로 해당 브라우저로 열고, 실패 시에만 브라우저 선택 팝업을 띄웁니다")

                    Toggle("브라우저 선택 시 프로필 목록 펼치기", isOn: $expandProfilesOnBrowserSelect)
                        .toggleStyle(.switch)
                        .font(.system(size: 13))
                        .help("브라우저 선택 시 프로필 목록을 펼칩니다. 끄면 기본 프로필로 바로 엽니다")
                }

                Divider()

                // 데이터 관리
                VStack(alignment: .leading, spacing: 12) {
                    Text("데이터 관리")
                        .font(.headline)

                    // 설정 내보내기/불러오기
                    HStack(spacing: 12) {
                        Button("설정 내보내기...") {
                            exportSettings()
                        }
                        Button("설정 불러오기...") {
                            importSettings()
                        }
                    }
                    Text("브라우저, 규칙, 프로필 설정을 파일로 내보내거나 불러올 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    // 설정 초기화
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("설정 초기화")
                                .font(.system(size: 13))
                            Text("브라우저 설정, 규칙, 프로필 등 모든 설정을 초기화합니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("초기화...") {
                            showingResetConfirmation = true
                        }
                        .foregroundColor(.red)
                    }

                    Text("모든 설정이 제거되며 앱이 종료됩니다. 재실행할 때 초기 구성을 다시 진행합니다.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .focusable(false)
        .alert("내보내기 완료", isPresented: $showingExportSuccess) {
            Button("확인") { }
        } message: {
            Text("설정이 성공적으로 내보내졌습니다.")
        }
        .alert("불러오기 완료", isPresented: $showingImportSuccess) {
            Button("확인") { }
        } message: {
            Text("설정이 성공적으로 불러와졌습니다. 앱이 종료됩니다. 다시 실행해주세요.")
        }
        .alert("불러오기 실패", isPresented: $showingImportError) {
            Button("확인") { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("설정 초기화", isPresented: $showingResetConfirmation) {
            Button("취소", role: .cancel) { }
            Button("초기화 및 종료", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("모든 설정이 초기화되고 앱이 종료됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("설정 불러오기", isPresented: $showingImportConfirmation) {
            Button("취소", role: .cancel) { }
            Button("불러오기 및 종료", role: .destructive) {
                confirmAndImportSettings()
            }
        } message: {
            Text("모든 설정을 불러오고 앱이 종료됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
    }

    private func resetAllSettings() {
        // 앱의 모든 UserDefaults 데이터 삭제
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        UserDefaults.standard.synchronize()

        // 앱 종료
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "BrowserOpener-Settings.json"
        panel.message = "설정을 내보낼 위치를 선택하세요"
        panel.prompt = "내보내기"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let jsonData = try SettingsImportExportManager.shared.exportSettings(defaults: .standard)
                try jsonData.write(to: url)
                showingExportSuccess = true
            } catch {
                importErrorMessage = "내보내기 중 오류가 발생했습니다: \(error.localizedDescription)"
                showingImportError = true
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.message = "불러올 설정 파일을 선택하세요"
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            // 파일을 선택하면 즉시 불러오지 않고 확인 팝업을 띄움
            pendingImportURL = url
            showingImportConfirmation = true
        }
    }

    private func confirmAndImportSettings() {
        guard let url = pendingImportURL else { return }

        do {
            let data = try Data(contentsOf: url)
            try SettingsImportExportManager.shared.importSettings(from: data, to: .standard)

            // Req 2: 설정 불러오기 및 종료
            // 성공 메시지 팝업 없이 바로 종료 (이미 확인 팝업에서 고지함)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            importErrorMessage = "불러오기 중 오류가 발생했습니다: \(error.localizedDescription)"
            showingImportError = true
        }
    }
}
