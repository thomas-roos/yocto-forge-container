#!/bin/bash
set -e

FORGEJO_URL="${FORGEJO_URL:-http://forgejo:3000}"
RUNNER_NAME="${RUNNER_NAME:-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-ubuntu:host}"

# Ensure /data is writable
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

if [ -n "$FORGEJO_ADMIN_USER" ] && [ -n "$FORGEJO_ADMIN_PASSWORD" ]; then
  echo "Trying API-based registration..."
  
  TOKEN=$(curl -sf -X POST "$FORGEJO_URL/api/v1/users/$FORGEJO_ADMIN_USER/actions/runners/registration-token" \
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

if [ -n "$FORGEJO_RUNNER_TOKEN" ]; then
  echo "Using manual token from environment..."
  forgejo-runner register --no-interactive \
    --instance "$FORGEJO_URL" \
    --token "$FORGEJO_RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS"
  exec forgejo-runner daemon
fi

echo "ERROR: No registration method available!"
echo "Please set either:"
echo "  - FORGEJO_ADMIN_USER and FORGEJO_ADMIN_PASSWORD for API registration"
echo "  - FORGEJO_RUNNER_TOKEN for manual registration"
echo ""
echo "To get a manual token:"
echo "  1. Access Forgejo web UI"
echo "  2. Go to Site Administration → Actions → Runners"
echo "  3. Click 'Create new Runner' and copy the token"
echo "  4. Set FORGEJO_RUNNER_TOKEN in .env and restart"
exit 1
