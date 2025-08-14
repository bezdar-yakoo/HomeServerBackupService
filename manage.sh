#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="$SCRIPT_DIR/config.json"
SERVICE_NAME="backup.service"
SERVICE_FILE="$SCRIPT_DIR/backup.service"

echo "1) Edit config"
echo "2) Run backup now"
echo "3) Install service (systemd)"
echo "4) Uninstall service"
echo "5) Show latest backups"
echo "6) Exit"
read -rp "Choice: " CH
case "$CH" in
  1) ${EDITOR:-nano} "$CONFIG" ;;
  2) sudo bash "$SCRIPT_DIR/backup.sh" ;;
  3) sudo bash "$SCRIPT_DIR/install_service.sh" ;;
  4) sudo systemctl stop backup.service || true; sudo systemctl disable backup.service || true; sudo rm -f /etc/systemd/system/backup.service; sudo systemctl daemon-reload; echo "Service uninstalled" ;;
  5) ls -1t $(jq -r '.output_dir' "$CONFIG") | head -n 10 ;;
  *) echo "Exit" ;;
esac