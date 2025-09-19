import SwiftUI
import AppKit

struct PickerView: View {
    @EnvironmentObject private var browserManager: BrowserManager
    @EnvironmentObject private var rulesStore: RulesStore
    @State private var hoveredBrowser: Browser?
    @State private var showingAddRule = false
    @State private var isRuleAddHovered = false
    @State private var isUrlCopyHovered = false
    @State private var isCancelHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 영역
            headerView

            // URL 표시 영역
            if !browserManager.currentURL.isEmpty {
                urlDisplayView
            }

            // 브라우저 선택 영역
            browserListView

            // 하단 정보 및 설정 영역
            footerView
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            setupKeyboardMonitoring()
        }
        .focusable(false)
        .sheet(isPresented: $showingAddRule, onDismiss: {
            browserManager.sourceAppBundleID = nil
        }) {
            AddRuleView(
                browsers: browserManager.installedBrowsers,
                initialPattern: initialPattern,
                initialSourceAppBundleID: browserManager.sourceAppBundleID ?? ""
            ) { newRule in
                withAnimation {
                    rulesStore.rules.append(newRule)
                }
            }
        }
    }

    private var initialPattern: String {
        // 스킴(https:// 등)만 제거하고 전체 URL 반환
        // URLRule 파싱 로직이 host:port/path 형식을 처리하므로 전체를 넘겨주는 것이 좋음
        let urlString = browserManager.currentURL
        if let range = urlString.range(of: "://") {
            return String(urlString[range.upperBound...])
        }
        return urlString
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.blue)

            Text("브라우저 선택")
                .font(.title2)
                .fontWeight(.medium)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var urlDisplayView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("열려는 URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    showingAddRule = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption2)
                        Text("규칙 추가")
                            .font(.caption2)
                    }
                    .foregroundColor(isRuleAddHovered ? .blue : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isRuleAddHovered ? Color.blue.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isRuleAddHovered = isHovered
                }
                .help("이 URL에 대한 규칙 추가")

                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()

                    // 오직 플레인 텍스트만 설정 (다른 형식 차단)
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(browserManager.currentURL, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                        Text("URL 복사")
                            .font(.caption2)
                    }
                    .foregroundColor(isUrlCopyHovered ? .blue : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isUrlCopyHovered ? Color.blue.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isUrlCopyHovered = isHovered
                }
                .help("URL을 클립보드에 복사")
            }

            DraggableURLView(url: browserManager.currentURL)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var browserListView: some View {
        VStack(spacing: 8) {
            Text("브라우저 선택:")
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)

            if browserManager.installedBrowsers.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(browserManager.installedBrowsers) { browser in
                            BrowserRowView(
                                browser: browser,
                                isHovered: hoveredBrowser?.id == browser.id,
                                onTap: {
                                    browserManager.openURL(browserManager.currentURL, with: browser)
                                },
                                onHover: { isHovered in
                                    hoveredBrowser = isHovered ? browser : nil
                                },
                                onProfileTap: { profile in
                                    browserManager.openURL(browserManager.currentURL, with: browser, profile: profile)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(height: 240)
        .padding(.bottom, 16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("설치된 브라우저가 없습니다")
                .font(.headline)

            Text("브라우저를 설치한 후 다시 시도해주세요.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }

    private var footerView: some View {
        HStack {
            Button(action: {
                browserManager.close()
            }) {
                Text("취소")
                    .foregroundColor(isCancelHovered ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCancelHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isHovered in
                isCancelHovered = isHovered
            }

            Spacer()

            Text("ESC로 취소")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }


    private func setupKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC key
                self.browserManager.close()
                return nil
            }
            return event
        }
    }
}

struct PickerView_Previews: PreviewProvider {
    static var previews: some View {
        PickerView()
            .environmentObject(BrowserManager())
            .environmentObject(RulesStore())
    }
}
