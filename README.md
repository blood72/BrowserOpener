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

`main` 브랜치 push, `main` 대상 PR(포크 포함), 수동 `workflow_dispatch`를 지원합니다. 작업 브랜치에서는 PR 이벤트만 빌드해 push와 PR의 중복 실행을 피합니다. 동일 이벤트·브랜치의 이전 실행은 취소합니다. 수동 실행 UI는 워크플로가 기본 브랜치에 병합된 뒤 사용할 수 있습니다.

워크플로 권한은 `contents: read`이며 인증서나 별도 토큰을 요구하지 않습니다. 앱은 **ad-hoc 서명**됩니다. Developer ID 서명이나 Apple 공증을 받은 배포본이 아니므로 다운로드한 앱의 Gatekeeper 허용 여부와 실제 사용자 Mac에서의 브라우저 선택·실행은 별도 확인이 필요합니다. CI는 기본 브라우저 설정을 바꾸지 않습니다. Intel 및 universal 빌드는 이번 파이프라인 범위에 포함하지 않습니다.

실행 페이지의 Artifacts 또는 작업 요약 링크에서 ZIP을 내려받아 압축 해제한 후 `shasum -a 256 -c SHA256SUMS`로 DMG를 확인할 수 있습니다. 다운로드에 GitHub 로그인이 필요할 수 있습니다. `build-info.json`은 빌드한 정확한 커밋을 기록하며, PR 실행에서는 병합 검증 커밋과 PR 원본 커밋을 구분합니다. CI 성공은 실제 macOS 13 사용자 환경에서 앱 실행까지 확인했다는 뜻이 아닙니다.

### 의존성 및 재현성

ViewInspector는 `Package.swift`의 기존 호환 범위 안에서 0.10.5 / `2dacb6e514be19379c605a5a11564d0f3fea89d9`로 `Package.resolved`에 고정합니다. 테스트·DMG 빌드는 `--force-resolved-versions`로 잠금 파일을 준수하며 CI에서 변경 여부도 검사합니다. 의존성을 갱신할 때는 macOS에서 명시적으로 재해결한 잠금 파일을 리뷰하고 전체 CI를 다시 실행해야 합니다. Actions도 커밋 SHA로 고정합니다. 호스팅 러너 이미지는 갱신되므로 산출물의 바이트 단위 동일성까지 보장하지는 않습니다.

### 후속 Release / Homebrew 배포

Actions artifact는 14일 후 만료되므로 Homebrew cask의 URL로 사용하지 않습니다. 후속 배포 작업에서는 검증한 소스 커밋에 새 버전 태그를 만들고, 해당 버전의 DMG와 SHA-256을 **버전별 고정 GitHub Release asset**으로 게시한 뒤 그 URL·체크섬을 tap에 등록해야 합니다. 게시 전 실제 Mac에서 실행 및 Gatekeeper 동작을 확인하고 ad-hoc 서명·공증 없음도 명시해야 합니다.

일반 `macOS artifacts` 워크플로는 Release 작성·게시를 수행하지 않습니다. 아래 별도 workflow는 검토용 Draft Release만 작성합니다. 두 workflow 모두 기존 1.0.1 Release asset 교체, 태그 이동, `homebrew-taps` 변경은 수행하지 않습니다.

## 1.0.2 Draft Release 준비

앱 표시 버전은 `Info.plist`의 `CFBundleShortVersionString` **1.0.2**, 빌드 번호는 `CFBundleVersion` **2**입니다. DMG 이름과 `build-info.json`도 같은 plist에서 생성합니다. 앱 기능은 변경하지 않습니다.

`Draft Release` (`.github/workflows/release.yml`)는 **main에 병합한 후** 수동 실행합니다. PR이나 작업 브랜치에서 배포 권한으로 실행하지 않습니다.

1. 병합된 최신 main의 전체 40자리 SHA를 확인합니다.
2. Actions의 `Draft Release` → `Run workflow`에서 branch는 `main`, `version`은 `1.0.2`, `target_commit`은 확인한 SHA를 입력합니다. 실행 시 main이 바뀌어 SHA가 다르면 중단하므로 최신 SHA를 다시 확인합니다.
3. 읽기 전용 `preflight`가 main 실행·정확한 SHA·plist 버전·기존 태그 및 조회 가능한 Release 충돌을 확인합니다. Draft가 목록에서 숨겨질 수 있으므로 이 단계만으로 Draft 충돌이 없다고 판단하지 않습니다. 태그 이름은 기존처럼 `1.0.2`이며 `v`를 붙이지 않습니다.
4. 기존 `macOS artifacts` workflow를 재사용해 `make test`, `make dmg`, DMG 검증·artifact 업로드·새 macOS 러너 재다운로드 검증을 수행합니다.
5. 이 검증들이 모두 성공해야 쓰기 권한의 `draft` 작업이 빌드 artifact의 체크섬·출처를 검사하고 **Draft를 포함한 Release 충돌을 다시 검사**합니다. 충돌이 없을 때만 `draft=true`, `prerelease=false`, `target_commitish=<전체 SHA>`인 Release를 만들고 `BrowserOpener-1.0.2.dmg`, `SHA256SUMS`, `build-info.json`을 첨부합니다.
6. 같은 `draft` 작업에서 **실제 Release asset API를 통해 첨부 파일을 새 디렉터리로 다시 다운로드**합니다. SHA-256·출처와 다운로드 시점의 Draft 상태를 확인한 뒤 Release ID·asset ID·파일 해시·커밋·Actions 실행을 `release-receipt.json`으로 기록합니다. 이 다운로드 파일과 기록만 별도의 `release-download-...` artifact에 14일간 보관합니다. 최초 빌드 artifact를 복사해 전달하지 않습니다.
7. 읽기 전용 macOS `verify-release` 작업은 `draft`가 출력한 **artifact ID**로 이 전달용 artifact를 받습니다. Draft API나 쓰기 토큰 없이 출처 기록·Release ID·커밋·체크섬을 대조하고 DMG 내부의 버전·arm64·macOS 13.0 타깃·ad-hoc 서명을 검사합니다. 이 작업까지 성공해야 배포 경로가 검증된 것입니다. 이 단계는 다운로드 시점 이후의 Draft 상태를 API로 재조회하지 않습니다.

