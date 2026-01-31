import AppKit

class URLInterceptor {
    // URL 가로채기 발생 시 호출될 클로저 (URL, SourceAppBundleID?)
    private var onIntercept: ((URL, String?) -> Void)?

    // 이전에 활성화되었던 앱의 Bundle ID (자신 제외)
    // PSN fallback 시 frontmostApp이 자신일 경우 이 값을 사용
    private var lastActiveAppBundleID: String?

    // Apple Event 핸들러 등록
    func start(interceptHandler: ((URL, String?) -> Void)? = nil) {
        onIntercept = interceptHandler

        // 앱 활성화 변경 감지 등록
        setupAppActivationTracking()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    // 앱 활성화 변경 감지: 다른 앱이 활성화될 때마다 기록
    private func setupAppActivationTracking() {
        let workspace = NSWorkspace.shared
        let myBundleID = Bundle.main.bundleIdentifier

        // 초기값: 현재 frontmost가 자신이 아니면 저장
        if let frontmost = workspace.frontmostApplication,
           frontmost.bundleIdentifier != myBundleID {
            lastActiveAppBundleID = frontmost.bundleIdentifier
        }

        // 다른 앱이 활성화될 때마다 기록
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  bundleID != myBundleID else {
                return
            }
            self?.lastActiveAppBundleID = bundleID
            NSLog("[URLInterceptor] 📱 Active app changed: %@", bundleID)
        }
    }

    // Apple Event 처리 핸들러
    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        NSLog("[URLInterceptor] 🚀 handleGetURL called")

        // URL 추출
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            NSLog("[URLInterceptor] ❌ Failed to extract URL from event")
            return
        }

        NSLog("[URLInterceptor] 📎 URL received: %@", urlString)

        // 송신자 앱 Bundle Identifier 추출
        let sourceAppBundleID = extractSenderBundleIdentifier(from: event)
        NSLog("[URLInterceptor] 📤 sourceAppBundleID: %@", sourceAppBundleID ?? "nil")

        // 델리게이트 또는 클로저로 전달
        onIntercept?(url, sourceAppBundleID)
    }

    private func extractSenderBundleIdentifier(from event: NSAppleEventDescriptor) -> String? {
        // keyAddressAttr에서 송신자 정보 추출
        guard let senderDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) else {
            NSLog("[URLInterceptor] ❌ No senderDescriptor found")
            return nil
        }

        let descriptorType = senderDescriptor.descriptorType
        NSLog("[URLInterceptor] 📋 descriptorType: %u (PSN=%u, BundleID=%u, ApplSig=%u)", descriptorType, typeProcessSerialNumber, typeApplicationBundleID, typeApplSignature)

        // ProcessSerialNumber 타입인 경우 (구형 방식)
        if descriptorType == typeProcessSerialNumber {
            NSLog("[URLInterceptor] ⚠️ PSN type detected - falling through to frontmostApp fallback")
            var psn = ProcessSerialNumber()
            let data = senderDescriptor.data
            guard data.count >= MemoryLayout<ProcessSerialNumber>.size else {
                NSLog("[URLInterceptor] ❌ PSN data too small")
                return nil
            }
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
        if descriptorType == typeApplicationBundleID {
            let bundleID = senderDescriptor.stringValue
            NSLog("[URLInterceptor] ✅ ApplicationBundleID detected: %@", bundleID ?? "nil")
            return bundleID
        }

        // ApplSignature 타입인 경우
        if descriptorType == typeApplSignature {
            NSLog("[URLInterceptor] 🔍 ApplSignature type detected - searching by creator code")
            let data = senderDescriptor.data
            guard data.count >= 4 else {
                NSLog("[URLInterceptor] ❌ ApplSignature data too small")
                return nil
            }
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
                        NSLog("[URLInterceptor] ✅ Found app by ApplSignature: %@", bundleID)
                        return bundleID
                    }
                }
            }
            NSLog("[URLInterceptor] ❌ No app matched ApplSignature")
        }

        // 대안: 가장 최근에 포커스를 가진 앱을 송신자로 추정
        // (링크 클릭 직전에 활성화된 앱이 대부분 송신자)
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let frontmostBundleID = frontmostApp?.bundleIdentifier
        let myBundleID = Bundle.main.bundleIdentifier
        NSLog("[URLInterceptor] 🔄 Fallback - frontmostApp: %@, myBundleID: %@, lastActiveApp: %@",
              frontmostBundleID ?? "nil", myBundleID ?? "nil", lastActiveAppBundleID ?? "nil")

        if frontmostApp != nil {
            // BrowserOpener 자신이 frontmost인 경우(이미 활성화된 상태 등),
            // 이전에 활성화되었던 앱을 송신자로 사용
            if frontmostBundleID == myBundleID {
                if let lastActive = lastActiveAppBundleID {
                    NSLog("[URLInterceptor] ✅ Using lastActiveApp as sender: %@", lastActive)
                    return lastActive
                }
                NSLog("[URLInterceptor] ⚠️ frontmostApp is self and no lastActiveApp - returning nil")
                return nil
            }
            NSLog("[URLInterceptor] ✅ Using frontmostApp as sender: %@", frontmostBundleID ?? "nil")
            return frontmostBundleID
        }

        NSLog("[URLInterceptor] ❌ No frontmostApp available")
        return nil
    }
}
