# ecomod server migration

This guide assumes:

- DNS already points to the target server
- ports 80 and 443 are reachable
- Docker is not yet installed

## 1. Install prerequisites

```bash
./scripts/install-prereqs.sh
```

## 2. Copy the deployment directory to the target server

Example:

```bash
rsync -av ecomod-server/ user@target:/srv/ecomod-server/
```

## 3. Configure the environment

```bash
cd /srv/ecomod-server
cp .env.example .env
nano .env
chmod 600 .env
```

## 4. Start the stack

```bash
./scripts/start-stack.sh
```

## 5. Verify

```bash
docker compose ps
docker compose logs -f --tail=200 caddy
```

The services should then be reachable at:

- `https://SERVER_URL/` for RStudio
- `https://SERVER_URL/code/` for code-server
