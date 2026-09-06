#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  ca-certificates \
  curl \
  git \
  docker.io \
  docker-compose-v2 \
  jq

# GWDG cloud VMs run a 1450-byte MTU (VXLAN overlay). Docker's default bridge is
# 1500, so bulk TLS over it black-holes: image pulls and `docker build` hang and
# time out (curl exit 28).
#
# Two settings are needed, because Docker does NOT propagate `mtu` to
# user-defined networks (verified on 29.1.3 - a network created without an
# explicit option comes up at 1500 regardless):
#   mtu                 -> docker0, used by `docker build`, `docker pull`,
#                          and any bare `docker run`
#   default-network-opts -> every bridge network created afterwards, including
#                          the ones Docker Compose creates per project
#
# A per-network com.docker.network.driver.mtu still overrides this, so an
# individual compose file can opt out if it ever needs to.
MTU=1450
sudo mkdir -p /etc/docker
DAEMON_MTU_CFG="$(cat <<JSON
{
  "mtu": ${MTU},
  "default-network-opts": {
    "bridge": { "com.docker.network.driver.mtu": "${MTU}" }
  }
}
JSON
)"
if [ -f /etc/docker/daemon.json ]; then
  # Existing config (likely a manual migration): deep-merge, don't clobber.
  sudo cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%s)"
  tmp="$(mktemp)"
  printf '%s' "$DAEMON_MTU_CFG" | sudo jq -s '.[0] * .[1]' /etc/docker/daemon.json - > "$tmp"
  sudo mv "$tmp" /etc/docker/daemon.json
else
  printf '%s\n' "$DAEMON_MTU_CFG" | sudo tee /etc/docker/daemon.json >/dev/null
fi
sudo chmod 0644 /etc/docker/daemon.json

sudo systemctl enable docker
# restart, not start: the package install already brought the daemon up, and it
# needs to re-read daemon.json for the MTU to take effect.
sudo systemctl restart docker

# start-stack.sh runs `docker compose` as the invoking user, which needs group
# membership to reach the daemon socket. Harmless when already a member, and a
# no-op for root (cloud-init runs this as root and adds the user separately).
if [ "$(id -u)" -ne 0 ]; then
  sudo usermod -aG docker "$USER"
  if ! id -nG | tr ' ' '\n' | grep -qx docker; then
    echo
    echo "NOTE: '$USER' was just added to the 'docker' group."
    echo "      Log out and back in (or run 'newgrp docker') before ./scripts/start-stack.sh."
  fi
fi
