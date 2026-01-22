# Forgejo for Yocto Development

Minimal Docker-based Forgejo setup for Yocto development with Actions runners, shared caches, and optional public access via Tunnelmole.

## Features

- Forgejo Git service (v14.0.1)
- Forgejo Actions runners with Yocto build environment
- Shared Yocto caches (sstate-cache, downloads) across builds
- Optional Hash Equivalence server for faster builds
- Optional HTTP sstate-cache server with password authentication
- Local Docker registry for runner images
- Optional Tunnelmole integration for public access
- Support for multiple OS-based runners (configurable via .env)

## Quick Reference

**Start all services including hash and sstate servers:**
```bash
docker-compose --profile registry --profile tunnel --profile hashserv --profile sstate-server up -d
```

**Use shared build cache in your Yocto builds:**
```bash
# Setup authentication (one-time)
cat > ~/.netrc << EOF
machine <server-ip>
login yocto
password changeme123
EOF
chmod 600 ~/.netrc

# Configure Yocto (add to local.conf or export in workflow)
SSTATE_MIRRORS = "file://.* http://<server-ip>:8080/sstate-cache/PATH"
PREMIRRORS:prepend = "git://.*/.* http://<server-ip>:8080/downloads/ \n"
PREMIRRORS:prepend = "ftp://.*/.* http://<server-ip>:8080/downloads/ \n"
PREMIRRORS:prepend = "http://.*/.* http://<server-ip>:8080/downloads/ \n"
PREMIRRORS:prepend = "https://.*/.* http://<server-ip>:8080/downloads/ \n"
BB_HASHSERVE = "wss://<server-ip>:8686/ws"
BB_SIGNATURE_HANDLER = "OEEquivHash"
BB_HASHSERVE_UPSTREAM = "wss://hashserv.yoctoproject.org/ws"
```

Replace `<server-ip>` with your server's IP address.

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

4. **Optional: Start Hash Equivalence and Sstate servers**
   ```bash
   docker-compose --profile hashserv --profile sstate-server up -d
   ```

5. **Run automated setup**
   ```bash
   ./setup-forgejo.sh
   ```
   
   This creates the admin user account with a random password.

6. **Access Forgejo**
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

The registry is password protected and accessible on the network:

```bash
# Login to registry
docker login 172.31.34.190:5000
# Username: yocto
# Password: changeme123

# Build and push runner image
docker build -f Dockerfile.yocto-runner-ubuntu-22.04 -t 172.31.34.190:5000/yocto-runner-ubuntu-22.04:latest .
docker push 172.31.34.190:5000/yocto-runner-ubuntu-22.04:latest
```

**To change registry password:**
```bash
docker run --rm --entrypoint htpasswd httpd:alpine -Bbn yocto <new-password> > registry-htpasswd
docker-compose --profile registry restart
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
├── hashserv-data/          # Hash equivalence server database
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

## Using Hash Equivalence Server

The hash equivalence server speeds up builds by reusing build outputs with equivalent inputs. To enable:

1. **Start the server:**
   ```bash
   docker-compose --profile hashserv up -d
   ```

2. **Configure your Yocto build** (in `local.conf` or workflow):
   ```bash
   BB_HASHSERVE = "wss://<server-ip>:8686/ws"
   BB_SIGNATURE_HANDLER = "OEEquivHash"
   ```
   
   Replace `<server-ip>` with your server's IP address or hostname (e.g., `172.31.34.190`).

3. **Optional: Use upstream server** for additional cache hits:
   ```bash
   BB_HASHSERVE_UPSTREAM = "wss://hashserv.yoctoproject.org/ws"
   ```

The server runs in read-only mode to prevent clients from storing local equivalences. This ensures only equivalences for the shared sstate-cache are served.

## Using HTTP Sstate-Cache Server

Share your sstate-cache over HTTP with password authentication:

1. **Generate password file** (first time only):
   ```bash
   docker run --rm httpd:alpine htpasswd -nbB yocto <your-password> > sstate-htpasswd
   ```
   
   Default credentials are already generated: `yocto` / `changeme123`

2. **Start the server:**
   ```bash
   docker-compose --profile sstate-server up -d
   ```

3. **Configure authentication** on the client machine (where you run Yocto builds):
   ```bash
   # Create ~/.netrc for HTTP authentication
   cat > ~/.netrc << EOF
   machine <server-ip>
   login yocto
   password changeme123
   EOF
   chmod 600 ~/.netrc
   ```
   
   Replace `<server-ip>` with your server's IP address (e.g., `172.31.34.190`).

4. **Configure your Yocto build** (in `local.conf` or workflow):
   ```bash
   SSTATE_MIRRORS = "file://.* http://<server-ip>:8080/sstate-cache/PATH"
   PREMIRRORS:prepend = "git://.*/.* http://<server-ip>:8080/downloads/ \n"
   PREMIRRORS:prepend = "ftp://.*/.* http://<server-ip>:8080/downloads/ \n"
   PREMIRRORS:prepend = "http://.*/.* http://<server-ip>:8080/downloads/ \n"
   PREMIRRORS:prepend = "https://.*/.* http://<server-ip>:8080/downloads/ \n"
   ```

5. **Complete example** for workflow (combines both hash server and sstate server):
   ```bash
   # Setup authentication
   cat > ~/.netrc << EOF
   machine 172.31.34.190
   login yocto
   password changeme123
   EOF
   chmod 600 ~/.netrc
   
   # Configure Yocto
   export SSTATE_MIRRORS="file://.* http://172.31.34.190:8080/sstate-cache/PATH"
   export PREMIRRORS="git://.*/.* http://172.31.34.190:8080/downloads/ \n ftp://.*/.* http://172.31.34.190:8080/downloads/ \n http://.*/.* http://172.31.34.190:8080/downloads/ \n https://.*/.* http://172.31.34.190:8080/downloads/ \n"
   export BB_HASHSERVE="wss://172.31.34.190:8686/ws"
   export BB_SIGNATURE_HANDLER="OEEquivHash"
   export BB_HASHSERVE_UPSTREAM="wss://hashserv.yoctoproject.org/ws"
   export BB_ENV_PASSTHROUGH_ADDITIONS="$BB_ENV_PASSTHROUGH_ADDITIONS SSTATE_MIRRORS PREMIRRORS BB_HASHSERVE BB_SIGNATURE_HANDLER BB_HASHSERVE_UPSTREAM"
   ```

**Server Details:**
- Hash Equivalence: WebSocket on port 8686 (read-only mode)
- Sstate Cache: HTTP on port 8080 at `/sstate-cache/` (password protected, read-only)
- Downloads Cache: HTTP on port 8080 at `/downloads/` (password protected, read-only)
- All servers provide read-only access to shared build artifacts

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
