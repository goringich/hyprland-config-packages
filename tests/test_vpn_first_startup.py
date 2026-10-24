#!/usr/bin/env python3
"""Isolated tests for VPN-gated workspace startup and last-profile restoration."""

import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "hypr/UserScripts/VpnFirstStartup.sh"


class VpnFirstStartupTests(unittest.TestCase):
  def run_startup(
    self, proxy_ready=True, proxy_port="12334", timeout="0",
    saved_browser_command=None, clients="[]", recover_after_hidi=False,
    create_guard=True,
  ):
    with tempfile.TemporaryDirectory() as tmp:
      root = pathlib.Path(tmp)
      home = root / "home"
      binary_dir = root / "bin"
      binary_dir.mkdir()
      (home / ".local/bin").mkdir(parents=True)
      chrome = home / ".local/bin/google-chrome-stable"
      chrome.write_text("#!/bin/sh\nexit 0\n")
      chrome.chmod(0o755)

      if saved_browser_command is not None:
        config_dir = home / ".config/hypr/UserConfigs"
        config_dir.mkdir(parents=True)
        (config_dir / "VpnFirstBrowserCommand").write_text(saved_browser_command + "\n")

      guard = home / ".config/hypr/scripts/SessionStartupGuard.sh"
      if create_guard:
        guard.parent.mkdir(parents=True, exist_ok=True)
        guard.write_text("#!/bin/sh\nexit 0\n")

      scripts = {
        "hiddify": "#!/bin/sh\nexit 0\n",
        "hidi": (
          "#!/bin/sh\n"
          "echo 'hidi provider-on' >> \"$TEST_LAUNCH_LOG\"\n"
          "touch \"$TEST_HIDI_FLAG\"\n"
        ),
        "hyprctl": (
          "#!/bin/sh\n"
          "if [ \"$1\" = clients ]; then\n"
          "  printf '%s\\n' \"$TEST_CLIENTS\"\n"
          "else\n"
          "  printf '%s\\n' \"$*\" >> \"$TEST_LAUNCH_LOG\"\n"
          "fi\n"
        ),
        "curl": (
          "#!/bin/sh\n"
          "if [ \"$TEST_RECOVER_AFTER_HIDI\" = 1 ] && [ -f \"$TEST_HIDI_FLAG\" ]; then\n"
          "  exit 0\n"
          "fi\n"
          "exit \"$TEST_CURL_EXIT\"\n"
        ),
      }
      for name, script in scripts.items():
        path = binary_dir / name
        path.write_text(script)
        path.chmod(0o755)

      log_path = root / "launches.log"
      env = dict(os.environ)
      env.update({
        "HOME": str(home),
        "PATH": f"{binary_dir}:{os.environ.get('PATH', '')}",
        "XDG_STATE_HOME": str(root / "state"),
        "HIDDIFY_PROXY_PORT": proxy_port,
        "HIDDIFY_WAIT_SECONDS": timeout,
        "HIDDIFY_ACTIVATION_TIMEOUT": "5",
        "TEST_LAUNCH_LOG": str(log_path),
        "TEST_CURL_EXIT": "0" if proxy_ready else "7",
        "TEST_HIDI_FLAG": str(root / "hidi-on"),
        "TEST_RECOVER_AFTER_HIDI": "1" if recover_after_hidi else "0",
        "TEST_CLIENTS": clients,
      })
      result = subprocess.run(
        ["bash", str(SCRIPT)], env=env, check=False,
        capture_output=True, text=True, timeout=20,
      )
      launches = log_path.read_text().splitlines() if log_path.exists() else []
      state_log = root / "state/hypr/vpn-first-startup.log"
      log_text = state_log.read_text() if state_log.exists() else ""
      return result, launches, log_text

  def test_ready_proxy_opens_hiddify_then_chrome(self):
    result, launches, log = self.run_startup()
    self.assertEqual(result.returncode, 0, log)
    self.assertEqual(len(launches), 2)
    self.assertIn("[workspace 5 silent]", launches[0])
    self.assertIn("[workspace 1 silent]", launches[1])
    self.assertIn("--restore-last-session", launches[1])
    self.assertNotIn("hidi provider-on", launches)

  def test_disconnected_proxy_requests_last_profile(self):
    result, launches, log = self.run_startup(proxy_ready=False, timeout="3", recover_after_hidi=True)
    self.assertEqual(result.returncode, 0, log)
    self.assertIn("hidi provider-on", launches)
    self.assertTrue(any("[workspace 1 silent]" in line for line in launches))

  def test_unavailable_proxy_blocks_chrome(self):
    result, launches, log = self.run_startup(proxy_ready=False, timeout="3")
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("hidi provider-on", launches)
    self.assertFalse(any("[workspace 1 silent]" in line for line in launches))
    self.assertIn("Chrome remains closed", log)

  def test_existing_windows_not_duplicated(self):
    clients = '[{"class":"app.hiddify.com"},{"class":"Google-chrome"}]'
    result, launches, log = self.run_startup(clients=clients)
    self.assertEqual(result.returncode, 0, log)
    self.assertEqual(launches, [])
    self.assertIn("Browser already open", log)

  def test_saved_guard_path_replaced_without_removing_guard(self):
    command = (
      'bash -lc "sleep 11; bash $scriptsDir/SessionStartupGuard.sh '
      'run-shell-if-normal chrome-restore '
      """'hyprctl dispatch exec \\"[workspace 1 silent] """ +
      '$HOME/.local/bin/google-chrome-stable --restore-last-session\\"\'"'
    )
    result, launches, log = self.run_startup(saved_browser_command=command)
    self.assertEqual(result.returncode, 0, log)
    self.assertIn("SessionStartupGuard.sh", launches[-1])
    self.assertIn("/.config/hypr/scripts/SessionStartupGuard.sh", launches[-1])
    self.assertNotIn("$scriptsDir", launches[-1])
    self.assertIn("run-shell-if-normal", launches[-1])

  def test_missing_session_guard_is_not_bypassed(self):
    result, launches, log = self.run_startup(
      saved_browser_command='bash $scriptsDir/SessionStartupGuard.sh run-shell-if-normal chrome-restore "echo test"',
      create_guard=False,
    )
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("SessionStartupGuard missing", log)
    self.assertFalse(any("workspace 1" in line for line in launches))

  def test_invalid_port(self):
    result, launches, log = self.run_startup(proxy_port="invalid")
    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(launches, [])
    self.assertIn("Invalid HIDDIFY_PROXY_PORT", log)

  def test_invalid_timeout(self):
    result, launches, log = self.run_startup(timeout="invalid")
    self.assertNotEqual(result.returncode, 0)
    self.assertEqual(launches, [])
    self.assertIn("Invalid startup timeout", log)


if __name__ == "__main__":
  unittest.main()
