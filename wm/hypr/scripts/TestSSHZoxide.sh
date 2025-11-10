#!/bin/bash
# Test SSH agent and zoxide configuration

echo "🔍 Testing SSH Agent and Zoxide Configuration"
echo "============================================="

# Test SSH Agent
echo -e "\n📡 SSH Agent Status:"
if [ -n "$SSH_AUTH_SOCK" ]; then
    echo "✅ SSH_AUTH_SOCK is set: $SSH_AUTH_SOCK"
    
    if ssh-add -l >/dev/null 2>&1; then
        echo "✅ SSH Agent is running with keys loaded:"
        ssh-add -l | sed 's/^/   /'
    else
        echo "⚠️  SSH Agent is running but no keys loaded"
        echo "   Run: ~/.local/bin/load-ssh-keys.sh"
    fi
else
    echo "❌ SSH_AUTH_SOCK is not set"
    echo "   Run: source ~/.zshrc"
fi

# Test Zoxide
echo -e "\n🗂️  Zoxide Status:"
if command -v z >/dev/null 2>&1; then
    echo "✅ Zoxide is available (command 'z')"
    echo "   Version: $(zoxide --version)"
    
    # Show some zoxide stats if database exists
    if zoxide query --list >/dev/null 2>&1; then
        echo "   Database entries: $(zoxide query --list | wc -l)"
        echo "   Recent directories:"
        zoxide query --list | tail -5 | sed 's/^/   /'
    else
        echo "   Database is empty (start using 'z <dir>' to populate)"
    fi
else
    echo "❌ Zoxide command 'z' not found"
    echo "   Run: source ~/.zshrc"
fi

# Test aliases
echo -e "\n🔧 Available Aliases:"
echo "   z       -> smart cd (zoxide)"
echo "   zi      -> interactive directory selection" 
echo "   cd      -> aliased to 'z'"
echo "   ..      -> z .."
echo "   ...     -> z ../.."

echo -e "\n🎉 Configuration test completed!"
echo "   • Open a new terminal to use the full configuration"
echo "   • SSH keys will auto-load in new terminals"
echo "   • Use 'z <dir>' to navigate and build zoxide database"