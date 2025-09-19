#!/bin/bash

echo "BrowserOpener 빌드 시작..."

# Swift 패키지 빌드
swift build -c release

if [ $? -eq 0 ]; then
    echo "빌드 성공!"

    echo "기존 앱을 닫는 중..."
    killall BrowserOpener 2>/dev/null || true

    # 앱 번들 구조 생성
    echo "앱 번들 생성 중..."
    rm -rf /Applications/BrowserOpener.app
    mkdir -p /Applications/BrowserOpener.app/Contents/MacOS

    # 실행 파일 복사
    cp .build/release/BrowserOpener /Applications/BrowserOpener.app/Contents/MacOS/

    # Info.plist 복사
    cp Info.plist /Applications/BrowserOpener.app/Contents/

    # 실행 권한 부여
    chmod +x /Applications/BrowserOpener.app/Contents/MacOS/BrowserOpener

    echo "설치 완료!"
    echo "시스템 환경설정 > 일반 > 기본 웹 브라우저에서 BrowserOpener를 선택하세요."
else
    echo "빌드 실패!"
    exit 1
fi
