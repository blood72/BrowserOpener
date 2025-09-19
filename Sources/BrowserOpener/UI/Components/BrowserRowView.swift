import SwiftUI

struct BrowserRowView: View {
    let browser: Browser
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let onProfileTap: (BrowserProfile) -> Void

    @State private var isExpanded = false
    @State private var isOpenButtonHovered = false
    @State private var isChevronHovered = false
    @AppStorage("expandProfilesOnBrowserSelect") private var expandProfilesOnBrowserSelect = true

    private var enabledProfiles: [BrowserProfile] {
        browser.profiles.filter { $0.isEnabled }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 12) {
                // 브라우저 아이콘
                if let icon = browser.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }

                // 브라우저 이름
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.name)
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(.primary)

                    if let defaultProfile = browser.defaultProfile {
                        Text(defaultProfile.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Open Button (Separate Action)
                Button(action: onTap) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 14))
                        .foregroundColor(isOpenButtonHovered ? .blue : .secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isOpenButtonHovered ? Color.blue.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isOpenButtonHovered = hovering
                }
                .help("기본 프로필로 열기")

                // Expand/Collapse Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(isChevronHovered ? .primary : .secondary)
                    .rotationEffect(Angle(degrees: isExpanded ? 90 : 0))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isChevronHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onHover { isHovered in
                        isChevronHovered = isHovered
                    }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle()) // 전체 영역 터치 가능
            .onTapGesture {
                if expandProfilesOnBrowserSelect {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } else {
                    onTap()
                }
            }

            // Expanded Profiles List
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(enabledProfiles) { profile in
                        ProfileRowView(
                            profile: profile,
                            isDefault: profile.id == browser.defaultProfile?.id,
                            onTap: {
                                onProfileTap(profile)
                            }
                        )
                    }
                }
                .padding(.leading, 56) // 아이콘 너비 + 패딩만큼 들여쓰기
                .padding(.bottom, 8)
            }
        }
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

struct ProfileRowView: View {
    let profile: BrowserProfile
    let isDefault: Bool
    let onTap: () -> Void
    @State private var isRowHovered = false
    @State private var isOpenIconHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // 프로필 아이콘
                Image(systemName: isDefault ? "star.fill" : "person.crop.circle")
                    .font(.system(size: 12))
                    .foregroundColor(isDefault ? .yellow : .secondary)
                    .frame(width: 16)

                Text(profile.name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                // Open Icon - Always visible but distinct on hover
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption2)
                    .foregroundColor(isOpenIconHovered ? .blue : (isRowHovered ? .secondary : .clear))
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isOpenIconHovered ? Color.blue.opacity(0.1) : Color.clear)
                    )
                    .onHover { isHovered in
                        isOpenIconHovered = isHovered
                    }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRowHovered ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRowHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isRowHovered = hovering
        }
    }
}
