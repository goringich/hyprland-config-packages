#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$repo_root" <<'PY'
from pathlib import Path
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime, timezone

repo = Path(sys.argv[1])
home = Path.home()
hypr = home / ".config/hypr"
startup = hypr / "UserConfigs/Startup_Apps.conf"
rules = hypr / "UserConfigs/WindowRules.conf"
main = hypr / "hyprland.conf"
script_src = repo / "hypr/UserScripts/VpnFirstStartup.sh"
script_dest = hypr / "UserScripts/VpnFirstStartup.sh"

for path in (startup, rules, main, script_src):
  if not path.is_file():
    raise SystemExit(f"Missing file, no changes applied: {path}")

main_text = main.read_text()
if "Startup_Apps.conf" not in main_text or "WindowRules.conf" not in main_text:
  raise SystemExit("Active Hyprland config does not source the expected startup and rule files")

start_text = startup.read_text()
new_exec = "exec-once = bash $HOME/.config/hypr/UserScripts/VpnFirstStartup.sh"
if new_exec not in start_text:
  pattern = re.compile(r"(?m)^exec-once\s*=\s*\[workspace\s+1\s+silent\]\s*[^\n]*google-chrome-stable[^\n]*--restore-last-session\s*$")
  start_text, count = pattern.subn(new_exec, start_text)
  if count != 1:
    raise SystemExit("Expected exactly one Chrome startup entry; no changes applied")

rules_text = rules.read_text()
new_rules = (
  r"windowrule = workspace 4 silent, class:^([Oo]bsidian|md\.obsidian\.Obsidian)$",
  r"windowrule = workspace 5 silent, class:^([Hh]iddify|[Hh]iddify-[Nn]ext|app\.hiddify\.com)$",
)
for marker, line in (("obsidian", new_rules[0]), ("hiddify", new_rules[1])):
  if line in rules_text:
    continue
  other_rules = [
    line for line in rules_text.splitlines()
    if not line.lstrip().startswith("#")
    and "windowrule" in line
    and "workspace" in line
    and marker in line.lower()
  ]
  if other_rules:
    raise SystemExit(f"Conflicting {marker} workspace rule; no changes applied: {other_rules[0]}")
  rules_text += "\n" + line + "\n"

changes = {
  startup: start_text,
  rules: rules_text,
  script_dest: script_src.read_text(),
}
changed = {path: text for path, text in changes.items() if not path.exists() or path.read_text() != text}
if not changed:
  print("Already installed; no changes made")
  raise SystemExit(0)

state_root = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state")))
backup = state_root / "hypr" / ("backup-vpn-first-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
backup.mkdir(parents=True, mode=0o700, exist_ok=False)
for path in changed:
  if path.exists():
    shutil.copy2(path, backup / path.name)

for path, text in changed.items():
  path.parent.mkdir(parents=True, exist_ok=True)
  previous_mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
  with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as tmp:
    tmp.write(text)
    temp_path = Path(tmp.name)
  temp_path.chmod(previous_mode)
  temp_path.replace(path)
  print(f"Updated {path}")
print(f"Backup of replaced files: {backup}")
PY

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload
  hyprctl configerrors || true
fi
printf '%s\n' 'Restart the Hyprland session to exercise the exec-once startup order.'
