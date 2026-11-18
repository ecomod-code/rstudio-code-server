# ecomod-server

Deployment repository for the **ecomod research server stack**.

This stack provides a lightweight remote research environment consisting of:

- **RStudio Server**
- **VS Code (code-server)**
- **Caddy reverse proxy with automatic HTTPS (Let's Encrypt)**

All services run in **Docker containers** and are orchestrated using **Docker Compose**.

The repository is designed so the **same deployment artifacts** can be used for:

- provisioning **new machines via cloud-init**
- **manual migration** of existing servers
- **routine updates**

# Architecture

```
Internet
   │
   ▼
┌───────────────┐
│     Caddy     │  (TLS termination + routing)
└───────┬───────┘
        │
        ├─────────────► RStudio Server
        │               (port 8787)
        │
        └─────────────► code-server (VS Code)
                        (port 8443)
```

Routing:

| URL | Service |
|----|----|
| `/` | RStudio |
| `/code/` | VS Code |

Caddy automatically obtains and renews TLS certificates via **Let's Encrypt**.


# Repository Layout

```
ecomod-server/
├── .env.example
├── docker-compose.yaml
├── Caddyfile
├── scripts/
│   ├── install-prereqs.sh
│   ├── prepare-directories.sh
│   ├── start-stack.sh
│   ├── update-stack.sh
│   └── setup-nextcloud-sync.sh
├── docs/
│   ├── migration-guide.md
│   └── nextcloud-sync.md
└── cloud-init/
    └── cloud-init.yaml
```

## Key Files

### `.env.example`

Template for per-server configuration.

Copy to `.env` and adjust values.

### `docker-compose.yaml`

Defines the service stack:

- `caddy`
- `rstudio`
- `code-server`

The RStudio and code-server images are built in their own repositories and published on Docker Hub:

| Service | Image | Source |
|----|----|----|
| `rstudio` | [`ecomod/rstudio`](https://hub.docker.com/r/ecomod/rstudio) | https://github.com/ecomod-code/rstudio-docker |
| `code-server` | [`ecomod/code-server`](https://hub.docker.com/r/ecomod/code-server) | https://github.com/ecomod-code/code-server |

### `Caddyfile`

Reverse proxy configuration and TLS setup.

### `scripts/`

Operational scripts for convenience.

| Script | Purpose |
|------|------|
| `install-prereqs.sh` | installs Docker and required packages |
| `prepare-directories.sh` | creates persistent storage directories |
| `start-stack.sh` | launches the stack |
| `update-stack.sh` | updates container images |
| `setup-nextcloud-sync.sh` | optional: syncs a Nextcloud folder into the workspace |

# Quick Start (Manual Deployment)

## 1 Install prerequisites

```
./scripts/install-prereqs.sh
```

## 2 Configure environment

```
cp .env.example .env
nano .env
chmod 600 .env
```

## 3 Start the stack

```
./scripts/start-stack.sh
```

---

# Access

After startup:

| Service | URL |
|------|------|
| RStudio | https://SERVER_URL/ |
| VS Code | https://SERVER_URL/code/ |

Credentials:

```
username: rstudio
password: USER_PASSWORD
```

# Updating the Stack

Pull new container images and restart services:

```
./scripts/update-stack.sh
```

# Logs and Status

Check running services:

```
docker compose ps
```

Follow logs:

```
docker compose logs -f --tail=200
```

Check Caddy specifically:

```
docker compose logs -f --tail=200 caddy
```

# Persistent Data

Persistent data is stored under:

```
volumes/
├── workspace
├── code_config
├── caddy_data
└── caddy_config
```

These directories contain:

| Directory | Purpose |
|----|----|
| `workspace` | shared working directory for RStudio and VS Code |
| `code_config` | VS Code configuration |
| `caddy_data` | TLS certificates |
| `caddy_config` | Caddy runtime configuration |

These directories are not part of the Git repo.

# Nextcloud Sync (optional)

`scripts/setup-nextcloud-sync.sh` syncs one folder of the user's Nextcloud (default `/RStudio-Server`) two-way into `volumes/workspace/RStudio-Server`, i.e. `~/RStudio-Server` in RStudio and VS Code. It runs every 15 minutes via a systemd timer.

Enable it on a running server (prompts for instance URL, app username and app password; re-run to change them):

```
./scripts/setup-nextcloud-sync.sh
```

Operate it:

```
sudo systemctl start --no-block nextcloud-sync.service   # sync now
journalctl -u nextcloud-sync -f                          # logs
sudo systemctl disable --now nextcloud-sync.timer        # disable
```

What users need to do (app password, folder, rules for the synced folder): [docs/nextcloud-sync.md](docs/nextcloud-sync.md).

# Cloud‑Init Deployment

New VMs can automatically provision the server stack via:

```
cloud-init/cloud-init.yaml
```

The cloud-init configuration:

1. clones this repository
2. writes the `.env` file
3. runs the same repo scripts used for manual deployment
4. optionally sets up the Nextcloud sync — fill in `NC_URL`, `NC_USER` and `NC_APP_PASSWORD`, or leave them empty to skip it

