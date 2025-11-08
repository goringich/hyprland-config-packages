#!/bin/bash
# Quick network fix script for ERR_NETWORK_CHANGED errors

echo "🔧 Fixing network issues..."

# 1. Restart DNS resolver
echo "1. Restarting DNS resolver..."
sudo systemctl restart systemd-resolved

# 2. Flush DNS cache
echo "2. Flushing DNS cache..."
sudo systemctl reload-or-restart systemd-resolved

# 3. Check for conflicting VPN connections
echo "3. Checking VPN connections..."
active_vpns=$(nmcli connection show --active | grep -c "wireguard\|vpn")
if [ "$active_vpns" -gt 1 ]; then
    echo "⚠️  Multiple VPN connections detected. Keeping only arch2..."
    nmcli connection down arch 2>/dev/null || true
fi

# 4. Restart NetworkManager if needed
if [ "$1" = "--full-reset" ]; then
    echo "4. Full NetworkManager restart..."
    sudo systemctl restart NetworkManager
    sleep 3
    # Reconnect to WiFi
    wifi_connection=$(nmcli connection show --active | grep wifi | awk '{print $1}' | head -1)
    if [ -n "$wifi_connection" ]; then
        nmcli connection up "$wifi_connection"
    fi
fi

# 5. Test connectivity
echo "5. Testing connectivity..."
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connection working"
else
    echo "❌ Internet connection still has issues"
    echo "Try: $0 --full-reset"
fi

echo "🎉 Network fix completed!"