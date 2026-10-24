# VPN-first startup (Hyprland)

## Expected behavior

- Obsidian is placed on workspace 4 whenever its main window opens.
- Hiddify is placed on workspace 5 whenever its window opens.
- At login, VpnFirstStartup.sh requests Hiddify on workspace 5, then checks the local SOCKS proxy.
- When the proxy can complete an HTTPS request, Chrome starts on workspace 1 with --restore-last-session via the existing wrapper.
- If the proxy is unavailable for 300 seconds, Chrome is NOT started automatically. Check ~/.local/state/hypr/vpn-first-startup.log.
- VS Code and Telegram autostart settings are unchanged.

The SOCKS check proves that a request succeeded through the configured local proxy; it does not verify the remote exit IP, a TUN interface, or every Chrome request's routing.

## Host configuration compatibility (October 2026)

The original installer required the exact line `exec-once = [workspace 1 silent] ...google-chrome-stable --restore-last-session`. Current installations may use different Chrome launch arguments or a separate `*.conf` file. The updated installer finds one active Chrome/Chromium/Brave `exec-once` command in the local Hyprland config tree, comments out only that original entry, saves its complete command in `UserConfigs/VpnFirstBrowserCommand`, and installs one VPN-gated startup hook. Other autostart lines are not replaced. If zero or multiple entries are found, installation stops safely and prints a diagnostic rather than guessing. Chrome startup controlled by systemd or XDG autostart needs a separate host-specific adjustment.

The installer also detects `hyprctl version`: Hyprland 0.53+ requires the modern `windowrule = match:class ..., workspace N silent` syntax; older versions use `windowrule = workspace N silent, class:...`. It can migrate precisely matching old application rules, leaving unrelated rules intact.

`hyprctl reload` does not run `exec-once`. The VPN startup log appears only after a new Hyprland session, or explicit manual invocation of `bash ~/.config/hypr/UserScripts/VpnFirstStartup.sh`. Run `hyprctl configerrors` after installation.

## Critical Hiddify limitation

Hiddify App 4.1.1 currently DOES NOT auto-connect its last selected profile on desktop just because the app starts. "Start at login" only opens the app. The upstream 4.1.1 HiddifyCli "tunnel activate" implementation also has a reported bug. Therefore this change DOES NOT implement unattended connection of the last profile. It deliberately waits for a real connection rather than reporting a false success or launching Chrome early.

Sources:
- https://github.com/hiddify/hiddify-app/issues/2338
- https://github.com/hiddify/hiddify-app/issues/1161
- https://hiddify.com/app/How-to-use-Hiddify-app/
- https://wiki.hypr.land/0.52.0/Configuring/Window-Rules/

For unattended connection, a tested supported control interface for the installed Hiddify build or a separate private HiddifyCli profile configuration is still required. Do not commit subscription URLs, proxy credentials, profile databases, or exported secrets to this public repository. Do not assume a GUI launch auto-connects.

## Deployment to existing CachyOS installation

This repository's Hyprland export was last updated in November 2025. Inspect the CURRENT host configuration before deploying. Do NOT run bin/import.sh for this small change: it uses rsync --delete and can overwrite unrelated live configuration.

On the host, clone/pull the repository and run `bash bin/apply-vpn-first-workspaces.sh`. The installer checks that Hyprland sources the expected files and that there is one known Chrome autostart entry. It modifies only that entry, adds two app-specific window rules, and installs VpnFirstStartup.sh. It preserves unrelated local customizations, creates timestamped backups under XDG_STATE_HOME/hypr, and can be run repeatedly. If the live configuration differs, the installer stops rather than replacing it wholesale.

To run from a temporary checkout on CachyOS:

```bash
set -euo pipefail
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --depth 1 https://github.com/goringich/hyprland-config-packages.git "$tmp/repo"
bash "$tmp/repo/bin/apply-vpn-first-workspaces.sh"
```

The installer cannot edit GitHub from the host, so treat the repository as the canonical source of the applied startup logic. Review live-only customizations separately before exporting them. The script runs using bash, so an executable bit is not required. Disable duplicate Hiddify "Start at login" if the app and Hyprland both try to start it.

Check the desktop command with "command -v hiddify" or "gtk-launch app.hiddify.com", and compare actual window classes using "hyprctl clients -j". The installed window-rule syntax must also match the host's Hyprland version.

To verify the SOCKS port (default 12334), check Hiddify's Inbound settings and run:

    curl --fail --noproxy '' --proxy socks5h://127.0.0.1:12334 https://www.cloudflare.com/cdn-cgi/trace

If another port is configured, override HIDDIFY_PROXY_PORT for the startup process before launching Hyprland (do not hardcode secrets).

After updating the rules, run "hyprctl reload" and "hyprctl configerrors". The exec-once startup sequence is only exercised by a new Hyprland login.

## Tests

    bash -n hypr/UserScripts/VpnFirstStartup.sh
    python -m unittest discover -s tests -p 'test_vpn_first_startup.py' -v

No privileged or network actions are made by the unit tests.
