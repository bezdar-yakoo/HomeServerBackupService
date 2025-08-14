#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVICE_DEST="/etc/systemd/system/backup.service"
BIN_DEST="/usr/local/bin/backup.sh"
INSTALL_DIR="/home/yakoo/HomeServerBackupService"
SERVICE_USER="backup"

# require jq
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install: sudo apt update && sudo apt install -y jq"
  exit 1
fi

# create system user if missing
if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
  sudo useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
fi

# ensure install dir exists
sudo mkdir -p "$INSTALL_DIR"

# copy repository files to install dir
sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"

CONFIG="$INSTALL_DIR/config.json"
if [ ! -f "$CONFIG" ]; then
  echo "Config file $CONFIG not found. Adjust and re-run."
  exit 1
fi

# read values from config
OUTPUT_DIR=$(jq -r '.output_dir // "/var/backups/backup-service"' "$CONFIG")
TMP_BASE=$(jq -r '.tmp_base // "/tmp/backup-service"' "$CONFIG")

# read include and extra dirs into arrays (handle empty arrays)
mapfile -t INCLUDE_DIRS < <(jq -r '.include_dirs[]? | select(.!=null)' "$CONFIG" 2>/dev/null || true)
mapfile -t EXTRA_DIRS < <(jq -r '.extra_dirs[]? | select(.!=null)' "$CONFIG" 2>/dev/null || true)

# create output and tmp dirs from config
sudo mkdir -p "$OUTPUT_DIR"
sudo mkdir -p "$TMP_BASE"

# set ownership for output and tmp
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$OUTPUT_DIR"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$TMP_BASE"
sudo chmod 750 "$OUTPUT_DIR" "$TMP_BASE"

# ensure include dirs: if missing create and chown to service user; if exist leave as-is but notify
for d in "${INCLUDE_DIRS[@]:-}"; do
  if [ -z "$d" ]; then
    continue
  fi
  if [ -e "$d" ]; then
    echo "Include dir exists: $d"
  else
    echo "Include dir not found, creating: $d"
    sudo mkdir -p "$d"
    sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$d"
    sudo chmod 750 "$d"
  fi
done

# ensure extra dirs: create if missing and chown to service user
for d in "${EXTRA_DIRS[@]:-}"; do
  if [ -z "$d" ]; then
    continue
  fi
  if [ -e "$d" ]; then
    echo "Extra dir exists: $d"
  else
    echo "Creating extra dir: $d"
    sudo mkdir -p "$d"
    sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$d"
    sudo chmod 750 "$d"
  fi
done

# make scripts executable and owned by root:service_user
sudo chown root:"$SERVICE_USER" "$INSTALL_DIR"/*.sh || true
sudo chmod 750 "$INSTALL_DIR"/*.sh || true

# copy main script to /usr/local/bin
sudo cp "$INSTALL_DIR/backup.sh" "$BIN_DEST"
sudo chown root:"$SERVICE_USER" "$BIN_DEST"
sudo chmod 750 "$BIN_DEST"

# if docker group exists add service user so it can exec docker commands
if getent group docker >/dev/null 2>&1; then
  sudo usermod -aG docker "$SERVICE_USER" || true
fi

# copy service file
sudo cp "$INSTALL_DIR/backup.service" "$SERVICE_DEST"

# ensure service runs as the dedicated user
if ! grep -q "^User=$SERVICE_USER$" "$SERVICE_DEST" 2>/dev/null; then
  sudo sed -i "/^\[Service\]/a User=$SERVICE_USER
Group=$SERVICE_USER" "$SERVICE_DEST" || true
fi

# reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable --now backup.service

echo "Service installed and started. Check status: sudo systemctl status backup.service"