"""Exercise release collision and provenance checks without credentials or API writes."""
import copy
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import shutil
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('draft_release', Path(__file__).parents[1] / 'draft-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
COMMIT = 'a' * 40
VERSION = '1.0.2'
RUN = 'https://github.com/blood72/BrowserOpener/actions/runs/123'
INFO = {'CFBundleVersion': '2'}


class FakeAPI:
    def __init__(self):
        self.releases = []
        self.tag = None
        self.writes = []
        self.blobs = {}
        self.publish_after_create = False
        self.hide_drafts = False
        self.downloads = []

    def request(self, path, **kwargs):
        data, upload = kwargs.get('data'), kwargs.get('upload')
        if data is not None:
            self.writes.append(('create', copy.deepcopy(data)))
            item = dict(data, id=1, html_url='https://github.com/example/draft', assets=[])
            self.releases.append(item)
            result = copy.deepcopy(item)
            if self.publish_after_create:
                item['draft'] = False
            return result
        if upload is not None:
            name = upload.name
            self.writes.append(('upload', name))
            asset_id = len(self.blobs) + 1
            self.blobs[asset_id] = upload.read_bytes()
            self.releases[0]['assets'].append({'id': asset_id, 'name': name,
                                             'size': upload.stat().st_size, 'state': 'uploaded'})
            return {}
        if path.startswith('releases?'):
            return copy.deepcopy([r for r in self.releases if not (self.hide_drafts and r['draft'])])
        if path.startswith('git/ref/'):
            return self.tag
        if path.startswith('releases/assets/'):
            self.downloads.append(int(path.rsplit('/', 1)[1]))
            return self.blobs[int(path.rsplit('/', 1)[1])]
        if path == 'releases/1':
            return copy.deepcopy(self.releases[0])
        raise AssertionError(path)


class DraftReleaseTests(unittest.TestCase):
    def setUp(self):
        output = contextlib.redirect_stdout(io.StringIO())
        output.__enter__()
        self.addCleanup(output.__exit__, None, None, None)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / 'artifact'
        self.directory.mkdir()
        self.api = FakeAPI()
        dmg = self.directory / 'BrowserOpener-1.0.2.dmg'
        dmg.write_bytes(b'dmg fixture; native DMG validation runs separately on macOS')
        digest = hashlib.sha256(dmg.read_bytes()).hexdigest()
        (self.directory / 'SHA256SUMS').write_text(f'{digest}  {dmg.name}\n')
        self.metadata = {'source_commit': COMMIT, 'event_head_commit': COMMIT,
                         'app_version': VERSION, 'bundle_version': '2', 'architecture': 'arm64',
                         'minimum_macos': '13.0', 'notarized': False,
                         'signature': 'ad-hoc (no Developer ID certificate)', 'run_url': RUN}
        self.write_metadata()

    def write_metadata(self):
        (self.directory / 'build-info.json').write_text(json.dumps(self.metadata))

    def create(self):
        return release.create(self.api, self.directory, VERSION, COMMIT, INFO, RUN)

    def test_valid_create_is_draft_only_and_repeated_version_never_writes(self):
        item = self.create()
        self.assertTrue(item['draft'])
        self.assertFalse(item['prerelease'])
        self.assertEqual(item['target_commitish'], COMMIT)
        self.assertEqual(item['tag_name'], VERSION)
        self.assertEqual(len(item['assets']), 3)
        writes = copy.deepcopy(self.api.writes)
        with self.assertRaisesRegex(ValueError, 'already has release'):
            self.create()
        self.assertEqual(self.api.writes, writes)

    def test_existing_tag_even_same_commit_blocks_creation(self):
        self.api.tag = {'object': {'sha': COMMIT}}
        with self.assertRaisesRegex(ValueError, 'Tag .* already exists'):
            self.create()
        self.assertEqual(self.api.writes, [])

    def test_prior_release_is_preserved_by_preflight(self):
        prior = {'id': 99, 'tag_name': '1.0.1', 'draft': False,
                 'target_commitish': 'main', 'assets': [{'name': 'BrowserOpener-1.0.1.dmg'}]}
        self.api.releases = [copy.deepcopy(prior)]
        release.ensure_no_visible_conflict(self.api, VERSION)
        self.assertEqual(self.api.releases, [prior])
        self.assertEqual(self.api.writes, [])

    def test_read_only_preflight_may_hide_draft_but_writer_recheck_blocks(self):
        self.api.releases = [{'id': 1, 'tag_name': VERSION, 'draft': True,
                              'target_commitish': COMMIT, 'assets': []}]
        self.api.hide_drafts = True
        release.ensure_no_visible_conflict(self.api, VERSION)
        self.api.hide_drafts = False
        with self.assertRaisesRegex(ValueError, 'already has release'):
            self.create()
        self.assertEqual(self.api.writes, [])

    def test_existing_public_draft_partial_and_other_commit_all_block(self):
        for draft, commit in [(False, COMMIT), (True, COMMIT), (True, 'b' * 40)]:
            with self.subTest(draft=draft, commit=commit):
                self.api.releases = [{'id': 1, 'tag_name': VERSION, 'draft': draft,
                                      'target_commitish': commit, 'assets': []}]
                with self.assertRaisesRegex(ValueError, 'already has release'):
                    self.create()
                self.assertEqual(self.api.writes, [])

    def test_bad_checksum_prevents_any_release_write(self):
        (self.directory / 'BrowserOpener-1.0.2.dmg').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'SHA256SUMS mismatch'):
            self.create()
        self.assertEqual(self.api.writes, [])

    def test_wrong_source_version_architecture_and_run_are_rejected(self):
        for key, value in [('source_commit', 'b' * 40), ('event_head_commit', 'b' * 40),
                           ('app_version', '1.0.1'), ('bundle_version', '1'),
                           ('architecture', 'x86_64'), ('run_url', RUN + '4')]:
            with self.subTest(key=key):
                original = self.metadata[key]
                self.metadata[key] = value
                self.write_metadata()
                with self.assertRaisesRegex(ValueError, 'provenance mismatch'):
                    self.create()
                self.assertEqual(self.api.writes, [])
                self.metadata[key] = original

    def test_publication_during_upload_stops_writes(self):
        self.api.publish_after_create = True
        with self.assertRaisesRegex(ValueError, 'Release is public'):
            self.create()
        self.assertEqual([kind for kind, _ in self.api.writes], ['create'])

    def test_download_checks_actual_asset_bytes_without_writes(self):
        self.create()
        writes = copy.deepcopy(self.api.writes)
        destination = Path(self.temp.name) / 'download'
        release.download(self.api, 1, destination, VERSION, COMMIT, INFO, RUN)
        for name in release.asset_names(VERSION):
            self.assertEqual((destination / name).read_bytes(), (self.directory / name).read_bytes())
        self.assertEqual(self.api.writes, writes)
        self.api.blobs[1] = b'x' * len(self.api.blobs[1])
        with self.assertRaisesRegex(ValueError, 'SHA256SUMS mismatch'):
            release.download(self.api, 1, Path(self.temp.name) / 'corrupt', VERSION, COMMIT, INFO, RUN)
        self.assertEqual(self.api.writes, writes)

    def test_incomplete_release_download_is_rejected(self):
        self.create()
        self.api.releases[0]['assets'].pop()
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            release.download(self.api, 1, Path(self.temp.name) / 'missing', VERSION, COMMIT, INFO, RUN)

    def download_release(self):
        self.create()
        destination = Path(self.temp.name) / 'transfer'
        release.download(self.api, 1, destination, VERSION, COMMIT, INFO, RUN)
        return destination

    def test_transfer_uses_release_bytes_even_without_original_build_artifact(self):
        self.create()
        shutil.rmtree(self.directory)
        destination = Path(self.temp.name) / 'release-only'
        release.download(self.api, 1, destination, VERSION, COMMIT, INFO, RUN)
        self.assertEqual(self.api.downloads, [1, 2, 3])
        receipt = release.verify_download(destination, 1, VERSION, COMMIT, INFO, RUN)
        self.assertEqual([a['id'] for a in receipt['assets']], self.api.downloads)

    def test_initial_build_artifact_cannot_replace_release_transfer(self):
        with self.assertRaisesRegex(ValueError, 'Missing or unexpected files'):
            release.verify_download(self.directory, 1, VERSION, COMMIT, INFO, RUN)

    def test_offline_transfer_verification_needs_no_token_or_api(self):
        destination = self.download_release()
        environment = dict(os.environ)
        environment.pop('GH_TOKEN', None)
        environment['RELEASE_ID'] = '1'
        with patch.dict(os.environ, environment, clear=True), \
                patch.object(release, 'context', return_value=(VERSION, COMMIT, INFO, RUN)), \
                patch.object(release, 'GitHub', side_effect=AssertionError('No API access allowed')), \
                patch('sys.argv', ['draft-release.py', 'verify-download', '--directory', str(destination)]):
            release.main()

    def test_wrong_release_run_or_file_hash_in_receipt_is_rejected(self):
        destination = self.download_release()
        receipt_path = destination / 'release-receipt.json'
        original = json.loads(receipt_path.read_text())
        for key, value, message in [('id', 2, 'ID mismatch'), ('run_url', RUN + '4', 'run mismatch')]:
            with self.subTest(key=key):
                receipt = copy.deepcopy(original)
                receipt[key] = value
                receipt_path.write_text(json.dumps(receipt))
                with self.assertRaisesRegex(ValueError, message):
                    release.verify_download(destination, 1, VERSION, COMMIT, INFO, RUN)
        receipt_path.write_text(json.dumps(original))
        (destination / 'BrowserOpener-1.0.2.dmg').write_bytes(b'replaced')
        with self.assertRaisesRegex(ValueError, 'receipt hash mismatch'):
            release.verify_download(destination, 1, VERSION, COMMIT, INFO, RUN)

    def test_dispatch_requires_main_and_exact_sha(self):
        environment = {'RELEASE_VERSION': VERSION, 'TARGET_COMMIT': COMMIT,
                       'GITHUB_REPOSITORY': 'blood72/BrowserOpener', 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                       'GITHUB_REF': 'refs/heads/main', 'GITHUB_SHA': COMMIT, 'GITHUB_RUN_ID': '123'}
        with patch.dict(os.environ, environment), patch.object(
                release.plistlib, 'load', return_value={'CFBundleShortVersionString': VERSION}):
            self.assertEqual(release.context()[0:2], (VERSION, COMMIT))
            with patch.dict(os.environ, {'GITHUB_REF': 'refs/heads/feature'}):
                with self.assertRaisesRegex(ValueError, 'main only'):
                    release.context()
            with patch.dict(os.environ, {'GITHUB_SHA': 'b' * 40}):
                with self.assertRaisesRegex(ValueError, 'Target must equal'):
                    release.context()


if __name__ == '__main__':
    unittest.main()
