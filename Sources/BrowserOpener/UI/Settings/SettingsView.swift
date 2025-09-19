import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "일반"
    case browsers = "브라우저"
    case rules = "규칙"
    case about = "About"

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .browsers: return "globe"
        case .rules: return "list.bullet.clipboard"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @EnvironmentObject var rulesStore: RulesStore
    @EnvironmentObject var browserStore: BrowserStore

    var body: some View {
        VStack(spacing: 0) {
            // AltTab 스타일 상단 탭 바
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 메인 콘텐츠 영역
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .browsers:
                    BrowserSettingsView()
                        .environmentObject(browserStore)
                case .rules:
                    RulesSettingsView()
                        .environmentObject(rulesStore)
                        .environmentObject(browserStore)
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 720)
        .navigationTitle("설정")
        .focusable(false)
    }
}

struct SettingButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(width: 60, height: 60)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.8) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        } else if isHovered {
            return Color.secondary.opacity(0.12)
        } else {
            return Color.clear
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(RulesStore())
            .environmentObject(BrowserStore())
    }
}
