import SwiftUI
import AppKit

struct DraggableURLView: View {
    let url: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundColor(.blue)
                .font(.caption)
                .alignmentGuide(.top) { _ in 0 }

            // 커서 깜빡임이 있는 텍스트 뷰
            ReadonlyTextView(text: url)
                .frame(minHeight: 40) // 최소 2줄이 보이도록 높이 설정
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .draggable(url) {
            // 드래그 프리뷰
            HStack {
                Image(systemName: "link")
                .foregroundColor(.blue)
                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .shadow(radius: 4)
        }
        .help("텍스트를 선택하여 복사하거나 다른 앱으로 드래그할 수 있습니다")
    }
}

class ReadonlyTextViewClass: NSTextView {
    override func insertText(_ insertString: Any) {
        // 텍스트 입력 차단 (readonly 동작)
        NSSound.beep()
    }

    override func deleteBackward(_ sender: Any?) {
        // 백스페이스 차단
        NSSound.beep()
    }

    override func deleteForward(_ sender: Any?) {
        // 델리트 차단
        NSSound.beep()
    }

    override func paste(_ sender: Any?) {
        // 붙여넣기 차단
        NSSound.beep()
    }

    // 드래그 앤 드롭 수신 차단
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // 드래그 앤 드롭으로 텍스트 변경 차단
        NSSound.beep()
        return false
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // 드래그 진입 시 거부 표시
        return []
    }

    // 컨텍스트 메뉴 커스터마이징 - 복사만 남기기
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // 텍스트가 선택되어 있을 때만 복사 메뉴 추가
        if selectedRange().length > 0 {
            let copyItem = NSMenuItem(title: "복사", action: #selector(copy(_:)), keyEquivalent: "c")
            copyItem.target = self
            menu.addItem(copyItem)
        }

        return menu.items.isEmpty ? nil : menu
    }
}

struct ReadonlyTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ReadonlyTextViewClass()

        // 텍스트 뷰 설정
        textView.string = text
        textView.isEditable = true  // 편집 가능으로 설정하여 커서 표시
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.clear
        textView.insertionPointColor = NSColor.controlAccentColor // 커서 색상

        // 텍스트 컨테이너 설정
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        // 크기 설정
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // 스크롤 뷰 설정
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // 드래그 앤 드롭 수신은 차단하되, 내보내기는 가능하도록
        textView.unregisterDraggedTypes()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? ReadonlyTextViewClass {
            if textView.string != text {
                textView.string = text
                textView.needsLayout = true
            }
        }
    }
}
