#!/bin/bash
# Cleanup script - stops services and optionally removes data

set -e

echo "Stopping all services..."
docker-compose --profile registry --profile tunnel down

if [ "$1" == "--clean-data" ]; then
  echo "Removing all data directories..."
  sudo rm -rf forgejo-data runner-data registry-data yocto-cache
  echo "✅ All data removed"
else
  echo "✅ Services stopped (data preserved)"
  echo ""
  echo "To remove all data, run:"
  echo "  ./cleanup.sh --clean-data"
fi
