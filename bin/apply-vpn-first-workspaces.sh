#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$repo_root" <<'PY'
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

repo = Path(sys.argv[1])
home = Path.home()
hypr = home / '.config/hypr'
startup = hypr / 'UserConfigs/Startup_Apps.conf'
rules = hypr / 'UserConfigs/WindowRules.conf'
main = hypr / 'hyprland.conf'
script_src = repo / 'hypr/UserScripts/VpnFirstStartup.sh'
script_dest = hypr / 'UserScripts/VpnFirstStartup.sh'
command_dest = hypr / 'UserConfigs/VpnFirstBrowserCommand'

for path in (startup, rules, main, script_src):
  if not path.is_file():
    raise SystemExit(f'Missing required file, no changes made: {path}')

main_text = main.read_text()
if 'Startup_Apps.conf' not in main_text or 'WindowRules.conf' not in main_text:
  raise SystemExit('Hyprland source configuration differs. No changes made.')

def hypr_version():
  try:
    result = subprocess.run(['hyprctl', 'version', '-j'], check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)
    version = str(data.get('version', ''))
    match = re.search(r'(\d+)\.(\d+)(?:\.(\d+))?', version)
    if match:
      return tuple(int(x or 0) for x in match.groups())
  except (OSError, subprocess.SubprocessError, ValueError, TypeError):
    pass
  try:
    result = subprocess.run(['hyprctl', 'version'], check=True, capture_output=True, text=True)
    match = re.search(r'(\d+)\.(\d+)(?:\.(\d+))?', result.stdout)
    if match:
      return tuple(int(x or 0) for x in match.groups())
  except (OSError, subprocess.SubprocessError):
    pass
  raise SystemExit('Cannot determine Hyprland version; no changes made. Run hyprctl version.')

version = hypr_version()
modern = version >= (0, 53, 0)
modern_rule = {
  'Obsidian': r'windowrule = match:class ^([Oo]bsidian|md\.obsidian\.Obsidian)$, workspace 4 silent',
  'Hiddify': r'windowrule = match:class ^([Hh]iddify|[Hh]iddify-[Nn]ext|app\.hiddify\.com)$, workspace 5 silent',
}
legacy_rule = {
  'Obsidian': r'windowrule = workspace 4 silent, class:^([Oo]bsidian|md\.obsidian\.Obsidian)$',
  'Hiddify': r'windowrule = workspace 5 silent, class:^([Hh]iddify|[Hh]iddify-[Nn]ext|app\.hiddify\.com)$',
}
expected_rules = modern_rule if modern else legacy_rule
old_rules = legacy_rule if modern else modern_rule

changes = {}
new_exec = 'exec-once = bash $HOME/.config/hypr/UserScripts/VpnFirstStartup.sh'
startup_text = startup.read_text()
files = sorted(p for p in hypr.rglob('*.conf') if p.is_file() and p != command_dest)
if main not in files:
  files.append(main)
if startup not in files:
  files.append(startup)

browser_regex = re.compile(r'(?i)(?:google-chrome|chromium|chrome-stable|chrome-browser|brave-browser|\bchrome\b)')
exec_regex = re.compile(r'^(\s*)exec-once\s*=\s*(.*?)\s*$')
found = []
for path in files:
  for index, line in enumerate(path.read_text().splitlines()):
    match = exec_regex.match(line)
    if match and browser_regex.search(match.group(2)):
      found.append((path, index, line, match.group(2)))

already_hooked = new_exec in startup_text
if len(found) > 1 or (already_hooked and found):
  lines = ', '.join(f'{p.relative_to(hypr)}:{i + 1}' for p, i, _, _ in found)
  raise SystemExit(f'Ambiguous/duplicate browser startup entries ({lines}). No changes made.')

if found and not already_hooked:
  path, index, line, command = found[0]
  command = re.sub(r'^\[workspace\s+[^\]]+\]\s*', '', command).strip()
  if not command:
    raise SystemExit('Chrome command is empty; no changes made.')
  content = path.read_text().splitlines(keepends=True)
  original = content[index].rstrip('\r\n')
  content[index] = '# vpn-first disabled original: ' + original + '\n'
  changes[path] = ''.join(content)
  changes[command_dest] = command + '\n'
  startup_text = changes.get(startup, startup_text).rstrip('\n') + '\n' + new_exec + '\n'
  changes[startup] = startup_text
elif not already_hooked:
  raise SystemExit(
    'Chrome autostart not found in Hyprland *.conf. No changes made. '
    'Check XDG autostart/systemd or inspect: '
    "rg -n -i 'chrome|chromium|browser|exec-once' ~/.config/hypr"
  )

if already_hooked and not command_dest.exists():
  raise SystemExit('VPN-first hook exists but saved Chrome command is missing; no changes made.')

rule_lines = rules.read_text().splitlines(keepends=True)
for name, required in expected_rules.items():
  if any(line.strip() == required for line in rule_lines):
    continue
  alternate = old_rules[name]
  replaced = False
  for i, line in enumerate(rule_lines):
    if line.strip() == alternate:
      rule_lines[i] = required + '\n'
      replaced = True
      break
  if replaced:
    continue
  if any('windowrule' in line and not line.lstrip().startswith('#') and name.lower() in line.lower() for line in rule_lines):
    raise SystemExit(f'Existing custom {name} window rule needs review; no changes made.')
  rule_lines.append(required + '\n')
changes[rules] = ''.join(rule_lines)
changes[script_dest] = script_src.read_text()
changes = {path: body for path, body in changes.items() if not path.exists() or path.read_text() != body}
if not changes:
  print('Already installed; no changes made')
  raise SystemExit(0)

state_root = Path(os.environ.get('XDG_STATE_HOME', str(home / '.local/state')))
backup = state_root / 'hypr' / ('backup-vpn-first-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
backup.mkdir(parents=True, mode=0o700, exist_ok=False)
for path in changes:
  if path.exists():
    target = backup / path.relative_to(hypr)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)

for path, text in changes.items():
  path.parent.mkdir(parents=True, exist_ok=True)
  mode = path.stat().st_mode & 0o777 if path.exists() else (0o600 if path == command_dest else 0o644)
  with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as tmp:
    tmp.write(text)
    temp_path = Path(tmp.name)
  temp_path.chmod(mode)
  temp_path.replace(path)
  print(f'Updated: {path.relative_to(hypr)}')
print(f'Backup: {backup}')
print(f'Hyprland: {version[0]}.{version[1]}.{version[2]}; window rule syntax: {"modern" if modern else "legacy"}')
PY

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload
  hyprctl configerrors || true
fi
printf '%s\n' 'Log in to Hyprland again to run exec-once.'
