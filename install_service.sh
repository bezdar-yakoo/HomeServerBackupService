#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVICE_DEST="/etc/systemd/system/backup.service"
TIMER_DEST="/etc/systemd/system/backup.timer"
BIN_DEST="/usr/local/bin/backup.sh"
INSTALL_DIR="/home/yakoo/HomeServerBackupService"
SERVICE_USER="backup"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install: sudo apt update && sudo apt install -y jq"
  exit 1
fi

# create system user if missing
if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
fi

sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"

CONFIG="$INSTALL_DIR/config.json"
if [ ! -f "$CONFIG" ]; then
  echo "Config file $CONFIG not found. Adjust and re-run."
  exit 1
fi

OUTPUT_DIR=$(jq -r '.output_dir // "/var/backups/backup-service"' "$CONFIG")
TMP_BASE=$(jq -r '.tmp_base // "/tmp/backup-service"' "$CONFIG")

mapfile -t INCLUDE_DIRS < <(jq -r '.include_dirs[]? | select(.!=null)' "$CONFIG" 2>/dev/null || true)
mapfile -t EXTRA_DIRS < <(jq -r '.extra_dirs[]? | select(.!=null)' "$CONFIG" 2>/dev/null || true)

sudo mkdir -p "$OUTPUT_DIR"
sudo mkdir -p "$TMP_BASE"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$OUTPUT_DIR"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$TMP_BASE"
sudo chmod 750 "$OUTPUT_DIR" "$TMP_BASE"

for d in "${INCLUDE_DIRS[@]:-}"; do
  [ -z "$d" ] && continue
  if [ -e "$d" ]; then
    echo "Include dir exists: $d"
  else
    echo "Include dir not found, creating: $d"
    sudo mkdir -p "$d"
    sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$d"
    sudo chmod 750 "$d"
  fi
done

for d in "${EXTRA_DIRS[@]:-}"; do
  [ -z "$d" ] && continue
  if [ -e "$d" ]; then
    echo "Extra dir exists: $d"
  else
    echo "Creating extra dir: $d"
    sudo mkdir -p "$d"
    sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$d"
    sudo chmod 750 "$d"
  fi
done

sudo chown root:"$SERVICE_USER" "$INSTALL_DIR"/*.sh || true
sudo chmod 750 "$INSTALL_DIR"/*.sh || true

sudo cp "$INSTALL_DIR/backup.sh" "$BIN_DEST"
sudo chown root:"$SERVICE_USER" "$BIN_DEST"
sudo chmod 750 "$BIN_DEST"

if getent group docker >/dev/null 2>&1; then
  sudo usermod -aG docker "$SERVICE_USER" || true
fi

# copy service file and ensure it runs as service user
sudo cp "$INSTALL_DIR/backup.service" "$SERVICE_DEST"
if ! sudo grep -q "^User=$SERVICE_USER$" "$SERVICE_DEST" 2>/dev/null; then
  sudo sed -i "/^\[Service\]/a User=$SERVICE_USER\nGroup=$SERVICE_USER" "$SERVICE_DEST" || true
fi

# Read timer config and create timer unit
TIMER_ONCALENDAR=$(jq -r '.timer.on_calendar // "daily"' "$CONFIG" 2>/dev/null || echo "daily")

# Allow aliases: hourly/daily/weekly/monthly or raw OnCalendar.
case "$TIMER_ONCALENDAR" in
  hourly|daily|weekly|monthly) ONCAL="$TIMER_ONCALENDAR" ;;
  *) ONCAL="$TIMER_ONCALENDAR" ;;
esac

sudo tee "$TIMER_DEST" > /dev/null <<EOF
[Unit]
Description=Run backup.service on schedule

[Timer]
OnCalendar=$ONCAL
Persistent=true
Unit=backup.service

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now backup.service || true
sudo systemctl enable --now backup.timer

echo "Service and timer installed. Check status: sudo systemctl status backup.service && sudo systemctl status backup.timer"
