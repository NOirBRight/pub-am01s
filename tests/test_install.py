"""Install script is idempotent inside a temporary config home."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "install.py"
PLUGIN_ID = "noirbright.pub-am01s"
REQUIRE_LINE = 'require("hypr.am01s")'
EXPECTED_MENU = {
    "icon": "󰔡",
    "label": "PUB 设置",
    "action": (
        'mkdir -p "${XDG_RUNTIME_DIR:-$HOME/.cache}/pub-am01s" && '
        'touch "${XDG_RUNTIME_DIR:-$HOME/.cache}/pub-am01s/open-settings"'
    ),
}


def real_menu_stamp() -> tuple[Path, tuple[int, int] | None]:
    configured = os.environ.get("XDG_CONFIG_HOME")
    root = Path(configured) if configured else Path.home() / ".config"
    path = root / "omarchy" / "extensions" / "omarchy-menu.jsonc"
    if not path.exists():
        return path, None
    stat = path.stat()
    return path, (stat.st_mtime_ns, stat.st_size)


class InstallTest(unittest.TestCase):
    def test_twice_leaves_one_of_each(self):
        real_path, real_before = real_menu_stamp()
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home = base / "home"
            home.mkdir()
            config = base / "xdg"
            (config / "hypr").mkdir(parents=True)
            (config / "omarchy").mkdir(parents=True)
            hyprland = config / "hypr" / "hyprland.lua"
            hyprland.write_text("-- user config\nhl.monitor({ name = \"DP-1\" })\n", encoding="utf-8")
            shell = config / "omarchy" / "shell.json"
            shell.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "bar": {"position": "top"},
                        "plugins": [{"id": "omarchy.example", "enabled": True}],
                    }
                ),
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["XDG_CONFIG_HOME"] = str(config)
            env.pop("PUB_AM01S_OUTPUT", None)

            for _ in range(2):
                completed = subprocess.run(
                    [sys.executable, str(SCRIPT), "--output", "HDMI-A-3"],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

            text = hyprland.read_text(encoding="utf-8")
            self.assertIn("-- user config", text)
            self.assertEqual(text.splitlines().count(REQUIRE_LINE), 1)

            plugin = config / "omarchy" / "plugins" / PLUGIN_ID
            self.assertTrue(plugin.is_symlink(), plugin)
            self.assertEqual(plugin.resolve(), (ROOT / "plugin").resolve())

            lua = config / "hypr" / "am01s.lua"
            self.assertTrue(lua.is_symlink(), lua)
            self.assertEqual(lua.resolve(), (ROOT / "hypr" / "am01s.lua").resolve())

            data = json.loads(shell.read_text(encoding="utf-8"))
            self.assertEqual(data["version"], 1)
            self.assertEqual(data["bar"], {"position": "top"})
            ours = [
                entry for entry in data["plugins"]
                if isinstance(entry, dict) and entry.get("id") == PLUGIN_ID
            ]
            self.assertEqual(ours, [{"id": PLUGIN_ID}])
            self.assertTrue(
                any(
                    isinstance(entry, dict) and entry.get("id") == "omarchy.example"
                    for entry in data["plugins"]
                )
            )

            output = (config / "hypr" / "am01s-output").read_text(encoding="utf-8")
            self.assertIn("HDMI-A-3", output)
            outside = [path for path in home.rglob("*")]
            self.assertEqual(outside, [])

            menu = config / "omarchy" / "extensions" / "omarchy-menu.jsonc"
            menu_text = menu.read_text(encoding="utf-8")
            menu_data = json.loads(menu_text)
            self.assertEqual(list(menu_data), ["setup.pub"])
            self.assertEqual(menu_data["setup.pub"], EXPECTED_MENU)
            self.assertEqual(menu_text.count('"setup.pub"'), 1)
        real_after_path, real_after = real_menu_stamp()
        self.assertEqual(real_after_path, real_path)
        self.assertEqual(real_after, real_before)

    def test_menu_keeps_other_keys_and_one_setup_pub(self):
        real_path, real_before = real_menu_stamp()
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home = base / "home"
            home.mkdir()
            config = base / "xdg"
            menu = config / "omarchy" / "extensions" / "omarchy-menu.jsonc"
            menu.parent.mkdir(parents=True)
            menu.write_text(
                """
{
  // existing entries
  /* block */
  "setup.audio": {"icon": "x", "label": "keep // inside", "action": "echo ok", "aliases": ["a", "b"],},
  "setup.pub": {"icon": "old", "label": "旧", "action": "old"},
  "setup.pub": {"icon": "older", "label": "更旧", "action": "older"},
}
""".strip()
                + "\n",
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["XDG_CONFIG_HOME"] = str(config)
            env.pop("PUB_AM01S_OUTPUT", None)
            for _ in range(2):
                completed = subprocess.run(
                    [sys.executable, str(SCRIPT)],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

            data = json.loads(menu.read_text(encoding="utf-8"))
            self.assertEqual(menu.read_text(encoding="utf-8").count('"setup.pub"'), 1)
            self.assertEqual(data["setup.pub"], EXPECTED_MENU)
            self.assertEqual(
                data["setup.audio"],
                {"icon": "x", "label": "keep // inside", "action": "echo ok", "aliases": ["a", "b"]},
            )
            self.assertEqual([path for path in home.rglob("*")], [])
        real_after_path, real_after = real_menu_stamp()
        self.assertEqual(real_after_path, real_path)
        self.assertEqual(real_after, real_before)


if __name__ == "__main__":
    unittest.main()
