#!/bin/bash
# Manage services: start, stop, clean, logs
set -e

COMMAND=${1:-help}

case "$COMMAND" in
  start)
    # Parse tunnel flag
    PROFILES="--profile registry"
    if [ "$2" == "--tunnel" ]; then
      PROFILES="--profile registry --profile tunnel"
    fi
    
    source .env
    USER_ID=${USER_ID:-$(id -u)}
    GROUP_ID=${GROUP_ID:-$(id -g)}
    
    # Ensure directories exist
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
    
    export USER_ID GROUP_ID
    
    echo "Starting services..."
    podman-compose $PROFILES up -d
    
    echo ""
    echo "✅ Services started!"
    echo ""
    
    # Show access info
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    PUBLIC_IP=$(curl -s --max-time 2 http://checkip.amazonaws.com || true)
    
    if [ "$2" == "--tunnel" ] && podman ps --filter "name=forgejo-tunnelmole" --format "{{.Names}}" | grep -q tunnelmole; then
      echo "Waiting for Tunnelmole..."
      sleep 10
      TUNNEL_URL=$(podman logs forgejo-tunnelmole 2>&1 | grep -o 'https://[^[:space:]]*tunnelmole.net' | head -1)
      
      if [ -n "$TUNNEL_URL" ]; then
        echo "🌐 Public access: $TUNNEL_URL"
      else
        echo "⚠️  Tunnelmole URL not ready. Check: podman logs forgejo-tunnelmole"
      fi
    else
      echo "🔒 SSH Tunnel access:"
      [ -n "$PUBLIC_IP" ] && echo "   ssh -L 3000:localhost:3000 user@${PUBLIC_IP}"
      echo "   ssh -L 3000:localhost:3000 user@${PRIVATE_IP}"
      echo "   Then: http://localhost:3000"
    fi
    ;;
    
  stop)
    echo "Stopping services..."
    podman-compose --profile registry --profile tunnel --profile hashserv --profile sstate-server down
    echo "✅ Services stopped"
    ;;
    
  clean)
    echo "Stopping services..."
    podman-compose --profile registry --profile tunnel --profile hashserv --profile sstate-server down
    echo ""
    read -p "Remove all data? This cannot be undone. [y/N] " CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
      echo "Removing data directories..."
      sudo rm -rf forgejo-data runner-data registry-data yocto-cache yocto-builds hashserv-data
      echo "✅ All data removed"
    else
      echo "Cancelled"
    fi
    ;;
    
  logs)
    shift
    podman-compose logs -f "$@"
    ;;
    
  ps|status)
    podman-compose ps
    ;;
    
  restart)
    echo "Restarting services..."
    podman-compose --profile registry restart
    echo "✅ Services restarted"
    ;;
    
  cache-start)
    echo "Starting cache servers..."
    podman-compose --profile hashserv --profile sstate-server up -d
    echo "✅ Cache servers started"
    echo ""
    echo "Hash Equivalence: wss://<server-ip>:8686/ws"
    echo "Sstate Cache: http://<server-ip>:8080/sstate-cache/"
    echo "Downloads: http://<server-ip>:8080/downloads/"
    ;;
    
  cache-stop)
    echo "Stopping cache servers..."
    podman-compose --profile hashserv --profile sstate-server down
    echo "✅ Cache servers stopped"
    ;;
    
  *)
    echo "Usage: ./manage.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [--tunnel]  Start services (optionally with Tunnelmole)"
    echo "  stop              Stop all services"
    echo "  restart           Restart services"
    echo "  clean             Stop services and remove all data"
    echo "  logs [service]    View logs (optionally filter by service)"
    echo "  ps|status         Show running services"
    echo "  cache-start       Start hash equivalence and sstate HTTP servers"
    echo "  cache-stop        Stop cache servers"
    echo ""
    echo "Examples:"
    echo "  ./manage.sh start"
    echo "  ./manage.sh start --tunnel"
    echo "  ./manage.sh logs forgejo"
    echo "  ./manage.sh logs runner-ubuntu-22.04-1"
    exit 1
    ;;
esac
