#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="$SCRIPT_DIR/config.json"
SERVICE_NAME="backup.service"
TIMER_NAME="backup.timer"

usage() {
  cat <<EOF
1) Edit config
2) Run backup now
3) Install service (systemd)
4) Uninstall service
5) Show latest backups
6) Show timer status
7) Edit timer schedule (config.timer.on_calendar)
8) Enable timer
9) Disable timer
10) Start timer now
11) Stop timer
12) Reload timer units
13) Apply timer from config (recreate timer unit)
0) Exit
EOF
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required. Install: sudo apt update && sudo apt install -y jq"
    exit 1
  fi
}

edit_config() {
  ${EDITOR:-nano} "$CONFIG"
}

run_backup_now() {
  sudo systemctl start "$SERVICE_NAME"
  sudo journalctl -u "$SERVICE_NAME" --no-pager -n 50
}

install_service() {
  sudo bash "$SCRIPT_DIR/install_service.sh"
}

uninstall_service() {
  sudo systemctl stop "$SERVICE_NAME" || true
  sudo systemctl disable "$SERVICE_NAME" || true
  sudo systemctl stop "$TIMER_NAME" || true
  sudo systemctl disable "$TIMER_NAME" || true
  sudo rm -f /etc/systemd/system/"$SERVICE_NAME" /etc/systemd/system/"$TIMER_NAME"
  sudo systemctl daemon-reload
  echo "Service and timer removed."
}

show_latest_backups() {
  outdir=$(jq -r '.output_dir' "$CONFIG")
  ls -1t "${outdir}" | head -n 10
}

show_timer_status() {
  echo "=== systemctl status $TIMER_NAME ==="
  sudo systemctl status "$TIMER_NAME" --no-pager || true
  echo
  echo "=== is-enabled ==="
  sudo systemctl is-enabled "$TIMER_NAME" 2>/dev/null || echo "disabled"
  echo
  echo "=== next triggers (list-timers) ==="
  sudo systemctl list-timers --all | grep -E "$(basename "$TIMER_NAME" .timer)|$TIMER_NAME" || true
  echo
  echo "=== last service logs ==="
  sudo journalctl -u "$SERVICE_NAME" -n 30 --no-pager || true
}

edit_timer_schedule() {
  require_jq
  read -rp "New OnCalendar (e.g. daily or '*-*-* 03:00:00'): " NEW
  if [ -z "$NEW" ]; then
    echo "Empty. Aborted."
    return
  fi
  tmp=$(mktemp)
  # ensure .timer exists and set on_calendar
  jq --arg v "$NEW" '.timer |= (. // {}) | .timer.on_calendar = $v' "$CONFIG" >"$tmp" && mv "$tmp" "$CONFIG"
  echo "Updated config.timer.on_calendar -> $NEW"
  echo "To apply change run option 13 (Apply timer from config) or run install_service.sh"
}

enable_timer() {
  sudo systemctl enable --now "$TIMER_NAME"
  sudo systemctl daemon-reload
  echo "Timer enabled and started."
}

disable_timer() {
  sudo systemctl disable --now "$TIMER_NAME" || true
  sudo systemctl daemon-reload
  echo "Timer disabled."
}

start_timer_now() {
  sudo systemctl start "$TIMER_NAME"
  echo "Timer started."
}

stop_timer() {
  sudo systemctl stop "$TIMER_NAME" || true
  echo "Timer stopped."
}

reload_timer_units() {
  sudo systemctl daemon-reload
  sudo systemctl restart "$TIMER_NAME" || true
  echo "Daemon reloaded. Timer restarted if exists."
}

apply_timer_from_config() {
  if [ -x "$SCRIPT_DIR/install_service.sh" ]; then
    sudo bash "$SCRIPT_DIR/install_service.sh"
    echo "install_service.sh applied. Check systemctl status $TIMER_NAME"
  else
    echo "install_service.sh not found or not executable in $SCRIPT_DIR"
  fi
}

# Main
if [ ! -f "$CONFIG" ]; then
  echo "Config $CONFIG not found. Create it first."
  exit 1
fi

usage
read -rp "Choice: " CH
case "$CH" in
  1) edit_config ;;
  2) run_backup_now ;;
  3) install_service ;;
  4) uninstall_service ;;
  5) show_latest_backups ;;
  6) show_timer_status ;;
  7) edit_timer_schedule ;;
  8) enable_timer ;;
  9) disable_timer ;;
  10) start_timer_now ;;
  11) stop_timer ;;
  12) reload_timer_units ;;
  13) apply_timer_from_config ;;
  0) echo "Exit" ;;
  *) echo "Invalid choice" ;;
esac
