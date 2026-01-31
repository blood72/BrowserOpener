#!/bin/bash

# BrowserOpener 빌드 및 설치 스크립트

set -e

# 스크립트 디렉토리와 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

APP_NAME="BrowserOpener"
BUILD_DIR="${PROJECT_ROOT}/.build/release"

echo "BrowserOpener 빌드 시작..."

# Swift 패키지 빌드
cd "$PROJECT_ROOT"
swift build -c release

if [ $? -eq 0 ]; then
    echo "빌드 성공!"

    echo "기존 앱을 닫는 중..."
    killall BrowserOpener 2>/dev/null || true

    # 앱 번들 구조 생성
    echo "앱 번들 생성 중..."
    rm -rf /Applications/BrowserOpener.app
    mkdir -p /Applications/BrowserOpener.app/Contents/MacOS
    mkdir -p /Applications/BrowserOpener.app/Contents/Resources

    # 실행 파일 복사
    cp "${BUILD_DIR}/${APP_NAME}" /Applications/BrowserOpener.app/Contents/MacOS/

    # Info.plist 복사
    cp "${PROJECT_ROOT}/Info.plist" /Applications/BrowserOpener.app/Contents/

    # 아이콘 복사 (있는 경우)
    if [ -f "${PROJECT_ROOT}/DesignAssets/AppIcon.icns" ]; then
        cp "${PROJECT_ROOT}/DesignAssets/AppIcon.icns" /Applications/BrowserOpener.app/Contents/Resources/
    fi

    # 실행 권한 부여
    chmod +x /Applications/BrowserOpener.app/Contents/MacOS/BrowserOpener

    echo "설치 완료!"
    echo "시스템 환경설정 > 일반 > 기본 웹 브라우저에서 BrowserOpener를 선택하세요."
else
    echo "빌드 실패!"
    exit 1
fi
