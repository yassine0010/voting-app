#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------
# Config (edit as you like)
# -----------------------------
CONTAINER_NAME="${1:-}"          # optional 1st arg: container name for docker logs
TOP_N=5                          # how many top processes to show
DOCKER_LOG_LINES=80              # tail for docker container logs
JOURNAL_LINES=120                # tail for docker.service logs
WATCH_SOURCE="${2:-docker}"      # optional 2nd arg: docker | syslog | journal-docker
KEYWORDS_REGEX='ERROR|FAIL|OOM|Killed'  # alert keywords (case-insensitive)

# Services to check (systemd service names)
SERVICES=("docker" "nginx" "ssh" "sshd")

# -----------------------------
# Helpers
# -----------------------------
ok()   { printf "OK   - %s\n" "$*"; }
fail() { printf "FAIL - %s\n" "$*"; }
line() { printf "\n%s\n" "============================================================"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

check_service() {
  local svc="$1"
  if systemctl list-unit-files --type=service 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"; then
    if systemctl is-active --quiet "$svc"; then
      ok "service '$svc' is running"
    else
      fail "service '$svc' is NOT running. Suggestion: sudo systemctl status $svc && sudo systemctl start $svc"
    fi
  else
    # Service not installed / not known on this machine
    # Not necessarily an error; depends on your host
    fail "service '$svc' not found on this system (may be normal). Suggestion: systemctl list-units --type=service | grep -i $svc"
  fi
}

show_top_processes() {
  line
  echo "Top ${TOP_N} processes by CPU:"
  ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu | head -n $((TOP_N + 1))

  line
  echo "Top ${TOP_N} processes by Memory (RAM):"
  ps -eo pid,user,comm,%mem,%cpu --sort=-%mem | head -n $((TOP_N + 1))
}

show_docker_stats() {
  line
  echo "Docker stats (one-shot):"
  if have_cmd docker; then
    if docker info >/dev/null 2>&1; then
      docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    else
      fail "Docker command exists but daemon not reachable. Suggestion: sudo systemctl status docker"
    fi
  else
    fail "docker command not found"
  fi
}

show_docker_container_logs() {
  line
  if [[ -z "$CONTAINER_NAME" ]]; then
    echo "Docker container logs: (skipped)  -> Provide container name as 1st arg:"
    echo "  ./ops_check.sh <container_name> [watch_source]"
    return
  fi

  echo "Docker logs for container: $CONTAINER_NAME (last ${DOCKER_LOG_LINES} lines)"
  if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    docker logs --tail "$DOCKER_LOG_LINES" "$CONTAINER_NAME" 2>&1 | sed 's/^/  /'
    ok "docker logs fetched for '$CONTAINER_NAME'"
  else
    fail "container '$CONTAINER_NAME' not running (or not found). Suggestion: docker ps -a | grep -i $CONTAINER_NAME"
  fi
}

show_docker_journal() {
  line
  echo "docker.service logs (journalctl -u docker) last ${JOURNAL_LINES} lines:"
  if have_cmd journalctl; then
    # journalctl may require sudo depending on distro/policies
    if journalctl -u docker -n 1 >/dev/null 2>&1; then
      journalctl -u docker -n "$JOURNAL_LINES" --no-pager | sed 's/^/  /'
      ok "docker.service journal read"
    else
      fail "cannot read docker.service journal (permissions?). Suggestion: sudo journalctl -u docker -n ${JOURNAL_LINES} --no-pager"
    fi
  else
    fail "journalctl not found"
  fi
}

check_services() {
  line
  echo "Service checks (OK/FAIL):"
  for svc in "${SERVICES[@]}"; do
    check_service "$svc"
  done
}

watch_logs_and_alert() {
  line
  echo "Watching logs for keywords (case-insensitive): $KEYWORDS_REGEX"
  echo "Source: $WATCH_SOURCE"
  echo "Press Ctrl+C to stop."

  if [[ "$WATCH_SOURCE" == "docker" ]]; then
    if [[ -z "$CONTAINER_NAME" ]]; then
      fail "watch_source=docker requires container name as 1st arg"
      return
    fi
    docker logs -f "$CONTAINER_NAME" 2>&1 | \
      grep -iE --line-buffered "$KEYWORDS_REGEX" | \
      while IFS= read -r match; do
        printf "\nALERT [%s] %s\n" "$(date '+%F %T')" "$match"
      done

  elif [[ "$WATCH_SOURCE" == "syslog" ]]; then
    local syslog_file="/var/log/syslog"
    if [[ -r "$syslog_file" ]]; then
      tail -Fn0 "$syslog_file" | \
        grep -iE --line-buffered "$KEYWORDS_REGEX" | \
        while IFS= read -r match; do
          printf "\nALERT [%s] %s\n" "$(date '+%F %T')" "$match"
        done
    else
      fail "cannot read $syslog_file. Suggestion: sudo tail -f $syslog_file"
    fi

  elif [[ "$WATCH_SOURCE" == "journal-docker" ]]; then
    if have_cmd journalctl; then
      journalctl -u docker -f -o cat 2>/dev/null | \
        grep -iE --line-buffered "$KEYWORDS_REGEX" | \
        while IFS= read -r match; do
          printf "\nALERT [%s] %s\n" "$(date '+%F %T')" "$match"
        done
    else
      fail "journalctl not found"
    fi

  else
    fail "Unknown WATCH_SOURCE='$WATCH_SOURCE'. Use: docker | syslog | journal-docker"
  fi
}

# -----------------------------
# Main
# -----------------------------
echo "Ops check starting: $(date '+%F %T')"
echo "Container: ${CONTAINER_NAME:-<none>}"

show_top_processes
show_docker_stats
show_docker_container_logs
show_docker_journal
check_services

# Watch mode (optional): uncomment to always watch at end
# watch_logs_and_alert

echo
echo "Done. Tip: run watch mode like:"
echo "  ./ops_check.sh <container_name> docker"
echo "  ./ops_check.sh <container_name> journal-docker"
echo "  ./ops_check.sh _ syslog" explain me ligne by ligne