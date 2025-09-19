import SwiftUI

struct AboutSettingsView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                VStack(alignment: .leading, spacing: 4) {
                    Text("About")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("BrowserOpener에 대한 정보")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // 앱 정보
                VStack(spacing: 20) {
                    // 앱 아이콘 및 기본 정보
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        VStack(spacing: 4) {
                            Text("BrowserOpener")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("버전 \(appVersion) (빌드 \(buildNumber))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    // 설명
                    VStack(alignment: .leading, spacing: 8) {
                        Text("스마트 브라우저 선택기")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("URL을 열 때 적절한 브라우저를 선택할 수 있게 해주는 macOS 유틸리티입니다.\n규칙 기반 자동 선택과 수동 선택을 지원합니다.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // 링크들
                    VStack(spacing: 8) {
                        AboutLinkView(
                            title: "GitHub 저장소",
                            subtitle: "소스 코드 및 이슈 트래킹",
                            systemImage: "chevron.left.forwardslash.chevron.right",
                            action: {
                                NSWorkspace.shared.open(URL(string: "https://github.com/blood72/BrowserOpener")!)
                            }
                        )

                        AboutLinkView(
                            title: "라이선스",
                            subtitle: "MIT License",
                            systemImage: "doc.text",
                            action: {
                                // 라이선스 보기 액션
                            }
                        )

                        AboutLinkView(
                            title: "피드백 보내기",
                            subtitle: "버그 리포트 및 기능 요청",
                            systemImage: "envelope",
                            action: {
                                NSWorkspace.shared.open(URL(string: "https://github.com/blood72/BrowserOpener/issues")!)
                            }
                        )
                    }

                    Divider()

                    // 시스템 정보
                    VStack(alignment: .leading, spacing: 8) {
                        Text("시스템 정보")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            SystemInfoRow(title: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                            SystemInfoRow(title: "아키텍처", value: ProcessInfo.processInfo.machineHardwareName)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .focusable(false)
    }
}

struct AboutLinkView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SystemInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

struct AboutSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSettingsView()
            .frame(width: 400, height: 300)
    }
}
