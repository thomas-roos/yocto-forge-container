#!/bin/bash
# Cleanup script - stops services and optionally removes data

set -e

echo "Stopping all services..."
podman-compose --profile registry --profile tunnel --profile hashserv --profile sstate-server down

if [ "$1" == "--clean-data" ]; then
  echo "Removing all data directories..."
  sudo rm -rf forgejo-data runner-data registry-data yocto-cache yocto-builds hashserv-data
  echo "✅ All data removed"
else
  echo "✅ Services stopped (data preserved)"
  echo ""
  echo "To remove all data, run:"
  echo "  ./cleanup.sh --clean-data"
fi
