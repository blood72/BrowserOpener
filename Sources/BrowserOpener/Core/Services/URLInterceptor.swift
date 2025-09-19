import AppKit

class URLInterceptor {
    // URL 가로채기 발생 시 호출될 클로저 (URL, SourceAppBundleID?)
    private var onIntercept: ((URL, String?) -> Void)?

    // Apple Event 핸들러 등록
    func start(interceptHandler: ((URL, String?) -> Void)? = nil) {
        onIntercept = interceptHandler

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    // Apple Event 처리 핸들러
    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // URL 추출
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        // 송신자 앱 Bundle Identifier 추출
        let sourceAppBundleID = extractSenderBundleIdentifier(from: event)

        // 델리게이트 또는 클로저로 전달
        onIntercept?(url, sourceAppBundleID)
    }

    private func extractSenderBundleIdentifier(from event: NSAppleEventDescriptor) -> String? {
        // keyAddressAttr에서 송신자 정보 추출
        guard let senderDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) else {
            return nil
        }

        // ProcessSerialNumber 타입인 경우 (구형 방식)
        if senderDescriptor.descriptorType == typeProcessSerialNumber {
            var psn = ProcessSerialNumber()
            let data = senderDescriptor.data
            guard data.count >= MemoryLayout<ProcessSerialNumber>.size else { return nil }
            _ = data.withUnsafeBytes { ptr in
                memcpy(&psn, ptr.baseAddress!, MemoryLayout<ProcessSerialNumber>.size)
            }
            // ProcessSerialNumber에서 앱 정보 추출
            // - PSN 처리 로직은 신뢰성이 낮아 생략하고 frontmostApp fallback을 사용하는 기존 로직 유지
            // - Note: PSN을 PID로 변환하는 것은 deprecated API 없이 어려움.
            //         기존의 "현재 앱이 아닌 다른 앱 찾기" 로직은 잘못된 결과를 초래하므로 제거.
            //         대신 아래의 frontmostApp fallback을 사용하도록 함.
        }

        // ApplicationBundleID 타입인 경우 (신형 방식)
        if senderDescriptor.descriptorType == typeApplicationBundleID {
            return senderDescriptor.stringValue
        }

        // ApplSignature 타입인 경우
        if senderDescriptor.descriptorType == typeApplSignature {
            let data = senderDescriptor.data
            guard data.count >= 4 else { return nil }
            let signature = data.withUnsafeBytes { ptr -> OSType in
                ptr.load(as: OSType.self)
            }
            // Creator code로 앱 찾기
            for app in NSWorkspace.shared.runningApplications {
                if let bundleID = app.bundleIdentifier,
                   let bundle = Bundle(identifier: bundleID),
                   let creatorCode = bundle.infoDictionary?["CFBundleSignature"] as? String,
                   creatorCode.utf8.count == 4 {
                    let appSignature = creatorCode.utf8.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
                    if appSignature == signature {
                        return bundleID
                    }
                }
            }
        }

        // 대안: 가장 최근에 포커스를 가진 앱을 송신자로 추정
        // (링크 클릭 직전에 활성화된 앱이 대부분 송신자)
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            // BrowserOpener 자신이 frontmost인 경우(이미 활성화된 상태 등),
            // 자신을 제외한 그 다음 앱을 찾아야 함.
            if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
                // 실행 중인 앱 중 활성화된 순서대로 정렬하여 두 번째 앱을 찾음 (완벽하지 않음)
                // 하지만 macOS API 한계상 이 방법이 최선일 수 있음.
                // 여기서는 단순히 nil을 반환하여, "출처 없음"으로 처리하거나
                // 사용자가 직접 선택하게 하는 것이 나을 수 있음.
                return nil
            }
            return frontmostApp.bundleIdentifier
        }

        return nil
    }
}
