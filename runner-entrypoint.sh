#!/bin/bash
set -e

FORGEJO_URL="${FORGEJO_URL:-http://forgejo:3000}"
RUNNER_NAME="${RUNNER_NAME:-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-ubuntu:host}"

# Handle CROPS-specific setup
if [[ "$RUNNER_NAME" == *"crops"* ]]; then
  echo "CROPS runner detected, setting up user mapping..."
  if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    groupadd -g $GROUP_ID yoctouser 2>/dev/null || true
    useradd -u $USER_ID -g $GROUP_ID -m yoctouser 2>/dev/null || true
  fi
fi

mkdir -p /data
cd /data

echo "Waiting for Forgejo to be ready..."
until curl -sf "$FORGEJO_URL" > /dev/null 2>&1; do
  sleep 2
done
echo "Forgejo is ready!"

if [ -f .runner ]; then
  echo "Runner already registered, starting..."
  exec forgejo-runner daemon
fi

echo "Attempting runner registration..."

# Try API-based registration
if [ -n "$FORGEJO_ADMIN_USER" ] && [ -n "$FORGEJO_ADMIN_PASSWORD" ]; then
  echo "Trying API-based registration..."
  
  TOKEN=$(curl -sf "$FORGEJO_URL/api/v1/admin/runners/registration-token" \
    -u "$FORGEJO_ADMIN_USER:$FORGEJO_ADMIN_PASSWORD" \
    -H "Content-Type: application/json" 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  
  if [ -n "$TOKEN" ]; then
    echo "API registration successful, registering runner..."
    forgejo-runner register --no-interactive \
      --instance "$FORGEJO_URL" \
      --token "$TOKEN" \
      --name "$RUNNER_NAME" \
      --labels "$RUNNER_LABELS"
    exec forgejo-runner daemon
  fi
  echo "API registration failed, trying manual token..."
fi

# Try manual token
if [ -n "$FORGEJO_RUNNER_TOKEN" ]; then
  echo "Using manual token from environment..."
  forgejo-runner register --no-interactive \
    --instance "$FORGEJO_URL" \
    --token "$FORGEJO_RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS"
  exec forgejo-runner daemon
fi

# Registration failed
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "❌ Runner registration failed!"
echo ""
echo "Manual registration steps:"
echo "  1. Access Forgejo: http://localhost:3000"
echo "  2. Go to: Site Administration → Actions → Runners"
echo "  3. Click 'Create new Runner' and copy the token"
echo "  4. Add to .env: FORGEJO_RUNNER_TOKEN=<your-token>"
echo "  5. Restart: ./manage.sh restart"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 1
