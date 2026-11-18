#!/usr/bin/env bash
set -euo pipefail

# Writes ecomod-specific metrics for node_exporter's textfile collector.
# Installed and run every minute by setup-monitoring-agent.sh; not meant to be
# run by hand. Everything generic (disk, RAM, CPU, OOM kills, OS and kernel
# version, boot time) already comes from node_exporter itself.

BASE="${ECOMOD_BASE:?ECOMOD_BASE not set}"
OUT_DIR=/var/lib/prometheus/node-exporter
STATE_DIR=/var/lib/ecomod-monitoring

mkdir -p "$OUT_DIR" "$STATE_DIR"
# Written next to the target and renamed, so node_exporter never reads a
# half-written file.
tmp="$(mktemp "$OUT_DIR/.ecomod.prom.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }
newest_mtime() {
  local t
  t="$(find "$1" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)"
  echo "${t%.*}"
}

{
  # Last activity, 0 = never. RStudio has no heartbeat file, but its state
  # dir changes while someone works (session start, editor autosave).
  # code-server touches its heartbeat file on every request - including
  # unauthenticated ones, so uptime checks must not hit /code/ itself.
  rstudio="$(newest_mtime "$BASE/volumes/workspace/.local/share/rstudio")"
  echo "# HELP ecomod_last_activity_timestamp_seconds Last user activity per IDE (0 = never)."
  echo "# TYPE ecomod_last_activity_timestamp_seconds gauge"
  echo "ecomod_last_activity_timestamp_seconds{app=\"rstudio\"} ${rstudio:-0}"
  echo "ecomod_last_activity_timestamp_seconds{app=\"code-server\"} $(mtime "$BASE/volumes/code_config/.local/share/code-server/heartbeat")"

  # Ubuntu creates this file when an installed update (e.g. a kernel) needs
  # a reboot to take effect.
  echo "# HELP ecomod_reboot_required 1 if installed updates wait for a reboot."
  echo "# TYPE ecomod_reboot_required gauge"
  echo "ecomod_reboot_required $([[ -f /var/run/reboot-required ]] && echo 1 || echo 0)"

  # Containers of any compose project on this host. The restart count resets
  # whenever a container is recreated, e.g. by update-stack.sh.
  ids="$(docker ps -aq --filter label=com.docker.compose.service 2>/dev/null || true)"
  echo "# HELP ecomod_container_running 1 if the compose service's container is running."
  echo "# TYPE ecomod_container_running gauge"
  echo "# HELP ecomod_container_restart_count Restarts of the container since it was created."
  echo "# TYPE ecomod_container_restart_count gauge"
  if [[ -n "$ids" ]]; then
    # shellcheck disable=SC2086 # word splitting of the id list is intended
    docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}} {{.State.Running}} {{.RestartCount}}' $ids |
      while read -r service running restarts; do
        echo "ecomod_container_running{service=\"$service\"} $([[ "$running" == true ]] && echo 1 || echo 0)"
        echo "ecomod_container_restart_count{service=\"$service\"} $restarts"
      done
  fi

  # Nextcloud sync (setup-nextcloud-sync.sh). systemd only remembers the
  # latest run, so the time of the last successful one is kept in a state
  # file and survives failed runs.
  echo "# HELP ecomod_nextcloud_sync_enabled 1 if the sync timer is enabled."
  echo "# TYPE ecomod_nextcloud_sync_enabled gauge"
  if systemctl is-enabled --quiet nextcloud-sync.timer 2>/dev/null; then
    echo "ecomod_nextcloud_sync_enabled 1"
    result="$(systemctl show -p Result --value nextcloud-sync.service)"
    exit_ts="$(systemctl show --timestamp=unix -p ExecMainExitTimestamp --value nextcloud-sync.service)"
    if [[ "$result" == success && -n "$exit_ts" ]]; then
      echo "${exit_ts#@}" > "$STATE_DIR/nextcloud-sync-last-success"
    fi
    echo "# HELP ecomod_nextcloud_sync_last_success_timestamp_seconds End of the last successful sync (0 = none yet)."
    echo "# TYPE ecomod_nextcloud_sync_last_success_timestamp_seconds gauge"
    echo "ecomod_nextcloud_sync_last_success_timestamp_seconds $(cat "$STATE_DIR/nextcloud-sync-last-success" 2>/dev/null || echo 0)"
    echo "# HELP ecomod_nextcloud_sync_last_run_failed 1 if the latest sync run failed."
    echo "# TYPE ecomod_nextcloud_sync_last_run_failed gauge"
    echo "ecomod_nextcloud_sync_last_run_failed $([[ "$result" == success ]] && echo 0 || echo 1)"
  else
    echo "ecomod_nextcloud_sync_enabled 0"
  fi
} > "$tmp"

chmod 644 "$tmp"
mv "$tmp" "$OUT_DIR/ecomod.prom"
