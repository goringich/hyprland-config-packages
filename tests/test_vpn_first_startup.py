#!/usr/bin/env python3
"""Unit tests for the VPN-first desktop startup gate."""

import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "hypr/UserScripts/VpnFirstStartup.sh"


class VpnFirstStartupTests(unittest.TestCase):
  def run_startup(self, proxy_ready=True, proxy_port="12334", timeout="0", saved_browser_command=None):
    with tempfile.TemporaryDirectory() as tmp:
      root = pathlib.Path(tmp)
      home = root / "home"
      binary_dir = root / "bin"
      binary_dir.mkdir()
      (home / ".local/bin").mkdir(parents=True)
      (home / ".local/bin/google-chrome-stable").write_text("#!/bin/sh\nexit 0\n")
      (home / ".local/bin/google-chrome-stable").chmod(0o755)
      if saved_browser_command is not None:
        config_dir = home / ".config/hypr/UserConfigs"
        config_dir.mkdir(parents=True)
        (config_dir / "VpnFirstBrowserCommand").write_text(saved_browser_command + "\n")

      for name, content in {
        "hiddify": "#!/bin/sh\nexit 0\n",
        "hyprctl": '#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_LAUNCH_LOG"\n',
        "curl": "#!/bin/sh\nexit \"$TEST_CURL_EXIT\"\n",
      }.items():
        path = binary_dir / name
        path.write_text(content)
        path.chmod(0o755)

      log_path = root / "launches.log"
      env = dict(os.environ)
      env.update({
        "HOME": str(home),
        "PATH": f"{binary_dir}:{os.environ.get('PATH', '')}",
        "XDG_STATE_HOME": str(root / "state"),
        "HIDDIFY_PROXY_PORT": proxy_port,
        "HIDDIFY_WAIT_SECONDS": timeout,
        "TEST_LAUNCH_LOG": str(log_path),
        "TEST_CURL_EXIT": "0" if proxy_ready else "7",
      })
      result = subprocess.run(["bash", str(SCRIPT)], env=env, check=False, capture_output=True, text=True)
      launches = log_path.read_text().splitlines() if log_path.exists() else []
      state_log = root / "state/hypr/vpn-first-startup.log"
      log_text = state_log.read_text() if state_log.exists() else ""
      return result, launches, log_text

  def test_vpn_ready_launches_hiddify_before_chrome(self):
    result, launches, _ = self.run_startup()
    self.assertEqual(result.returncode, 0)
    self.assertEqual(len(launches), 2)
    self.assertIn("[workspace 5 silent]", launches[0])
    self.assertIn("[workspace 1 silent]", launches[1])
    self.assertIn("--restore-last-session", launches[1])

  def test_vpn_ready_launches_saved_browser_command(self):
    result, launches, _ = self.run_startup(
      saved_browser_command="chromium --restore-last-session --enable-features=WaylandWindowDecorations"
    )
    self.assertEqual(result.returncode, 0)
    self.assertEqual(len(launches), 2)
    self.assertIn("chromium --restore-last-session", launches[1])
    self.assertIn("[workspace 1 silent]", launches[1])
    self.assertNotIn("google-chrome-stable", launches[1])

  def test_vpn_unavailable_blocks_chrome(self):
    result, launches, log = self.run_startup(proxy_ready=False)
    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(len(launches), 1)
    self.assertIn("workspace 5", launches[0])
    self.assertIn("Chrome remains closed", log)

  def test_invalid_port_fails_closed(self):
    result, launches, log = self.run_startup(proxy_port="bad")
    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(launches, [])
    self.assertIn("Invalid HIDDIFY_PROXY_PORT", log)

  def test_non_numeric_timeout_fails_closed(self):
    result, launches, log = self.run_startup(timeout="one")
    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(launches, [])
    self.assertIn("Invalid HIDDIFY_WAIT_SECONDS", log)


if __name__ == "__main__":
  unittest.main()
