#!/usr/bin/env python3
"""Create one immutable set of draft assets; never publish, replace, delete or retag."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import urllib.error
import urllib.parse
import urllib.request


def require(condition, message):
    if not condition:
        raise ValueError(message)


class StripCrossHostAuth(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected and urllib.parse.urlsplit(req.full_url).netloc != urllib.parse.urlsplit(newurl).netloc:
            redirected.remove_header('Authorization')
        return redirected


class GitHub:
    def __init__(self, repository, token):
        self.repository = repository
        self.token = token
        self.opener = urllib.request.build_opener(StripCrossHostAuth)

    def request(self, path, *, data=None, binary=False, upload=None, missing_ok=False):
        host = 'uploads.github.com' if upload is not None else 'api.github.com'
        headers = {'Authorization': f'Bearer {self.token}',
                   'Accept': 'application/octet-stream' if binary else 'application/vnd.github+json',
                   'X-GitHub-Api-Version': '2022-11-28'}
        payload = None
        if upload is not None:
            payload = upload.read_bytes()
            headers['Content-Type'] = 'application/octet-stream'
        elif data is not None:
            payload = json.dumps(data).encode()
            headers['Content-Type'] = 'application/json'
        req = urllib.request.Request(f'https://{host}/repos/{self.repository}/{path}',
                                     data=payload, headers=headers)
        try:
            with self.opener.open(req, timeout=60) as response:
                result = response.read()
        except urllib.error.HTTPError as error:
            if missing_ok and error.code == 404:
                return None
            raise RuntimeError(f'GitHub request failed: HTTP {error.code} for {path}. '
                               'Inspect the draft before retrying; no overwrite was attempted.') from None
        return result if binary else json.loads(result)


def context():
    version, commit = os.environ['RELEASE_VERSION'], os.environ['TARGET_COMMIT']
    require(re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', version), 'Invalid version')
    require(re.fullmatch(r'[0-9a-f]{40}', commit), 'Use a full lowercase 40-character commit SHA')
    require(os.environ['GITHUB_REPOSITORY'] == 'blood72/BrowserOpener', 'Unexpected repository')
    require(os.environ['GITHUB_EVENT_NAME'] == 'workflow_dispatch', 'Manual dispatch required')
    require(os.environ['GITHUB_REF'] == 'refs/heads/main', 'Dispatch this workflow on main only')
    require(os.environ['GITHUB_SHA'] == commit, 'Target must equal main SHA selected at dispatch; retry with the current SHA')
    root = Path(__file__).resolve().parent.parent
    with (root / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    require(info['CFBundleShortVersionString'] == version, 'Input version differs from Info.plist')
    run_url = (f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/"
               f"{os.environ['GITHUB_RUN_ID']}")
    return version, commit, info, run_url


def ensure_no_visible_conflict(api, version):
    # GitHub lists drafts only with push access. Read-only preflight is advisory;
    # create() must repeat this check using the write job's token before mutation.
    page = 1
    while True:
        releases = api.request(f'releases?per_page=100&page={page}')
        for release in releases:
            if release['tag_name'] == version:
                assets = ', '.join(asset['name'] for asset in release['assets']) or '(none)'
                raise ValueError(f"Version {version} already has release {release['id']}: "
                                 f"draft={release['draft']}, target={release['target_commitish']}, "
                                 f"assets={assets}. Stop and inspect it; even same-commit reruns do not modify it.")
        if len(releases) < 100:
            break
        page += 1
    tag = api.request(f'git/ref/tags/{version}', missing_ok=True)
    require(tag is None, f'Tag {version} already exists; never move or reuse it for this workflow')


def asset_names(version):
    return (f'BrowserOpener-{version}.dmg', 'SHA256SUMS', 'build-info.json')


def validate_artifacts(directory, version, commit, info, run_url):
    dmg, sums, metadata = (directory / name for name in asset_names(version))
    expected_line = hashlib.sha256(dmg.read_bytes()).hexdigest() + '  ' + dmg.name
    require(sums.read_text().strip() == expected_line, 'DMG SHA256SUMS mismatch or unexpected filename')
    build = json.loads(metadata.read_text())
    expected = {'source_commit': commit, 'event_head_commit': commit, 'app_version': version,
                'bundle_version': info['CFBundleVersion'], 'architecture': 'arm64',
                'minimum_macos': '13.0', 'notarized': False,
                'signature': 'ad-hoc (no Developer ID certificate)', 'run_url': run_url}
    for key, value in expected.items():
        require(build.get(key) == value, f'Artifact provenance mismatch: {key}')
    print(expected_line)


def check_draft(release, version, commit):
    require(release['draft'] is True, 'Release is public; refusing to change or claim a draft')
    require(release['prerelease'] is False, 'Unexpected prerelease flag')
    require(release['tag_name'] == version, 'Release version mismatch')
    require(release['target_commitish'] == commit, 'Release target commit mismatch')


def release_body(version, commit, run_url):
    return f'''BrowserOpener {version} — 검토용 Draft Release

- 대상 커밋: `{commit}`
- 테스트·패키징·artifact 재다운로드 검증: {run_url}
- CI·패키징·배포 절차 중심의 변경이며 앱 기능 리팩터링은 포함하지 않습니다.
- **Apple Silicon arm64 전용**입니다.
- **macOS 13.0 배포 타깃**을 바이너리에서 검사합니다. macOS 13 실기 검증은 하지 않았습니다.
- **ad-hoc 서명**이며 Developer ID 서명·Apple 공증은 없습니다.
- 이 새 {version} 산출물은 사용자 Mac에서 아직 검증하지 않았습니다. 이전 1.0.1 CI 빌드의 사용자 실행 확인을 대신 사용하지 않습니다.
- DMG와 `SHA256SUMS`, 정확한 소스·툴체인 정보를 담은 `build-info.json`을 첨부합니다.
- 쓰기 권한의 `draft` 작업이 실제 Release 첨부 파일을 다시 내려받고 출처 기록과 함께 별도 artifact로 전달합니다. 마지막 읽기 전용 `verify-release` 작업이 그 파일을 macOS에서 검사합니다. 이 작업까지 성공했는지 확인한 뒤 검토하세요.

초안은 공개 게시되지 않았으며 다운로드 URL은 아직 공개 tap용 URL이 아닙니다.
향후 사용자가 정식 게시한 뒤 버전별 고정 Release asset URL과 SHA-256으로 별도 homebrew-taps PR을 준비합니다. Actions artifact URL은 cask에 사용하지 않습니다.
기존 1.0.1 태그 및 Release asset은 보존합니다.
'''


def create(api, directory, version, commit, info, run_url):
    validate_artifacts(directory, version, commit, info, run_url)
    ensure_no_visible_conflict(api, version)  # Write token sees drafts; recheck before any mutation.
    release = api.request('releases', data={'tag_name': version, 'target_commitish': commit,
                         'name': f'BrowserOpener {version}', 'draft': True, 'prerelease': False,
                         'body': release_body(version, commit, run_url)})
    check_draft(release, version, commit)
    release_id = release['id']
    print(f"Draft created: {release['html_url']}")
    for name in asset_names(version):
        current = api.request(f'releases/{release_id}')
        check_draft(current, version, commit)
        require(not any(a['name'] == name for a in current['assets']), f'Asset already exists: {name}')
        api.request(f'releases/{release_id}/assets?name={urllib.parse.quote(name)}', upload=directory / name)
    current = api.request(f'releases/{release_id}')
    check_draft(current, version, commit)
    require(sorted(a['name'] for a in current['assets']) == sorted(asset_names(version)), 'Unexpected release assets')
    return current


def download(api, release_id, directory, version, commit, info, run_url):
    release = api.request(f'releases/{release_id}')
    check_draft(release, version, commit)
    require(sorted(a['name'] for a in release['assets']) == sorted(asset_names(version)), 'Incomplete or unexpected release assets')
    directory.mkdir(parents=True, exist_ok=False)
    for asset in release['assets']:
        require(asset['state'] == 'uploaded', 'Asset upload is incomplete')
        data = api.request(f"releases/assets/{asset['id']}", binary=True)
        require(len(data) == asset['size'], 'Asset download size mismatch')
        (directory / asset['name']).write_bytes(data)
    validate_artifacts(directory, version, commit, info, run_url)
    check_draft(api.request(f'releases/{release_id}'), version, commit)
    receipt = {key: release[key] for key in ('id', 'tag_name', 'target_commitish',
                                            'draft', 'prerelease', 'html_url')}
    receipt['run_url'] = run_url
    receipt['assets'] = [{'id': asset['id'], 'name': asset['name'],
                         'sha256': hashlib.sha256((directory / asset['name']).read_bytes()).hexdigest()}
                        for asset in release['assets']]
    # Written only after actual API downloads, hash/provenance checks and a final draft check.
    (directory / 'release-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return release


def verify_download(directory, release_id, version, commit, info, run_url):
    """Validate the write job's transfer offline; this needs no Draft API token."""
    require(sorted(p.name for p in directory.iterdir()) == sorted((*asset_names(version), 'release-receipt.json')),
            'Missing or unexpected files in the Release download artifact')
    receipt = json.loads((directory / 'release-receipt.json').read_text())
    check_draft(receipt, version, commit)
    require(receipt['id'] == release_id, 'Release receipt ID mismatch')
    require(receipt['run_url'] == run_url, 'Release receipt run mismatch')
    require(sorted(a['name'] for a in receipt['assets']) == sorted(asset_names(version)),
            'Unexpected assets in Release receipt')
    ids = [a['id'] for a in receipt['assets']]
    require(all(type(i) is int and i > 0 for i in ids) and len(set(ids)) == len(ids),
            'Invalid Release asset IDs')
    for asset in receipt['assets']:
        digest = hashlib.sha256((directory / asset['name']).read_bytes()).hexdigest()
        require(digest == asset['sha256'], f"Release receipt hash mismatch: {asset['name']}")
    validate_artifacts(directory, version, commit, info, run_url)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['preflight', 'create', 'download', 'verify-download'])
    parser.add_argument('--directory', type=Path)
    args = parser.parse_args()
    version, commit, info, run_url = context()
    if args.command == 'verify-download':
        require(args.directory is not None, '--directory is required')
        receipt = verify_download(args.directory, int(os.environ['RELEASE_ID']), version, commit, info, run_url)
        print(f"Verified transferred bytes from Release {receipt['id']} without Draft API access.")
        return
    api = GitHub(os.environ['GITHUB_REPOSITORY'], os.environ['GH_TOKEN'])
    if args.command == 'preflight':
        ensure_no_visible_conflict(api, version)
        print(f'No visible conflict for {version}, exact main commit {commit}; no mutations performed. '
              'Read-only access may hide drafts. The write job must recheck all drafts before creation.')
        return
    require(args.directory is not None, '--directory is required')
    if args.command == 'create':
        release = create(api, args.directory, version, commit, info, run_url)
        with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
            stream.write(f"release-id={release['id']}\n")
    else:
        release = download(api, int(os.environ['RELEASE_ID']), args.directory, version, commit, info, run_url)
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
        stream.write(f"[Unpublished Draft Release {version}]({release['html_url']})\n\nTarget: `{commit}`\n")


if __name__ == '__main__':
    main()
