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


class InstallTest(unittest.TestCase):
    def test_twice_leaves_one_of_each(self):
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


if __name__ == "__main__":
    unittest.main()
