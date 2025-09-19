# BrowserOpener

macOS 전용 브라우저 선택기 앱입니다.

## 기능

- URL 클릭 시 브라우저 선택 팝업
- 다중 프로필 지원 (Chrome, Edge, Vivaldi, ...)
- 메뉴바 상주 앱

## 개발 환경

### 요구사항

- macOS 14.0+
- Swift 6.1+
- XCode 26.0+ (for testing)

### 빌드 및 실행

```zsh
# 코드 테스트
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# 번들을 생성하고 Applications에 복사 후 실행
./build.sh
```

## Q&A

### 앱 번들 ID 찾기
```zsh
osascript -e 'id of app "Chromium"'
```
