# Modern CLI shims (safe 1:1)

This setup provides safe command shims that prefer modern tools when it won't break flags/behavior, and transparently falls back to the original commands otherwise.

Provided shims in `~/.local/bin`:
- `df` → `duf` only when called without options; otherwise `/usr/bin/df`
- `du` → `dust` only when called without options; otherwise `/usr/bin/du`
- `ls` → `eza` only when called without options; otherwise `/usr/bin/ls`
- `cat` → `bat --paging=never --style=plain` only when called without options; otherwise `/usr/bin/cat`
- `grep` → `rg --color=never` only when called without options; otherwise `/usr/bin/grep`

Notes:
- No override for `find` by default (too risky for 1:1). If you want, add a `find` shim later.
- Environment is set via `~/.config/environment.d/10-local-bin.conf` so GUIs and shells see `~/.local/bin` first.

## Sudo behavior
- These user shims are not used under `sudo` by default because `sudo` uses a restricted PATH.
- To enable shims for `sudo`:
  1) Install system-wide shims into `/usr/local/bin` (preferred).
  2) Or allow PATH to be preserved in sudoers: add `Defaults env_keep += "PATH"` via `sudo visudo`.

## Install modern tools on Arch
Run:

```bash
~/.local/bin/install-modern-utils-arch.sh
```

Packages: duf eza bat ripgrep fd dust.
