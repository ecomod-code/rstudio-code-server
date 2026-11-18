#!/usr/bin/env bash
set -euo pipefail

# Optional two-way sync of one Nextcloud folder into the shared workspace,
# via nextcloudcmd on a systemd timer. Safe to re-run (e.g. to change the
# account or the app password).
#
# Values come from the environment, or are prompted for when run interactively:
#   NC_URL           concrete instance URL, e.g. https://<inst>.academiccloud.de
#                    (files.academiccloud.de only redirects; the CLI can't use it)
#   NC_USER          username shown when the app password was created
#   NC_APP_PASSWORD  app password (SSO logins don't work for the CLI)
#   NC_REMOTE_PATH   remote folder, default /RStudio-Server
#
# Without NC_URL/NC_USER/NC_APP_PASSWORD and without a terminal (cloud-init),
# it does nothing, so a VM can be provisioned first and the sync enabled later:
#   ./scripts/setup-nextcloud-sync.sh

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE"

NC_URL="${NC_URL:-}"
NC_USER="${NC_USER:-}"
NC_APP_PASSWORD="${NC_APP_PASSWORD:-}"
NC_REMOTE_PATH="${NC_REMOTE_PATH:-/RStudio-Server}"

if [[ -z "$NC_URL" || -z "$NC_USER" || -z "$NC_APP_PASSWORD" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Nextcloud sync not configured (NC_URL/NC_USER/NC_APP_PASSWORD unset) - skipping."
    exit 0
  fi
  [[ -n "$NC_URL" ]]  || read -rp "Nextcloud instance URL (https://<inst>.academiccloud.de): " NC_URL
  [[ -n "$NC_USER" ]] || read -rp "App password username: " NC_USER
  [[ -n "$NC_APP_PASSWORD" ]] || { read -rsp "App password: " NC_APP_PASSWORD; echo; }
fi

NC_URL="${NC_URL%/}"
NC_HOST="${NC_URL#*://}"
NC_HOST="${NC_HOST%%/*}"
if [[ "$NC_HOST" == "files.academiccloud.de" ]]; then
  echo "ERROR: files.academiccloud.de only redirects to your institution's instance." >&2
  echo "       Use the concrete URL, e.g. https://<inst>.academiccloud.de." >&2
  exit 1
fi
NC_REMOTE_PATH="/${NC_REMOTE_PATH#/}"
NC_REMOTE_PATH="${NC_REMOTE_PATH%/}"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and edit it first." >&2
  exit 1
fi
set -a
source "$BASE/.env"
set +a

# Run the sync as the host account behind PUID, the uid code-server writes as,
# so synced files and files created in the IDEs have the same owner.
SYNC_USER="$(getent passwd "$PUID" | cut -d: -f1)"
if [[ -z "$SYNC_USER" ]]; then
  echo "ERROR: no host account with uid PUID=$PUID (from .env)." >&2
  exit 1
fi
SYNC_HOME="$(getent passwd "$SYNC_USER" | cut -d: -f6)"

# Named after the remote folder, so users find the same name on both sides.
LOCAL_DIR="$BASE/volumes/workspace/$(basename "$NC_REMOTE_PATH")"

sudo apt update
sudo apt install -y nextcloud-desktop-cmd

sudo mkdir -p "$LOCAL_DIR"
sudo chown "$PUID:$PGID" "$LOCAL_DIR"

# Credentials go into ~/.netrc, not the unit file, to keep them out of the
# process list and `systemctl cat`. Any previous entry for this host is
# replaced; entries for other hosts are kept.
NETRC="$SYNC_HOME/.netrc"
tmp="$(mktemp)"
if sudo test -f "$NETRC"; then
  sudo cp -a "$NETRC" "$NETRC.bak.$(date +%s)"
  sudo awk -v host="$NC_HOST" '
    $1 == "machine" { skip = ($2 == host) }
    !skip
  ' "$NETRC" > "$tmp"
fi
printf 'machine %s\nlogin %s\npassword %s\n' "$NC_HOST" "$NC_USER" "$NC_APP_PASSWORD" >> "$tmp"
sudo install -m 600 -o "$SYNC_USER" -g "$(id -gn "$SYNC_USER")" "$tmp" "$NETRC"
rm -f "$tmp"

# systemd timer rather than cron: a oneshot service never runs twice at once,
# so a long first sync can't overlap with the next run, and output lands in
# the journal (journalctl -u nextcloud-sync) instead of /dev/null.
sudo tee /etc/systemd/system/nextcloud-sync.service >/dev/null <<EOF
[Unit]
Description=Sync ${NC_REMOTE_PATH} from ${NC_HOST} into ${LOCAL_DIR}
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=${SYNC_USER}
Nice=10
IOSchedulingClass=idle
ExecStart=/usr/bin/nextcloudcmd -n --non-interactive --path "${NC_REMOTE_PATH}" "${LOCAL_DIR}" "${NC_URL}"
EOF

# OnUnitInactiveSec counts from the end of the previous run, so runs never
# queue up back to back.
sudo tee /etc/systemd/system/nextcloud-sync.timer >/dev/null <<'EOF'
[Unit]
Description=Periodic Nextcloud sync

[Timer]
OnBootSec=2min
OnUnitInactiveSec=15min

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now nextcloud-sync.timer

echo
echo "Nextcloud sync enabled: ${NC_URL}${NC_REMOTE_PATH} <-> ${LOCAL_DIR}"
echo "  Run now:  sudo systemctl start nextcloud-sync.service"
echo "  Logs:     journalctl -u nextcloud-sync -f"
echo "  Disable:  sudo systemctl disable --now nextcloud-sync.timer"
