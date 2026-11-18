#!/usr/bin/env bash
set -euo pipefail

# VM side of the monitoring: node_exporter on port 9100, scraped by the
# central Prometheus, plus collect-metrics.sh for the ecomod-specific values
# (last IDE activity, reboot pending, containers, Nextcloud sync). Works on its
# own; the central server picks the VM up once it is in its targets file.
# Safe to re-run, e.g. to install an updated collect-metrics.sh.
#
# node_exporter has no authentication: restrict port 9100 to the monitoring
# VM via the OpenStack security group.

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo apt update
sudo apt install -y --no-install-recommends prometheus-node-exporter

# A copy outside the repo: it runs as root, so it should not be editable by
# the account that owns the checkout.
sudo install -D -m 755 "$BASE/scripts/collect-metrics.sh" /usr/local/lib/ecomod-monitoring/collect-metrics.sh

sudo tee /etc/systemd/system/ecomod-metrics.service >/dev/null <<EOF
[Unit]
Description=Collect ecomod metrics for node_exporter

[Service]
Type=oneshot
Environment=ECOMOD_BASE=${BASE}
ExecStart=/usr/local/lib/ecomod-monitoring/collect-metrics.sh
EOF

sudo tee /etc/systemd/system/ecomod-metrics.timer >/dev/null <<'EOF'
[Unit]
Description=Collect ecomod metrics every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus-node-exporter.service
sudo systemctl enable --now ecomod-metrics.timer

echo
echo "Monitoring agent enabled: node_exporter on port 9100."
echo "  Check:  curl -s localhost:9100/metrics | grep ^ecomod_"
echo "  Logs:   journalctl -u ecomod-metrics"
