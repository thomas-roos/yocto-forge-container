# Script Consolidation Migration

## What Changed

Consolidated 7 scripts → 3 scripts for simpler workflow.

## New Scripts

1. **setup.sh** - One-time setup (replaces `generate-compose.sh` + `setup-forgejo.sh`)
2. **manage.sh** - Daily operations (replaces `start.sh` + `cleanup.sh`)
3. **runner-entrypoint.sh** - Updated to handle CROPS logic (replaces `runner-entrypoint-crops.sh`)

## Deprecated Scripts (can be removed)

- `generate-compose.sh` → merged into `setup.sh`
- `setup-forgejo.sh` → merged into `setup.sh`
- `start.sh` → replaced by `manage.sh start`
- `cleanup.sh` → replaced by `manage.sh clean`
- `runner-entrypoint-crops.sh` → merged into `runner-entrypoint.sh`
- `register-runner.sh` → functionality in `runner-entrypoint.sh` error messages

## Command Migration

| Old Command | New Command |
|-------------|-------------|
| `./generate-compose.sh && ./start.sh && ./setup-forgejo.sh` | `./setup.sh` |
| `./start.sh` | `./manage.sh start` |
| `./start.sh --tunnel` | `./manage.sh start --tunnel` |
| `./cleanup.sh` | `./manage.sh stop` |
| `./cleanup.sh --clean-data` | `./manage.sh clean` |
| `podman-compose logs -f` | `./manage.sh logs` |
| `podman-compose logs forgejo` | `./manage.sh logs forgejo` |
| `podman-compose ps` | `./manage.sh ps` |
| `podman-compose restart` | `./manage.sh restart` |
| `podman-compose --profile hashserv up -d` | `./manage.sh cache-start` |
| `podman-compose --profile hashserv down` | `./manage.sh cache-stop` |

## Testing

The system is currently running. To test:

```bash
# Stop current services
./manage.sh stop

# Restart with new scripts
./manage.sh start

# Check status
./manage.sh ps
./manage.sh logs
```

## Cleanup (after testing)

```bash
rm -f generate-compose.sh setup-forgejo.sh start.sh cleanup.sh \
      runner-entrypoint-crops.sh register-runner.sh
```
