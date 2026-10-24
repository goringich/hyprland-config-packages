#!/usr/bin/env python3
"""Isolated checks for the selective Hyprland installer."""

import os
import pathlib
import subprocess
import tempfile
import unittest


INSTALLER = pathlib.Path(__file__).resolve().parents[1] / "bin/apply-vpn-first-workspaces.sh"


class InstallerTests(unittest.TestCase):
  def create_host(self, root, chrome_line):
    home = root / "home"
    hypr = home / ".config/hypr"
    configs = hypr / "UserConfigs"
    configs.mkdir(parents=True)
    (hypr / "hyprland.conf").write_text(
      "source= $UserConfigs/Startup_Apps.conf\nsource= $UserConfigs/WindowRules.conf\n"
    )
    startup = configs / "Startup_Apps.conf"
    startup.write_text("exec-once = code\n" + chrome_line + "\nexec-once = telegram-desktop\n")
    rules = configs / "WindowRules.conf"
    rules.write_text("windowrule = workspace 7, tag:im*\n")
    bin_dir = root / "bin"
    bin_dir.mkdir()
    (bin_dir / "hyprctl").write_text("#!/bin/sh\nexit 0\n")
    (bin_dir / "hyprctl").chmod(0o755)
    env = dict(os.environ)
    env["HOME"] = str(home)
    env["XDG_STATE_HOME"] = str(root / "state")
    env["PATH"] = str(bin_dir) + ":" + env.get("PATH", "")
    return startup, rules, env

  def test_apply_then_repeat_without_duplicates(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, rules, env = self.create_host(
        pathlib.Path(tmp),
        "exec-once = [workspace 1 silent] $HOME/.local/bin/google-chrome-stable --restore-last-session",
      )
      first = subprocess.run(["bash", str(INSTALLER)], env=env, capture_output=True, text=True)
      self.assertEqual(first.returncode, 0, first.stderr)
      self.assertIn("exec-once = code", startup.read_text())
      self.assertIn("exec-once = telegram-desktop", startup.read_text())
      self.assertEqual(startup.read_text().count("VpnFirstStartup.sh"), 1)
      self.assertIn("Obsidian", rules.read_text())
      self.assertEqual(rules.read_text().count("windowrule = workspace 5 silent"), 1)
      second = subprocess.run(["bash", str(INSTALLER)], env=env, capture_output=True, text=True)
      self.assertEqual(second.returncode, 0, second.stderr)
      self.assertIn("Already installed", second.stdout)

  def test_unknown_browser_entry_does_not_modify_files(self):
    with tempfile.TemporaryDirectory() as tmp:
      startup, rules, env = self.create_host(pathlib.Path(tmp), "exec-once = firefox")
      original_startup = startup.read_text()
      original_rules = rules.read_text()
      result = subprocess.run(["bash", str(INSTALLER)], env=env, capture_output=True, text=True)
      self.assertNotEqual(result.returncode, 0)
      self.assertEqual(startup.read_text(), original_startup)
      self.assertEqual(rules.read_text(), original_rules)


if __name__ == "__main__":
  unittest.main()
