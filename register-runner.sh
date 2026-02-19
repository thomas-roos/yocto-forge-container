#!/bin/bash
# Register runner script

set -e

source .env

# Check if password file exists, otherwise prompt
if [ -f .forgejo-admin-password ]; then
  ADMIN_PASSWORD=$(cat .forgejo-admin-password)
else
  echo "Enter admin password for user '$FORGEJO_ADMIN_USER':"
  read -s ADMIN_PASSWORD
  echo ""
fi

echo "Getting runner registration token from Forgejo..."

# Get token via API
TOKEN=$(podman exec forgejo curl -sf -X POST "http://localhost:3000/api/v1/admin/runners/registration-token" \
  -u "$FORGEJO_ADMIN_USER:$ADMIN_PASSWORD" \
  -H "Content-Type: application/json" 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Failed to get token via API. Please check your password or get token manually:"
  echo ""
  echo "1. Login to Forgejo"
  echo "2. Go to Site Administration → Actions → Runners"
  echo "3. Click 'Create new Runner' and copy the token"
  echo "4. Run: echo 'FORGEJO_RUNNER_TOKEN=<your-token>' >> .env"
  echo "5. Run: podman-compose restart runner-ubuntu"
  exit 1
fi

echo "Token obtained successfully!"
echo ""
echo "Updating .env with runner token..."
if grep -q "FORGEJO_RUNNER_TOKEN=" .env; then
  sed -i "s|FORGEJO_RUNNER_TOKEN=.*|FORGEJO_RUNNER_TOKEN=$TOKEN|g" .env
else
  echo "FORGEJO_RUNNER_TOKEN=$TOKEN" >> .env
fi

echo "Restarting runner..."
podman-compose restart $(podman-compose ps --services | grep runner) > /dev/null 2>&1

echo ""
echo "✅ Runner registration initiated!"
echo ""
echo "Check runner status:"
echo "  podman-compose logs -f runner-ubuntu"
echo ""
echo "Verify in Forgejo UI:"
echo "  Site Administration → Actions → Runners"
