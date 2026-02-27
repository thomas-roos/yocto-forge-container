#!/bin/bash
# Start services and show access information

set -e

# Parse arguments
PROFILES="--profile registry"
USE_TUNNEL=false
if [ "$1" == "--tunnel" ] || [ "$2" == "--tunnel" ]; then
  PROFILES="--profile registry --profile tunnel"
  USE_TUNNEL=true
fi

echo "Starting services..."

# Ensure required directories exist (cleanup may have removed them)
source .env

# Auto-detect USER_ID and GROUP_ID if not set
USER_ID=${USER_ID:-$(id -u)}
GROUP_ID=${GROUP_ID:-$(id -g)}

# Create directories with correct ownership
mkdir -p forgejo-data yocto-cache/sstate-cache yocto-cache/downloads yocto-cache/tmp hashserv-data registry-data
chown -R $USER_ID:$GROUP_ID forgejo-data yocto-cache hashserv-data registry-data 2>/dev/null || true

IFS=',' read -ra RUNNER_LIST <<< "$RUNNERS"
for runner in "${RUNNER_LIST[@]}"; do
  runner_name=$(echo "$runner" | xargs | sed 's/yocto-runner-//')
  for i in $(seq 1 ${RUNNER_REPLICAS:-1}); do
    mkdir -p "runner-data/$runner_name-$i" "yocto-builds/$runner_name-$i"
    chown -R $USER_ID:$GROUP_ID "runner-data/$runner_name-$i" "yocto-builds/$runner_name-$i" 2>/dev/null || true
  done
done

# Export for docker-compose
export USER_ID GROUP_ID

podman-compose $PROFILES up -d

echo ""
echo "✅ Services started!"
echo ""

# Get server IPs
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s --max-time 2 http://checkip.amazonaws.com || true)

# Check if tunnelmole is running
if podman ps --filter "name=forgejo-tunnelmole" --format "{{.Names}}" | grep -q tunnelmole; then
  echo "Waiting for Tunnelmole to establish connection..."
  sleep 10
  
  TUNNEL_URL=$(podman logs forgejo-tunnelmole 2>&1 | grep -o 'https://[^[:space:]]*tunnelmole.net' | head -1)
  
  if [ -n "$TUNNEL_URL" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Forgejo is accessible at:"
    echo "   $TUNNEL_URL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "⚠️  Tunnelmole URL not yet available. Check logs:"
    echo "   podman logs forgejo-tunnelmole"
  fi
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔒 Forgejo is accessible via SSH tunnel only"
  echo ""
  echo "📡 SSH Tunnel (from your laptop):"
  if [ -n "$PUBLIC_IP" ]; then
    echo "   Public:  ssh -L 3000:localhost:3000 user@${PUBLIC_IP}"
  fi
  echo "   Private: ssh -L 3000:localhost:3000 user@${PRIVATE_IP}"
  echo "   Then access: http://localhost:3000"
  if [ -n "$PUBLIC_IP" ]; then
    echo ""
    echo "   Depending on your network topology, use the private or public IP."
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "Next steps:"
echo "  1. Run setup: ./setup-forgejo.sh"
echo "  2. Check logs: podman-compose logs -f"
echo "  3. Stop services: podman-compose down"
