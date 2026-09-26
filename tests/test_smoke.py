"""Load Service.qml under quickshell without leaving a process behind."""

import json
import os
import shutil
import signal
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "plugin" / "Service.qml"
COMMONS = Path("/usr/share/omarchy/shell/Commons")
ORIGINAL_RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "")
PLATFORM_FAILURES = (
    "could not load the qt platform plugin",
    "could not find the qt platform plugin",
    "qt.qpa.plugin",
    "failed to create platform",
)


def wayland_socket_exists() -> bool:
    if not ORIGINAL_RUNTIME:
        return False
    root = Path(ORIGINAL_RUNTIME)
    if not root.is_dir():
        return False
    display = os.environ.get("WAYLAND_DISPLAY")
    if display:
        candidate = root / display
        if candidate.exists() and not candidate.name.endswith(".lock"):
            return True
    for path in root.iterdir():
        if path.name.startswith("wayland-") and not path.name.endswith(".lock"):
            return True
    return False


def qml_problems(text: str) -> list[str]:
    problems = []
    for line in text.splitlines():
        stripped = line.strip()
        lower = stripped.lower()
        if (
            stripped.startswith("ERROR:")
            or "ERROR qml:" in stripped
            or "referenceerror" in lower
            or "typeerror" in lower
            or "syntaxerror" in lower
            or "is not a type" in lower
        ):
            problems.append(stripped)
    return problems


def platform_failed(text: str) -> bool:
    lowered = text.lower()
    return any(marker in lowered for marker in PLATFORM_FAILURES)


def run_quickshell(env: dict, harness: Path, timeout: float = 15) -> subprocess.CompletedProcess:
    proc = subprocess.Popen(
        ["quickshell", "--no-color", "-p", str(harness)],
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGTERM)
        try:
            stdout, stderr = proc.communicate(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            stdout, stderr = proc.communicate()
        raise AssertionError(
            "quickshell timed out\n" + (stdout or "") + (stderr or "")
        ) from None
    return subprocess.CompletedProcess(proc.args, proc.returncode, stdout, stderr)


@unittest.skipUnless(shutil.which("quickshell"), "requires Quickshell")
class ServiceSmokeTest(unittest.TestCase):
    def test_service_loads(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            home = base / "home"
            runtime = base / "runtime"
            config = base / "config"
            for path in (home, runtime, config, base / "state", base / "cache"):
                path.mkdir()
            runtime.chmod(0o700)
            if COMMONS.is_dir():
                (config / "Commons").symlink_to(COMMONS)
            harness = config / "shell.qml"
            harness.write_text(
                """
import QtQuick
import Quickshell
ShellRoot {
  Component.onCompleted: {
    var component = Qt.createComponent(%s)
    function instantiate() {
      if (component.status === Component.Error) {
        console.error(component.errorString())
        return
      }
      if (component.status !== Component.Ready) return
      var obj = component.createObject(null)
      if (!obj) console.error("Service.qml createObject returned null")
    }
    if (component.status === Component.Ready || component.status === Component.Error)
      instantiate()
    else
      component.statusChanged.connect(instantiate)
  }
  Timer {
    interval: 800
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }
}
""".strip()
                % json.dumps(SERVICE.as_uri()),
                encoding="utf-8",
            )
            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "XDG_CONFIG_HOME": str(home / ".config"),
                    "XDG_STATE_HOME": str(base / "state"),
                    "XDG_CACHE_HOME": str(base / "cache"),
                    "XDG_RUNTIME_DIR": str(runtime),
                    "QT_QPA_PLATFORM": "offscreen",
                    "QT_QPA_PLATFORMTHEME": "",
                    "QT_STYLE_OVERRIDE": "Basic",
                }
            )
            result = run_quickshell(env, harness)
            combined = (result.stdout or "") + (result.stderr or "")
            if platform_failed(combined):
                if not wayland_socket_exists():
                    self.skipTest("offscreen Quickshell failed to start and no wayland socket is available")
                fallback = os.environ.copy()
                fallback.update(
                    {
                        "HOME": str(home),
                        "XDG_CONFIG_HOME": str(home / ".config"),
                        "XDG_STATE_HOME": str(base / "state"),
                        "XDG_CACHE_HOME": str(base / "cache"),
                        "QT_QPA_PLATFORMTHEME": "",
                        "QT_STYLE_OVERRIDE": "Basic",
                    }
                )
                fallback.pop("QT_QPA_PLATFORM", None)
                result = run_quickshell(fallback, harness)
                combined = (result.stdout or "") + (result.stderr or "")
            problems = qml_problems(result.stderr or "") + qml_problems(result.stdout or "")
            self.assertEqual(result.returncode, 0, combined)
            self.assertEqual(problems, [], combined)


if __name__ == "__main__":
    unittest.main()
