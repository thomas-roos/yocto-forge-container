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
docker-compose $PROFILES up -d

echo ""
echo "✅ Services started!"
echo ""

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Check if tunnelmole is running
if docker ps --filter "name=forgejo-tunnelmole" --format "{{.Names}}" | grep -q tunnelmole; then
  echo "Waiting for Tunnelmole to establish connection..."
  sleep 10
  
  TUNNEL_URL=$(docker logs forgejo-tunnelmole 2>&1 | grep -o 'https://[^[:space:]]*tunnelmole.net' | head -1)
  
  if [ -n "$TUNNEL_URL" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Forgejo is accessible at:"
    echo "   $TUNNEL_URL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo "⚠️  Tunnelmole URL not yet available. Check logs:"
    echo "   docker logs forgejo-tunnelmole"
  fi
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔒 Forgejo is accessible via SSH tunnel only"
  echo ""
  echo "📡 SSH Tunnel (from your laptop):"
  echo "   ssh -L 3000:localhost:3000 user@${SERVER_IP}"
  echo "   Then access: http://localhost:3000"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "Next steps:"
echo "  1. Run setup: ./setup-forgejo.sh"
echo "  2. Check logs: docker-compose logs -f"
echo "  3. Stop services: docker-compose down"
