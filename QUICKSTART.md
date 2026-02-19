# Quick Reference

## Setup (First Time)
```bash
./generate-compose.sh
./start.sh --tunnel
./setup-forgejo.sh
```

## Daily Usage
```bash
# Start services (shows URL automatically)
./start.sh --tunnel

# Stop services
podman-compose --profile registry --profile tunnel down
```

## Building Runner Images
```bash
# Build
podman build -f Dockerfile.yocto-runner-ubuntu -t localhost:5000/yocto-runner-ubuntu:latest .

# Push to local registry
podman push localhost:5000/yocto-runner-ubuntu:latest
```

## Troubleshooting
```bash
# View all logs
podman-compose logs -f

# Restart a service
podman-compose restart forgejo

# Check running services
podman-compose ps

# Clean everything
./cleanup.sh --clean-data
```

## Adding New Runners
1. Create `Dockerfile.yocto-runner-<name>`
2. Edit `.env`: `RUNNERS=yocto-runner-ubuntu,yocto-runner-<name>`
3. Run `./generate-compose.sh`
4. Restart: `podman-compose up -d`
