#!/bin/bash
# Docker Container Manager - Fix ERR_NETWORK_CHANGED issues

echo "🐳 Docker Container Health Check"
echo "================================="

# Check for containers in restart loop
echo -e "\n📊 Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RestartCount}}"

# Find problematic containers
echo -e "\n⚠️  Containers with restart issues:"
problem_containers=$(docker ps --filter "status=restarting" --format "{{.Names}}")

if [ -z "$problem_containers" ]; then
    echo "✅ No containers stuck in restart loop"
else
    echo "$problem_containers" | while read container; do
        echo "   - $container is restarting"
        echo "     Logs:"
        docker logs "$container" --tail 5 | sed 's/^/       /'
    done
fi

# Check mcu_service specifically
if docker ps --format "{{.Names}}" | grep -q "mcu_service"; then
    echo -e "\n🔍 Checking mcu_service (known problem):"
    uptime=$(docker ps --format "{{.Names}}\t{{.Status}}" | grep mcu_service | awk '{print $2,$3}')
    echo "   Status: $uptime"
    
    if [[ "$uptime" =~ "second" ]]; then
        echo "   ⚠️  Container is constantly restarting!"
        echo "   This causes ERR_NETWORK_CHANGED errors"
        echo ""
        read -p "   Stop this container? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker stop work-mcu_service-1
            echo "   ✅ Container stopped"
        fi
    fi
fi

echo -e "\n💡 Recommendations:"
echo "   • Stop unused containers: docker stop <container_name>"
echo "   • Disable auto-restart: edit docker-compose.yml, change 'restart: always' to 'restart: no'"
echo "   • Check container logs: docker logs <container_name>"