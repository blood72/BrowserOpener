#!/bin/bash

# BrowserOpener DMG 생성 스크립트
# 로컬 배포용 (코드 서명 없음)

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 스크립트 디렉토리와 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 설정
APP_NAME="BrowserOpener"
BUILD_DIR="${PROJECT_ROOT}/.build/release"
DIST_DIR="${PROJECT_ROOT}/dist"
DMG_TMP_DIR="${DIST_DIR}/dmg_tmp"

# Info.plist에서 버전 추출
VERSION=$(defaults read "${PROJECT_ROOT}/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ${APP_NAME} DMG 생성 스크립트${NC}"
echo -e "${BLUE}  버전: ${VERSION}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 앱 빌드
echo -e "${YELLOW}[1/5] Swift 패키지 빌드 중...${NC}"
cd "$PROJECT_ROOT"
swift build -c release

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 빌드 실패!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 빌드 완료${NC}"

# 2. 기존 파일 정리
echo -e "${YELLOW}[2/5] 기존 파일 정리 중...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DMG_TMP_DIR"
echo -e "${GREEN}✓ 정리 완료${NC}"

# 3. 앱 번들 생성
echo -e "${YELLOW}[3/5] 앱 번들 생성 중...${NC}"
APP_BUNDLE="${DMG_TMP_DIR}/${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 실행 파일 복사
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Info.plist 복사
cp "${PROJECT_ROOT}/Info.plist" "${APP_BUNDLE}/Contents/"

# 아이콘 복사 (있는 경우)
if [ -f "${PROJECT_ROOT}/DesignAssets/AppIcon.icns" ]; then
    cp "${PROJECT_ROOT}/DesignAssets/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo -e "  ✓ 앱 아이콘 포함됨"
fi

echo -e "${GREEN}✓ 앱 번들 생성 완료${NC}"

# 4. Applications 심볼릭 링크 생성 (드래그 앤 드롭 설치용)
echo -e "${YELLOW}[4/5] DMG 콘텐츠 준비 중...${NC}"
ln -s /Applications "${DMG_TMP_DIR}/Applications"
echo -e "${GREEN}✓ DMG 콘텐츠 준비 완료${NC}"

# 5. DMG 생성
echo -e "${YELLOW}[5/5] DMG 생성 중...${NC}"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

# 기존 DMG 삭제
rm -f "$DMG_PATH"

# DMG 생성
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_TMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ DMG 생성 실패!${NC}"
    exit 1
fi

# 임시 폴더 정리
rm -rf "$DMG_TMP_DIR"

echo -e "${GREEN}✓ DMG 생성 완료${NC}"

# 완료 메시지
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ DMG 생성 성공!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "생성된 파일: ${BLUE}${DMG_PATH}${NC}"
echo -e "파일 크기: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo -e "${YELLOW}⚠️  참고: 이 DMG는 코드 서명되지 않았습니다.${NC}"
echo -e "${YELLOW}   다른 Mac에서 실행 시 '확인되지 않은 개발자' 경고가 표시될 수 있습니다.${NC}"
echo -e "${YELLOW}   이 경우 시스템 환경설정 > 개인 정보 보호 및 보안에서 '확인 없이 열기'를 클릭하세요.${NC}"
echo ""

# Finder에서 열기 (선택 옵션)
if [[ "$1" == "--open" ]]; then
    open "$DIST_DIR"
fi
