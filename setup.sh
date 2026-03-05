#!/bin/bash
# One-time setup: generate config, start services, create admin user
set -e

if [ ! -f .env ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
fi

source .env

# Auto-detect USER_ID and GROUP_ID if not set
USER_ID=${USER_ID:-$(id -u)}
GROUP_ID=${GROUP_ID:-$(id -g)}
RUNNER_REPLICAS=${RUNNER_REPLICAS:-1}

echo "Generating docker-compose.override.yml..."

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
  
  for i in $(seq 1 $RUNNER_REPLICAS); do
    cat >> docker-compose.override.yml << EOF
  runner-$runner_name-$i:
    build:
      context: .
      dockerfile: Dockerfile.$runner
    image: ${REGISTRY_URL}/${runner}:latest
    container_name: forgejo-runner-$runner_name-$i
    restart: always
    user: "$USER_ID:$GROUP_ID"
    privileged: true
    environment:
      - FORGEJO_URL=http://forgejo:3000
      - FORGEJO_ADMIN_USER=\${FORGEJO_ADMIN_USER}
      - FORGEJO_ADMIN_PASSWORD=\${FORGEJO_ADMIN_PASSWORD}
      - FORGEJO_RUNNER_TOKEN=\${FORGEJO_RUNNER_TOKEN}
      - RUNNER_NAME=runner-$runner_name-$i
      - RUNNER_LABELS=$runner_name:host
      - USER_ID=$USER_ID
      - GROUP_ID=$GROUP_ID
    volumes:
      - ./runner-data/$runner_name-$i:/data:Z
      - ./yocto-cache/sstate-cache:/nfs/sstate-cache
      - ./yocto-cache/downloads:/nfs/downloads
      - ./yocto-cache/tmp:/nfs/tmp
      - ./yocto-builds/$runner_name-$i:/home/yoctouser/.cache/act:Z
      - \${XDG_RUNTIME_DIR}/podman/podman.sock:/var/run/docker.sock
      - ./runner-entrypoint.sh:/entrypoint.sh:ro
    entrypoint: ["/entrypoint.sh"]
    depends_on:
      - forgejo
    networks:
      - forgejo-net

EOF
  done
done

echo "✅ Generated docker-compose.override.yml"
echo ""

# Create directories
echo "Creating data directories..."
mkdir -p forgejo-data yocto-cache/sstate-cache yocto-cache/downloads yocto-cache/tmp hashserv-data registry-data
chown -R $USER_ID:$GROUP_ID forgejo-data yocto-cache hashserv-data registry-data 2>/dev/null || true

for runner in "${RUNNER_LIST[@]}"; do
  runner_name=$(echo "$runner" | xargs | sed 's/yocto-runner-//')
  for i in $(seq 1 $RUNNER_REPLICAS); do
    mkdir -p "runner-data/$runner_name-$i" "yocto-builds/$runner_name-$i"
    chown -R $USER_ID:$GROUP_ID "runner-data/$runner_name-$i" "yocto-builds/$runner_name-$i" 2>/dev/null || true
  done
done

# Export for docker-compose
export USER_ID GROUP_ID

echo "Starting services..."
podman-compose --profile registry up -d

echo ""
echo "Waiting for Forgejo to be ready..."
until podman exec forgejo curl -sf http://localhost:3000 > /dev/null 2>&1; do
  sleep 2
done

echo "Waiting for Forgejo configuration..."
until podman exec forgejo test -f /data/gitea/conf/app.ini 2>/dev/null; do
  sleep 2
done

echo "Checking if admin user exists..."
if podman exec -u git forgejo gitea admin user list --config /data/gitea/conf/app.ini 2>/dev/null | grep -q "$FORGEJO_ADMIN_USER"; then
  echo "Admin user '$FORGEJO_ADMIN_USER' already exists!"
  if [ -f .forgejo-admin-password ]; then
    echo ""
    echo "Login credentials:"
    echo "  Username: $FORGEJO_ADMIN_USER"
    echo "  Password: $(cat .forgejo-admin-password)"
  fi
  echo ""
  read -p "Reset password? [y/N] " RESET
  if [ "$RESET" = "y" ] || [ "$RESET" = "Y" ]; then
    RANDOM_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    podman exec -u git forgejo gitea admin user change-password \
      --username "$FORGEJO_ADMIN_USER" --password "$RANDOM_PASSWORD" \
      --config /data/gitea/conf/app.ini
    echo "$RANDOM_PASSWORD" > .forgejo-admin-password
    chmod 600 .forgejo-admin-password
    if grep -q "^FORGEJO_ADMIN_PASSWORD=" .env 2>/dev/null; then
      sed -i "s|^FORGEJO_ADMIN_PASSWORD=.*|FORGEJO_ADMIN_PASSWORD=$RANDOM_PASSWORD|" .env
    else
      echo "FORGEJO_ADMIN_PASSWORD=$RANDOM_PASSWORD" >> .env
    fi
    echo ""
    echo "✅ Password reset!"
    echo "  Username: $FORGEJO_ADMIN_USER"
    echo "  Password: $RANDOM_PASSWORD"
    podman-compose --profile registry restart 2>/dev/null || true
  fi
else
  # Create admin user
  RANDOM_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
  
  echo "Creating admin user: $FORGEJO_ADMIN_USER"
  podman exec -u git forgejo gitea admin user create \
    --admin \
    --username "$FORGEJO_ADMIN_USER" \
    --password "$RANDOM_PASSWORD" \
    --email "$FORGEJO_ADMIN_USER@localhost" \
    --must-change-password=false \
    --config /data/gitea/conf/app.ini
  
  echo "$RANDOM_PASSWORD" > .forgejo-admin-password
  chmod 600 .forgejo-admin-password
  
  if grep -q "^FORGEJO_ADMIN_PASSWORD=" .env 2>/dev/null; then
    sed -i "s|^FORGEJO_ADMIN_PASSWORD=.*|FORGEJO_ADMIN_PASSWORD=$RANDOM_PASSWORD|" .env
  else
    echo "FORGEJO_ADMIN_PASSWORD=$RANDOM_PASSWORD" >> .env
  fi
  
  echo ""
  echo "✅ Admin user created!"
  echo "  Username: $FORGEJO_ADMIN_USER"
  echo "  Password: $RANDOM_PASSWORD"
  echo "  (saved to .forgejo-admin-password)"
  
  echo ""
  echo "Restarting runners to pick up credentials..."
  podman-compose --profile registry restart 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup complete!"
echo ""
echo "Access Forgejo via SSH tunnel:"
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "  ssh -L 3000:localhost:3000 user@${PRIVATE_IP}"
echo "  Then open: http://localhost:3000"
echo ""
echo "Next steps:"
echo "  ./manage.sh logs    # View logs"
echo "  ./manage.sh stop    # Stop services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
