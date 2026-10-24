#!/usr/bin/env python3
"""Unit tests for the live-configuration Hyprland installer."""

import os
import pathlib
import subprocess
import tempfile
import unittest


INSTALLER = pathlib.Path(__file__).resolve().parents[1] / "bin/apply-vpn-first-workspaces.sh"


class InstallerTests(unittest.TestCase):
  def create_host(self, root, chrome_line, version="0.54.2"):
    home = root / "home"
    hypr = home / ".config/hypr"
    configs = hypr / "UserConfigs"
    configs.mkdir(parents=True)
    (hypr / "hyprland.conf").write_text(
      "source= $UserConfigs/Startup_Apps.conf\n"
      "source= $UserConfigs/WindowRules.conf\n"
    )
    startup = configs / "Startup_Apps.conf"
    startup.write_text("exec-once = code\n" + chrome_line + "\nexec-once = telegram-desktop\n")
    rules = configs / "WindowRules.conf"
    rules.write_text("windowrule = workspace 7, tag:im*\n")
    bin_dir = root / "bin"
    bin_dir.mkdir()
    binary = bin_dir / "hyprctl"
    binary.write_text(
      "#!/bin/sh\n"
      f"if [ \"$1\" = \"version\" ]; then echo '{{\"version\":\"{version}\"}}'; fi\n"
    )
    binary.chmod(0o755)
    env = dict(os.environ)
    env.update({
      "HOME": str(home),
      "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
      "XDG_STATE_HOME": str(root / "state"),
    })
    return startup, rules, env

  def run_install(self, env):
    return subprocess.run(
      ["bash", str(INSTALLER)], env=env, capture_output=True, text=True, check=False
    )

  def test_original_startup_and_idempotence(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, rules, env = self.create_host(
        pathlib.Path(tmp),
        "exec-once = [workspace 1 silent] $HOME/.local/bin/google-chrome-stable --restore-last-session",
      )
      first = self.run_install(env)
      self.assertEqual(first.returncode, 0, first.stderr)
      self.assertIn("match:class", rules.read_text())
      self.assertEqual(startup.read_text().count("VpnFirstStartup.sh"), 1)
      saved = startup.parent / "VpnFirstBrowserCommand"
      self.assertIn("google-chrome-stable --restore-last-session", saved.read_text())
      self.assertIn("exec-once = code", startup.read_text())
      self.assertIn("exec-once = telegram-desktop", startup.read_text())
      second = self.run_install(env)
      self.assertEqual(second.returncode, 0, second.stderr)
      self.assertIn("Already installed", second.stdout)

  def test_non_exact_chrome_command_preserved(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, _, env = self.create_host(
        pathlib.Path(tmp), "exec-once = sleep 5 && google-chrome --restore-last-session"
      )
      result = self.run_install(env)
      self.assertEqual(result.returncode, 0, result.stderr)
      saved = startup.parent / "VpnFirstBrowserCommand"
      self.assertEqual(saved.read_text(), "sleep 5 && google-chrome --restore-last-session\n")

  def test_chromium_in_separate_config(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, _, env = self.create_host(pathlib.Path(tmp), "exec-once = nm-applet")
      extra = startup.parent / "UserExec.conf"
      extra.write_text("exec-once = [workspace 1 silent] chromium --restore-last-session\n")
      result = self.run_install(env)
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertIn("vpn-first disabled original", extra.read_text())
      self.assertIn("VpnFirstStartup.sh", startup.read_text())

  def test_absent_browser_command_fails_without_changes(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, rules, env = self.create_host(pathlib.Path(tmp), "exec-once = firefox")
      before_startup = startup.read_text()
      before_rules = rules.read_text()
      result = self.run_install(env)
      self.assertNotEqual(result.returncode, 0)
      self.assertIn("Chrome autostart not found", result.stderr)
      self.assertEqual(startup.read_text(), before_startup)
      self.assertEqual(rules.read_text(), before_rules)

  def test_duplicate_browser_autostart_fails_closed(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, _, env = self.create_host(
        pathlib.Path(tmp), "exec-once = google-chrome\nexec-once = chromium"
      )
      result = self.run_install(env)
      self.assertNotEqual(result.returncode, 0)
      self.assertNotIn("VpnFirstStartup.sh", startup.read_text())

  def test_legacy_hyprland_rules(self):
    with tempfile.TemporaryDirectory() as tmp:
      _, rules, env = self.create_host(
        pathlib.Path(tmp), "exec-once = google-chrome", version="0.52.1"
      )
      result = self.run_install(env)
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertIn("workspace 4 silent, class:", rules.read_text())

  def test_upgrade_legacy_rules_to_modern(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, rules, env = self.create_host(
        pathlib.Path(tmp), "exec-once = google-chrome"
      )
      rules.write_text(
        r"windowrule = workspace 4 silent, class:^([Oo]bsidian|md\.obsidian\.Obsidian)$" + "\n"
        + r"windowrule = workspace 5 silent, class:^([Hh]iddify|[Hh]iddify-[Nn]ext|app\.hiddify\.com)$" + "\n"
      )
      result = self.run_install(env)
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertNotIn("workspace 4 silent, class:", rules.read_text())
      self.assertIn("match:class", rules.read_text())


if __name__ == "__main__":
  unittest.main()
