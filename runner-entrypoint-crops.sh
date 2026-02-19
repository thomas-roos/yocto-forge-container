#!/bin/bash
set -e

FORGEJO_URL="${FORGEJO_URL:-http://forgejo:3000}"
RUNNER_NAME="${RUNNER_NAME:-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-ubuntu:host}"

echo "Waiting for Forgejo to be ready..."
until curl -sf "$FORGEJO_URL" > /dev/null 2>&1; do
  sleep 2
done
echo "Forgejo is ready!"

mkdir -p /data
cd /data

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
exit 1
