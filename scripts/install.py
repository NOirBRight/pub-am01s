#!/usr/bin/env python3
"""Install the pub-am01s plugin and Hyprland snippet under the XDG config home."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

PLUGIN_ID = "noirbright.pub-am01s"
PLUGIN_ENTRY = {"id": PLUGIN_ID}
REQUIRE_LINE = 'require("hypr.am01s")'
SETUP_PUB_KEY = "setup.pub"
SETUP_PUB_ENTRY = {
    "icon": "󰔡",
    "label": "PUB 设置",
    "action": (
        'mkdir -p "${XDG_RUNTIME_DIR:-$HOME/.cache}/pub-am01s" && '
        'touch "${XDG_RUNTIME_DIR:-$HOME/.cache}/pub-am01s/open-settings"'
    ),
}
DESCRIPTION = "ChangHong Electric Co.Ltd 0x0030"
REPO_ROOT = Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    raise SystemExit(message)


def config_home() -> Path:
    configured = os.environ.get("XDG_CONFIG_HOME")
    if configured:
        return Path(configured)
    home = os.environ.get("HOME")
    if not home:
        fail("HOME is not set")
    return Path(home) / ".config"


def resolved_without_leaf_symlink(path: Path) -> Path:
    # A symlink we are about to write may point at this repo. That target is
    # outside the config home on purpose; only the directory entry must stay inside.
    if path.is_symlink():
        return path.parent.resolve() / path.name
    cursor = path
    tail: list[str] = []
    while not cursor.exists() and cursor != cursor.parent:
        tail.append(cursor.name)
        cursor = cursor.parent
    base = cursor.resolve()
    for name in reversed(tail):
        base = base / name
    return base


def assert_inside(root: Path, path: Path, *, follow_leaf: bool) -> None:
    root_resolved = root.resolve()
    destination = path.resolve() if follow_leaf else resolved_without_leaf_symlink(path)
    if destination != root_resolved and root_resolved not in destination.parents:
        fail(f"refusing to touch {path}: it is outside {root_resolved}")


def ensure_symlink(link: Path, target: Path, root: Path) -> None:
    if not target.exists():
        fail(f"missing install target {target}")
    assert_inside(root, link, follow_leaf=False)
    link.parent.mkdir(parents=True, exist_ok=True)
    wanted = target.resolve()
    if link.is_symlink():
        if link.resolve() == wanted:
            return
        fail(f"{link} already exists and points at {link.resolve()}, not {wanted}")
    if link.exists():
        fail(f"{link} already exists and is not a symlink to {wanted}")
    link.symlink_to(wanted)


def qml_round(value: float) -> int:
    if value >= 0:
        return int(value + 0.5)
    return int(value - 0.5)


def as_number(value: object) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def mode_is_panel(monitor: dict) -> bool:
    width = as_number(monitor.get("width"))
    height = as_number(monitor.get("height"))
    if width is None or height is None:
        return False
    if width == 960 and height == 400:
        return True
    scale = as_number(monitor.get("scale"))
    if scale is None or scale <= 0:
        return False
    return qml_round(width * scale) == 960 and qml_round(height * scale) == 400


def connector_from_monitors(monitors: object) -> str | None:
    if not isinstance(monitors, list):
        return None
    for monitor in monitors:
        if not isinstance(monitor, dict):
            continue
        description = str(monitor.get("description") or "")
        if DESCRIPTION not in description or not mode_is_panel(monitor):
            continue
        name = monitor.get("name")
        if isinstance(name, str) and name:
            return name
    return None


def output_from_hyprctl() -> str | None:
    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        return None
    try:
        completed = subprocess.run(
            [hyprctl, "monitors", "-j"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if completed.returncode != 0:
        return None
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None
    return connector_from_monitors(payload)


def parse_output(argv: list[str]) -> str | None:
    output = None
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--output":
            index += 1
            if index >= len(argv) or not argv[index]:
                fail("--output requires a name")
            output = argv[index]
        elif arg.startswith("--output="):
            output = arg.split("=", 1)[1]
            if not output:
                fail("--output requires a name")
        else:
            fail(f"unknown argument: {arg}")
        index += 1
    return output


def resolve_output(argv_output: str | None) -> str | None:
    if argv_output:
        return argv_output
    from_env = os.environ.get("PUB_AM01S_OUTPUT")
    if from_env:
        return from_env
    return output_from_hyprctl()


def install_shell_json(root: Path) -> None:
    path = root / "omarchy" / "shell.json"
    assert_inside(root, path, follow_leaf=True)
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail(f"{path} is not valid JSON: {exc}")
        if not isinstance(data, dict):
            fail(f"{path} must be a JSON object")
    else:
        data = {}
    plugins = data.get("plugins", [])
    if plugins is None:
        plugins = []
    if not isinstance(plugins, list):
        fail(f"{path} plugins is not an array")
    kept: list[object] = []
    placed = False
    for entry in plugins:
        if isinstance(entry, dict) and entry.get("id") == PLUGIN_ID:
            if not placed:
                kept.append(dict(PLUGIN_ENTRY))
                placed = True
            continue
        kept.append(entry)
    if not placed:
        kept.append(dict(PLUGIN_ENTRY))
    data["plugins"] = kept
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def install_hypr_require(root: Path) -> None:
    path = root / "hypr" / "hyprland.lua"
    assert_inside(root, path, follow_leaf=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    if REQUIRE_LINE in text.splitlines():
        return
    if text and not text.endswith("\n"):
        text += "\n"
    text += REQUIRE_LINE + "\n"
    path.write_text(text, encoding="utf-8")


def strip_jsonc(text: str) -> str:
    # Omarchy menu files allow // comments, block comments, and trailing commas.
    if text.startswith("\ufeff"):
        text = text[1:]
    out: list[str] = []
    index = 0
    length = len(text)
    in_string = False
    escape = False
    while index < length:
        char = text[index]
        if in_string:
            out.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            index += 1
            continue
        if char == "/" and index + 1 < length and text[index + 1] == "/":
            index += 2
            while index < length and text[index] not in "\r\n":
                index += 1
            continue
        if char == "/" and index + 1 < length and text[index + 1] == "*":
            index += 2
            while index + 1 < length and not (text[index] == "*" and text[index + 1] == "/"):
                index += 1
            index = min(length, index + 2)
            continue
        out.append(char)
        index += 1
    raw = "".join(out)
    cleaned: list[str] = []
    index = 0
    length = len(raw)
    in_string = False
    escape = False
    while index < length:
        char = raw[index]
        if in_string:
            cleaned.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            cleaned.append(char)
            index += 1
            continue
        if char == ",":
            look = index + 1
            while look < length and raw[look] in " \t\r\n":
                look += 1
            if look < length and raw[look] in "}]":
                index += 1
                continue
        cleaned.append(char)
        index += 1
    return "".join(cleaned)


def load_menu(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    raw = path.read_text(encoding="utf-8")
    if not raw.strip():
        return {}
    try:
        data = json.loads(strip_jsonc(raw))
    except json.JSONDecodeError as exc:
        fail(f"{path} is not valid JSON: {exc}")
    if not isinstance(data, dict):
        fail(f"{path} must be a JSON object")
    return data


def install_menu(root: Path) -> None:
    path = root / "omarchy" / "extensions" / "omarchy-menu.jsonc"
    assert_inside(root, path, follow_leaf=True)
    data = load_menu(path)
    data[SETUP_PUB_KEY] = dict(SETUP_PUB_ENTRY)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def install_output(root: Path, name: str | None) -> None:
    if not name:
        return
    path = root / "hypr" / "am01s-output"
    assert_inside(root, path, follow_leaf=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(name + "\n", encoding="utf-8")


def main(argv: list[str]) -> None:
    root = config_home()
    assert_inside(root, root, follow_leaf=True)
    root.mkdir(parents=True, exist_ok=True)
    ensure_symlink(root / "omarchy" / "plugins" / PLUGIN_ID, REPO_ROOT / "plugin", root)
    install_shell_json(root)
    install_menu(root)
    ensure_symlink(root / "hypr" / "am01s.lua", REPO_ROOT / "hypr" / "am01s.lua", root)
    install_hypr_require(root)
    install_output(root, resolve_output(parse_output(argv)))


if __name__ == "__main__":
    main(sys.argv[1:])
