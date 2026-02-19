#!/bin/bash
set -e

FORGEJO_URL="${FORGEJO_URL:-http://forgejo:3000}"
RUNNER_NAME="${RUNNER_NAME:-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-ubuntu:host}"

# Setup user with host UID/GID
USER_ID=${USER_ID:-1000}
GROUP_ID=${GROUP_ID:-1000}

echo "Setting up user with UID=$USER_ID, GID=$GROUP_ID"

# Update yoctouser to match host UID/GID
groupmod -o -g "$GROUP_ID" yoctouser 2>/dev/null || true
usermod -o -u "$USER_ID" yoctouser 2>/dev/null || true

# Ensure directories are writable
chown -R yoctouser:yoctouser /data /nfs

echo "Waiting for Forgejo to be ready..."
until curl -sf "$FORGEJO_URL" > /dev/null 2>&1; do
  sleep 2
done
echo "Forgejo is ready!"

# Switch to yoctouser for runner operations
cd /data

if [ -f .runner ]; then
  echo "Runner already registered, starting..."
  exec sudo -u yoctouser forgejo-runner daemon
fi

echo "Attempting runner registration..."

if [ -n "$FORGEJO_ADMIN_USER" ] && [ -n "$FORGEJO_ADMIN_PASSWORD" ]; then
  echo "Trying API-based registration..."
  
  TOKEN=$(curl -sf -X POST "$FORGEJO_URL/api/v1/users/$FORGEJO_ADMIN_USER/actions/runners/registration-token" \
    -u "$FORGEJO_ADMIN_USER:$FORGEJO_ADMIN_PASSWORD" \
    -H "Content-Type: application/json" 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  
  if [ -n "$TOKEN" ]; then
    echo "API registration successful, registering runner..."
    sudo -u yoctouser forgejo-runner register --no-interactive \
      --instance "$FORGEJO_URL" \
      --token "$TOKEN" \
      --name "$RUNNER_NAME" \
      --labels "$RUNNER_LABELS"
    exec sudo -u yoctouser forgejo-runner daemon
  fi
  echo "API registration failed, trying manual token..."
fi

if [ -n "$FORGEJO_RUNNER_TOKEN" ]; then
  echo "Using manual token from environment..."
  sudo -u yoctouser forgejo-runner register --no-interactive \
    --instance "$FORGEJO_URL" \
    --token "$FORGEJO_RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS"
  exec sudo -u yoctouser forgejo-runner daemon
fi

echo "ERROR: No registration method available!"
exit 1
