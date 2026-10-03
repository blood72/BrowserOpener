#!/usr/bin/env python3
"""Record the exact source and Apple toolchain used by the packaging job."""
import json
import os
import pathlib
import plistlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent


def command(*args):
    return subprocess.check_output(args, cwd=root, text=True).strip()


with (root / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)

metadata = {
    "source_commit": command("git", "rev-parse", "HEAD"),
    "event_head_commit": os.environ["EVENT_HEAD_SHA"],
    "run_url": f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}"
               f"/actions/runs/{os.environ['GITHUB_RUN_ID']}",
    "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
    "app_version": info["CFBundleShortVersionString"],
    "bundle_version": info["CFBundleVersion"],
    "minimum_macos": info["LSMinimumSystemVersion"],
    "architecture": command("uname", "-m"),
    "signature": "ad-hoc (no Developer ID certificate)",
    "notarized": False,
    "xcode": command("xcodebuild", "-version"),
    "swift": command("swift", "--version"),
    "sdk": command("xcrun", "--sdk", "macosx", "--show-sdk-version"),
    "host_macos": command("sw_vers"),
    "runner_image": os.environ.get("ImageVersion"),
}
(root / "dist/build-info.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps(metadata, indent=2))
