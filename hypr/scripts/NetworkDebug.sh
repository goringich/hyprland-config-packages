#!/bin/bash
# Network troubleshooting script for preventing ERR_NETWORK_CHANGED errors

echo "=== Network Status Check ==="

# Check active network interfaces
echo "Active network interfaces:"
ip addr show | grep -E "^[0-9]+:|inet " | head -20

echo -e "\n=== Routing Table ==="
ip route show

echo -e "\n=== WireGuard Status ==="
sudo wg show 2>/dev/null || echo "No WireGuard interfaces active"

echo -e "\n=== NetworkManager Connections ==="
nmcli connection show --active

echo -e "\n=== DNS Status ==="
cat /etc/resolv.conf | head -10

echo -e "\n=== Common Network Issues Fixes ==="
echo "1. If you see ERR_NETWORK_CHANGED errors:"
echo "   - Multiple VPN connections are conflicting"
echo "   - Docker bridges are auto-connecting"
echo "   - DNS resolution is unstable"
echo ""
echo "2. To fix:"
echo "   - Keep only one VPN active at a time"
echo "   - Disable autoconnect for Docker bridges"
echo "   - Restart NetworkManager if needed: sudo systemctl restart NetworkManager"
echo ""
echo "3. Emergency DNS fix:"
echo "   - sudo systemctl restart systemd-resolved"
echo "   - or change DNS to 8.8.8.8: nmcli connection modify <connection> ipv4.dns 8.8.8.8"

# Check for conflicting routes
conflicting_routes=$(ip route show | grep -c "10.8.0.0/24")
if [ "$conflicting_routes" -gt 1 ]; then
    echo -e "\n⚠️  WARNING: Multiple routes to 10.8.0.0/24 detected!"
    echo "This can cause ERR_NETWORK_CHANGED errors."
fi

# Check for too many active docker networks
active_docker_nets=$(ip addr show | grep -c "br-")
if [ "$active_docker_nets" -gt 2 ]; then
    echo -e "\n⚠️  WARNING: Many Docker networks active ($active_docker_nets)"
    echo "Consider stopping unused containers: docker container prune"
fi