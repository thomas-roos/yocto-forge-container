#!/bin/bash
set -e

if [ ! -f .env ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
fi

source .env

if [ "$USE_LOCAL_REGISTRY" = "true" ]; then
  REGISTRY_PROFILE="--profile registry"
else
  REGISTRY_PROFILE=""
fi

IFS=',' read -ra RUNNER_LIST <<< "$RUNNERS"

cat > docker-compose.override.yml << 'EOF'
services:
EOF

for runner in "${RUNNER_LIST[@]}"; do
  runner=$(echo "$runner" | xargs)
  [ -z "$runner" ] && continue
  
  if [ ! -f "Dockerfile.$runner" ]; then
    echo "Warning: Dockerfile.$runner not found, skipping..."
    continue
  fi
  
  runner_name=$(echo "$runner" | sed 's/yocto-runner-//')
  
  cat >> docker-compose.override.yml << EOF
  runner-$runner_name:
    build:
      context: .
      dockerfile: Dockerfile.$runner
    image: ${REGISTRY_URL}/${runner}:latest
    container_name: forgejo-runner-$runner_name
    restart: always
    environment:
      - FORGEJO_URL=http://forgejo:3000
      - FORGEJO_ADMIN_USER=\${FORGEJO_ADMIN_USER}
      - FORGEJO_ADMIN_PASSWORD=\${FORGEJO_ADMIN_PASSWORD}
      - FORGEJO_RUNNER_TOKEN=\${FORGEJO_RUNNER_TOKEN}
      - RUNNER_NAME=runner-$runner_name
      - RUNNER_LABELS=$runner_name:docker://${REGISTRY_URL}/${runner}:latest
    volumes:
      - ./runner-data/$runner_name:/data
      - ./yocto-cache/sstate-cache:/nfs/sstate-cache
      - ./yocto-cache/downloads:/nfs/downloads
      - /var/run/docker.sock:/var/run/docker.sock
      - ./runner-entrypoint.sh:/entrypoint.sh:ro
    entrypoint: ["/entrypoint.sh"]
    depends_on:
      - forgejo
    networks:
      - forgejo-net

EOF
done

echo "Generated docker-compose.override.yml with runners: ${RUNNER_LIST[*]}"
echo ""
echo "To start services:"
echo "  docker-compose $REGISTRY_PROFILE up -d"
echo ""
echo "To enable Tunnelmole:"
echo "  docker-compose $REGISTRY_PROFILE --profile tunnel up -d"
echo ""
echo "After starting with Tunnelmole, get the public URL:"
echo "  docker logs forgejo-tunnelmole 2>&1 | grep 'https://.*tunnelmole.net'"
