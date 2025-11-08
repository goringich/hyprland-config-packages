# Managed by Copilot: shell PATH and shims bootstrap
# Idempotent: safe to source multiple times

# Ensure user bin is ahead of system bins
case :$PATH: in
  *:$HOME/.local/bin:*) :;;
  *) export PATH="$HOME/.local/bin:$PATH";;

esac

# Optional: make sudo expand aliases (functions/shims don't need this)
# Uncomment if you rely on alias-based overrides
# alias sudo='sudo '
