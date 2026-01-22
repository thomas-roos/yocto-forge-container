#!/bin/bash
# Start services and show access information

set -e

# Parse arguments
PROFILES=""
USE_TUNNEL=false
if [ "$1" == "--tunnel" ] || [ "$2" == "--tunnel" ]; then
  PROFILES="--profile registry --profile tunnel"
  USE_TUNNEL=true
else
  PROFILES="--profile registry"
fi

# Set Forgejo domain based on tunnel usage
if [ "$USE_TUNNEL" = true ]; then
  export FORGEJO_DOMAIN="tunnelmole.net"
  export FORGEJO_ROOT_URL="https://tunnelmole.net/"
else
  export FORGEJO_DOMAIN="localhost"
  export FORGEJO_ROOT_URL="http://localhost:3000/"
fi

echo "Starting services..."
docker-compose $PROFILES up -d

echo ""
echo "✅ Services started!"
echo ""

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
    
    # Update Forgejo configuration with new URL
    TUNNEL_DOMAIN=$(echo "$TUNNEL_URL" | sed 's|https://||' | sed 's|http://||' | sed 's|/$||')
    echo ""
    echo "Updating Forgejo configuration..."
    
    # Wait for app.ini to be created
    sleep 3
    
    # Update app.ini directly
    docker exec forgejo sed -i "s|^DOMAIN.*=.*|DOMAIN = $TUNNEL_DOMAIN|g" /data/gitea/conf/app.ini
    docker exec forgejo sed -i "s|^ROOT_URL.*=.*|ROOT_URL = $TUNNEL_URL/|g" /data/gitea/conf/app.ini
    docker exec forgejo sed -i "s|^SSH_DOMAIN.*=.*|SSH_DOMAIN = $TUNNEL_DOMAIN|g" /data/gitea/conf/app.ini
    
    echo "Restarting Forgejo to apply changes..."
    docker-compose restart forgejo > /dev/null 2>&1
    sleep 3
    echo "✅ Forgejo updated with new Tunnelmole URL"
  else
    echo "⚠️  Tunnelmole URL not yet available. Check logs:"
    echo "   docker logs forgejo-tunnelmole"
  fi
else
  echo "ℹ️  Forgejo is running internally (no external access)"
  echo "   To enable public access, run:"
  echo "   ./start.sh --tunnel"
fi

echo ""
echo "Next steps:"
echo "  1. Run setup: ./setup-forgejo.sh"
echo "  2. Check logs: docker-compose logs -f"
echo "  3. Stop services: docker-compose --profile registry --profile tunnel down"
