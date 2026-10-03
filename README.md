# BrowserOpener

macOS 전용 브라우저 선택기 앱입니다.

## 기능

- URL 클릭 시 브라우저 선택 팝업
- 다중 프로필 지원 (Chrome, Edge, Vivaldi, ...)
- 메뉴바 상주 앱

## 개발 환경

### 요구사항

- 앱 배포 대상: macOS 13.0+ (`Package.swift` 및 `Info.plist`). `MenuBarExtra`도 macOS 13 API입니다. CI의 최신 macOS 검사와 실제 macOS 13에서의 실행 확인은 별개입니다.
- 패키지 도구 버전: Swift 5.9 (`swift-tools-version`). 오래된 컴파일러에서의 빌드 성공을 보장하는 표기는 아닙니다.
- CI 툴체인: Apple Silicon `macos-15` 러너의 **Xcode 26.0.1**. 실제 Swift·SDK·러너 이미지 버전은 산출물의 `build-info.json`에 기록합니다.
- 앱과 AppKit 테스트에는 macOS SDK가 필요합니다. Codex Cloud에서는 저장소를 편집하고, macOS 빌드·테스트는 GitHub Actions에서 수행합니다.

### 빌드 및 실행

```sh
# 아래 명령은 macOS 러너에서 실행합니다.
export DEVELOPER_DIR=/Applications/Xcode_26.0.1.app/Contents/Developer
make test
make dmg
```

`make dmg`는 기존 SwiftPM Release 빌드와 `scripts/create-dmg.sh`로 `dist/BrowserOpener-<버전>.dmg`를 생성합니다. `/Applications`에 설치하거나 앱을 실행하지 않습니다. `make build`는 `/Applications/BrowserOpener.app`를 교체하므로 CI에서 실행하지 않습니다.

## GitHub Actions 산출물

[macOS artifacts](https://github.com/blood72/BrowserOpener/actions/workflows/macos.yml)는 다음 순서로 실행합니다.

1. Apple Silicon 및 Xcode 버전 확인 → `make test` (실패 시 중단).
2. `make dmg`: Release 빌드 → 앱 번들 ad-hoc 서명 → DMG 생성.
3. 실제 DMG를 읽기 전용으로 마운트해 앱 구성, arm64 단일 아키텍처, 앱 버전, macOS 13.0 배포 대상, 서명 무결성과 `/Applications` 링크 검사.
4. DMG, `SHA256SUMS`, `build-info.json`, `Package.resolved`, 테스트·패키징·검증 로그를 artifact로 **14일** 보관.
5. 별도의 새 macOS 러너에서 업로드한 artifact를 다시 다운로드하고 SHA-256, 소스 커밋, 앱 구성·서명을 재검사.

`main` 및 `ci/**` 브랜치 push, `main` 대상 PR, 수동 `workflow_dispatch`를 지원합니다. 동일 저장소의 `ci/**` PR에서는 push 검증을 사용해 중복 빌드를 생략합니다. 그 외 PR과 fork PR은 PR 커밋을 검증합니다. 동일 이벤트·브랜치의 이전 실행은 취소합니다. 수동 실행 UI는 워크플로가 기본 브랜치에 병합된 뒤 사용할 수 있습니다.

워크플로 권한은 `contents: read`이며 인증서나 별도 토큰을 요구하지 않습니다. 앱은 **ad-hoc 서명**됩니다. Developer ID 서명이나 Apple 공증을 받은 배포본이 아니므로 다운로드한 앱의 Gatekeeper 허용 여부와 실제 사용자 Mac에서의 브라우저 선택·실행은 별도 확인이 필요합니다. CI는 기본 브라우저 설정을 바꾸지 않습니다. Intel 및 universal 빌드는 이번 파이프라인 범위에 포함하지 않습니다.

실행 페이지의 Artifacts 또는 작업 요약 링크에서 ZIP을 내려받아 압축 해제한 후 `shasum -a 256 -c SHA256SUMS`로 DMG를 확인할 수 있습니다. 다운로드에 GitHub 로그인이 필요할 수 있습니다. `build-info.json`은 빌드한 정확한 커밋을 기록하며, PR 실행에서는 병합 검증 커밋과 PR 원본 커밋을 구분합니다. CI 성공은 실제 macOS 13 사용자 환경에서 앱 실행까지 확인했다는 뜻이 아닙니다.

### 의존성 및 재현성

ViewInspector는 `Package.swift`의 기존 호환 범위 안에서 0.10.5 / `2dacb6e514be19379c605a5a11564d0f3fea89d9`로 `Package.resolved`에 고정합니다. 테스트·DMG 빌드는 `--force-resolved-versions`로 잠금 파일을 준수하며 CI에서 변경 여부도 검사합니다. 의존성을 갱신할 때는 macOS에서 명시적으로 재해결한 잠금 파일을 리뷰하고 전체 CI를 다시 실행해야 합니다. Actions도 커밋 SHA로 고정합니다. 호스팅 러너 이미지는 갱신되므로 산출물의 바이트 단위 동일성까지 보장하지는 않습니다.

### 후속 Release / Homebrew 배포

Actions artifact는 14일 후 만료되므로 Homebrew cask의 URL로 사용하지 않습니다. 후속 배포 작업에서는 검증한 소스 커밋에 새 버전 태그를 만들고, 해당 버전의 DMG와 SHA-256을 **버전별 고정 GitHub Release asset**으로 게시한 뒤 그 URL·체크섬을 tap에 등록해야 합니다. 게시 전 실제 Mac에서 실행 및 Gatekeeper 동작을 확인하고 ad-hoc 서명·공증 없음도 명시해야 합니다.

이 워크플로는 Release 게시, 기존 asset 교체, 태그 이동, `homebrew-taps` 변경을 수행하지 않습니다. 기존 1.0.1 Release는 보존하며, 같은 앱 버전으로 만들어진 CI artifact도 이를 대체하지 않습니다.

## Q&A

### 앱 번들 ID 찾기
```zsh
osascript -e 'id of app "Chromium"'
```
