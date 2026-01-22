#!/bin/bash
set -e

source .env

FORGEJO_CONTAINER="forgejo"

echo "Waiting for Forgejo to be ready..."
until docker exec $FORGEJO_CONTAINER curl -sf http://localhost:3000 > /dev/null 2>&1; do
  sleep 2
done

echo "Checking if admin user exists..."
if docker exec -u git $FORGEJO_CONTAINER gitea admin user list 2>/dev/null | grep -q "$FORGEJO_ADMIN_USER"; then
  echo "Admin user '$FORGEJO_ADMIN_USER' already exists!"
  if [ -f .forgejo-admin-password ]; then
    echo ""
    echo "Login credentials:"
    echo "  Username: $FORGEJO_ADMIN_USER"
    echo "  Password: $(cat .forgejo-admin-password)"
  fi
  exit 0
fi

# Generate random password
RANDOM_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

echo "Creating admin user: $FORGEJO_ADMIN_USER"
docker exec -u git $FORGEJO_CONTAINER gitea admin user create \
  --admin \
  --username "$FORGEJO_ADMIN_USER" \
  --password "$RANDOM_PASSWORD" \
  --email "$FORGEJO_ADMIN_USER@localhost" \
  --must-change-password=false

# Save password to file
echo "$RANDOM_PASSWORD" > .forgejo-admin-password
chmod 600 .forgejo-admin-password

echo ""
echo "✅ Admin user created successfully!"
echo ""
echo "Login credentials:"
echo "  Username: $FORGEJO_ADMIN_USER"
echo "  Password: $RANDOM_PASSWORD"
echo ""
echo "⚠️  Password saved to: .forgejo-admin-password"
echo ""
echo "Restarting runner to trigger auto-registration..."
docker-compose restart $(docker-compose ps --services | grep runner) 2>/dev/null || true

echo ""
echo "Check runner registration status:"
echo "  docker-compose logs -f runner-ubuntu"
