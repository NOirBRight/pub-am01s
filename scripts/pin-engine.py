#!/usr/bin/env python3
"""Download the PUB engine named by engine.tag into plugin/bin."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TAG_PATH = REPO_ROOT / "engine.tag"
DEST = REPO_ROOT / "plugin" / "bin" / "pub-engine.mjs"
ASSET_URL = "https://github.com/NOirBRight/plan-usage-bar/releases/download/{tag}/pub-engine.mjs"


def fail(message: str) -> None:
    raise SystemExit(message)


def read_tag() -> str:
    if not TAG_PATH.is_file():
        fail(f"missing {TAG_PATH.name}")
    tag = TAG_PATH.read_text(encoding="utf-8").strip()
    if not tag or any(char.isspace() for char in tag) or "/" in tag or "\\" in tag:
        fail(f"{TAG_PATH.name} must contain a release tag")
    return tag


def parse_url(argv: list[str]) -> str | None:
    url = None
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--url":
            index += 1
            if index >= len(argv) or not argv[index]:
                fail("--url requires a value")
            url = argv[index]
        elif arg.startswith("--url="):
            url = arg.split("=", 1)[1]
            if not url:
                fail("--url requires a value")
        else:
            fail(f"unknown argument: {arg}")
        index += 1
    return url


def resolve_url(argv_url: str | None, tag: str) -> str:
    if argv_url:
        return argv_url
    from_env = os.environ.get("PUB_ENGINE_URL", "").strip()
    if from_env:
        return from_env
    return ASSET_URL.format(tag=tag)


def local_source(url: str) -> Path | None:
    if url.startswith("file:"):
        parsed = urllib.parse.urlparse(url)
        return Path(urllib.request.url2pathname(parsed.path))
    if "://" in url:
        return None
    return Path(url)


def write_asset(url: str, dest: Path) -> None:
    source = local_source(url)
    if source is not None:
        if not source.is_file():
            fail(f"missing engine asset {url}")
        shutil.copyfile(source, dest)
        return
    request = urllib.request.Request(url, headers={"User-Agent": "pub-am01s-pin-engine"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response, dest.open("wb") as handle:
            shutil.copyfileobj(response, handle)
    except urllib.error.HTTPError as exc:
        fail(f"could not download {url}: HTTP {exc.code}")
    except urllib.error.URLError as exc:
        fail(f"could not download {url}: {exc.reason}")
    except OSError as exc:
        fail(f"could not download {url}: {exc}")


def query_version(path: Path) -> None:
    try:
        completed = subprocess.run(
            ["node", str(path), "--version"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError:
        fail("engine version query failed: node is not installed")
    except subprocess.TimeoutExpired:
        fail("engine version query failed: timed out")
    except OSError as exc:
        fail(f"engine version query failed: {exc}")
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "").strip()
        if len(detail) > 400:
            detail = detail[:400]
        fail(f"engine version query failed: {detail or completed.returncode}")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        fail(f"engine version query returned invalid JSON: {exc}")
    if not isinstance(payload, dict) or not isinstance(payload.get("version"), str) or not payload["version"]:
        fail("engine version query must include a version string")
    schema = payload.get("schemaVersion")
    if isinstance(schema, bool) or not isinstance(schema, int):
        fail("engine version query must include an integer schemaVersion")


def pin(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Node only loads this check as ESM when the path still ends in .mjs.
    partial = dest.with_name(dest.stem + ".partial.mjs")
    try:
        write_asset(url, partial)
        query_version(partial)
        partial.replace(dest)
    finally:
        if partial.exists():
            partial.unlink()


def main(argv: list[str]) -> None:
    tag = read_tag()
    pin(resolve_url(parse_url(argv), tag), DEST)


if __name__ == "__main__":
    main(sys.argv[1:])
