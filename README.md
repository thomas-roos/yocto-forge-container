# Forgejo for Yocto Development

Minimal Docker-based Forgejo setup for Yocto development with Actions runners, shared caches, and optional public access via Tunnelmole.

## Features

- Forgejo Git service (v14.0.1)
- Forgejo Actions runners with Yocto build environment
- Shared Yocto caches (sstate-cache, downloads) across builds
- Local Docker registry for runner images
- Optional Tunnelmole integration for public access
- Support for multiple OS-based runners (configurable via .env)

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env to customize settings
   ```

2. **Generate runner services**
   ```bash
   ./generate-compose.sh
   ```

3. **Start services**
   ```bash
   # With Tunnelmole for public access (recommended)
   ./start.sh --tunnel
   
   # Or without Tunnelmole (internal only)
   ./start.sh
   ```
   
   The script will display the public URL automatically.

4. **Run automated setup**
   ```bash
   ./setup-forgejo.sh
   ```
   
   This creates the admin user account with a random password.

5. **Access Forgejo**
   - Public URL shown by start script
   - Login with credentials shown by setup script (also saved in `.forgejo-admin-password`)

## Configuration

Edit `.env` to customize:

```bash
# Use local registry or external
USE_LOCAL_REGISTRY=true
REGISTRY_URL=localhost:5000

# Comma-separated list of runners to enable
# Must match Dockerfile names (without "Dockerfile." prefix)
RUNNERS=yocto-runner-ubuntu

# Admin credentials for auto-registration
FORGEJO_ADMIN_USER=admin
FORGEJO_ADMIN_PASSWORD=changeme123

# Optional: Manual runner token (if auto-registration fails)
FORGEJO_RUNNER_TOKEN=
```

## Building and Pushing Runner Images

If using local registry:

```bash
# Start registry
docker-compose --profile registry up -d registry

# Build and push runner image
docker build -f Dockerfile.yocto-runner-ubuntu -t localhost:5000/yocto-runner-ubuntu:latest .
docker push localhost:5000/yocto-runner-ubuntu:latest
```

## Adding Custom Runners

1. Create a new Dockerfile (e.g., `Dockerfile.yocto-runner-fedora`)
2. Add it to the RUNNERS list in `.env`:
   ```bash
   RUNNERS=yocto-runner-ubuntu,yocto-runner-fedora
   ```
3. Regenerate compose configuration:
   ```bash
   ./generate-compose.sh
   ```
4. Restart services:
   ```bash
   docker-compose up -d
   ```

## Directory Structure

```
.
├── forgejo-data/           # Forgejo data and repositories
├── yocto-cache/
│   ├── sstate-cache/       # Shared Yocto state cache
│   └── downloads/          # Shared Yocto downloads
├── runner-data/
│   ├── ubuntu/             # Runner registration data
│   └── ...
└── registry-data/          # Local Docker registry storage
```

## Runner Registration

Runners attempt automatic registration using:
1. **API-based**: Uses FORGEJO_ADMIN_USER/PASSWORD to generate token
2. **Manual token**: Uses FORGEJO_RUNNER_TOKEN if API fails
3. **Interactive**: Prompts for token if both methods fail

To get a manual token:
1. Access Forgejo web UI
2. Go to Site Administration → Actions → Runners
3. Click "Create new Runner" and copy the token
4. Set `FORGEJO_RUNNER_TOKEN` in `.env`
5. Restart runner: `docker-compose restart runner-ubuntu`

## Using Tunnelmole

To expose Forgejo publicly:

```bash
docker-compose --profile tunnel up -d
docker-compose logs -f tunnelmole
```

Look for output like:
```
https://abc123.tunnelmole.net is forwarding to http://forgejo:3000
```

Use this URL to access Forgejo from anywhere.

## Troubleshooting

**Runner not registering:**
- Check runner logs: `docker-compose logs runner-ubuntu`
- Verify admin credentials match Forgejo setup
- Try manual token registration

**Registry connection issues:**
- Ensure registry is running: `docker-compose ps registry`
- Check registry URL in .env matches your setup
- For external registry, ensure it's accessible from Docker network

**Yocto build failures:**
- Verify shared cache directories exist and are writable
- Check runner has access to Docker socket
- Review runner logs for specific errors

**Tunnelmole not working:**
- Check tunnelmole logs: `docker-compose logs tunnelmole`
- Ensure forgejo service is running
- Free tier has bandwidth limits

## Stopping Services

```bash
# Stop all services
docker-compose --profile registry --profile tunnel down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose --profile registry --profile tunnel down -v
```
