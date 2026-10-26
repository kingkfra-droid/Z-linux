# Z-Linux OS Core — Agent Notes

## What This App Is

A full-stack cybersecurity command dashboard built on top of the Z-Linux distro toolkit repo. The original repo contains shell scripts for building a Debian rootfs / bootable ISOs (Termux/proot based). The web app was added as `web/` (React + Vite frontend) and `api/` (Node.js + Express backend with JSON file storage).

## Architecture

- **Frontend** (`web/`): React 18 + Vite 6. Served on port 3000. Proxies `/api` to the backend via Vite dev server proxy. Dark cyber-deck theme with neon-cyan/emerald accents.
- **Backend** (`api/`): Express with JSON file persistence (`api/data/`). No external database. Served on port 8000. Uses `node --watch` for hot reload.
- **Compose**: `docker-compose.base44.yml` runs both services from `node:22-slim`, bind-mounts the source, installs deps on startup.

## Running

```sh
docker compose -f docker-compose.base44.yml up -d
```

- Web: http://localhost:3000
- API: http://localhost:8000/api/health

## Key Details

- No external secrets or credentials needed — fully self-contained.
- API data persists in `api/data/*.json` (auto-created on first run from seed data in `api/seed.js`).
- Vite uses `allowedHosts: true` and `watch.usePolling: true` for Docker bind-mount compatibility.
- The `__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS` env var is passed through from the platform.
- Both services have healthchecks using Node's built-in `fetch` API.

## Views

1. **Dashboard** — system stats (CPU/RAM/scans/tunnels), quick-launcher grid, recent activity log
2. **Tool Arsenal** — 20 seeded security tools across 5 categories, searchable, with Run/Install actions
3. **Target Mapper** — network topology, target list with add/delete, port table, vulnerability cards, scan trigger
4. **Payload Studio** — payload generator form (msfvenom-style), generated payload list, listener management
5. **Terminal** — bottom drawer streaming real-time scan/tool logs