기본 권한과 빌드·검증 권한은 `contents: read`입니다. 초안 작성·첨부·실제 Release 다운로드를 담당하는 **기존 `draft` 작업 한 곳만** `contents: write`를 사용합니다. 기본 `GITHUB_TOKEN`을 사용하며 별도 인증서·비밀키는 필요 없습니다. 앱은 계속 ad-hoc 서명이고 공증되지 않습니다.

[GitHub 공식 List releases 문서](https://docs.github.com/en/rest/releases/releases#list-releases)는 “Only users with push access will receive listings for draft releases.”라고 명시합니다. 일반 조회 endpoint의 `Contents: read` 최소 권한만으로 비공개 Draft와 asset 접근까지 보장된다고 가정하지 않습니다. 따라서 Draft 목록·첨부 파일 접근은 쓰기 권한 job에 두고, 읽기 전용 macOS job은 전달받은 실제 Release 다운로드 파일만 검증합니다. 출처 기록은 이 workflow의 전달 경로를 확인하는 자료이며 독립적인 서명·공증은 아닙니다.

### 중복·실패 처리

같은 버전의 실행을 직렬화하며 업로드 도중 취소하지 않습니다. 빌드 전 읽기 전용 검사는 조회 가능한 Release·태그에 한정됩니다. 초안 작성 직전에는 쓰기 토큰으로 Draft까지 포함해 다시 검사합니다. **같은 커밋이라도 이미 해당 버전의 태그나 Release가 있으면 중단**하고 기존 draft 여부·대상·파일명을 보고합니다. 재빌드된 DMG는 바이트가 달라질 수 있으므로 기존 파일과 자동으로 섞거나 덮어쓰지 않습니다.

API 오류나 부분 업로드 후에는 기존 초안을 남기고 실패합니다. 무조건 재실행하거나 기존 초안을 자동 삭제하지 말고 원인과 첨부된 파일을 확인해야 합니다. 같은 버전의 부분 초안 복구는 별도로 판단합니다. 이미 공개된 Release에는 쓰지 않습니다. workflow에는 Release 공개 전환, 태그 이동, asset 교체·삭제 경로가 없습니다.

초안은 대상 커밋과 새 태그 이름을 고정하지만 태그 ref를 별도로 생성하거나 이동하지 않습니다. GitHub의 Draft Release 생성 성공만으로 태그가 이미 생성됐다고 간주하지 않습니다. 향후 공개 게시 시 해당 SHA에 태그가 연결되는지도 확인해야 합니다.

### 사용자 검토와 이후 공개 배포

이전 1.0.1 CI 빌드의 사용자 Mac 실행 확인은 새 1.0.2 산출물의 실기 검증으로 대신하지 않습니다. 새 DMG를 사용자 Mac에서 확인한 후 공개 여부를 결정합니다. macOS 13.0은 배포 타깃이며 해당 OS 실기 검증 완료를 뜻하지 않습니다.

이번 workflow는 Draft에서 멈춥니다. Draft 다운로드는 인증이 필요한 비공개 검토용이며 **아직 공개 tap용 URL이 아닙니다**. 14일 보관되는 Actions artifact와 별개로 Release 첨부 파일은 Release에 남습니다. 향후 사용자가 정식 게시한 뒤 버전별 고정 Release asset URL과 SHA-256을 검증하고 별도 `homebrew-taps` PR을 준비합니다. Actions artifact URL은 cask에 사용하지 않습니다.

PR CI에서 통과하는 빌드·테스트 및 모의 API 테스트와, 실제 Draft 작성·Release asset 다운로드 경로의 실증은 구분합니다. 후자는 main 병합 후 승인된 수동 Release 실행에서 확인해야 합니다. Cloud의 추가 다운로드 도메인 허용은 Cloud에서 직접 파일을 확인하기 위한 별도 설정이며 GitHub Actions 실행 조건이 아닙니다.

## Q&A

### 앱 번들 ID 찾기
```zsh
osascript -e 'id of app "Chromium"'
```
