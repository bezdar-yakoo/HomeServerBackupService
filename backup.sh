#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG="$SCRIPT_DIR/config.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install with: sudo apt install -y jq"
  exit 1
fi

# Read config
HOME_DIR=$(jq -r '.home_dir' "$CONFIG")
INCLUDE_DIRS=($(jq -r '.include_dirs[]' "$CONFIG"))
EXTRA_DIRS=($(jq -r '.extra_dirs[]' "$CONFIG"))
COPY_NGINX=$(jq -r '.copy_nginx' "$CONFIG")
COPY_LETS=$(jq -r '.copy_letsencrypt' "$CONFIG")
OUTPUT_DIR=$(jq -r '.output_dir' "$CONFIG")
MAX_SIZE_MB=$(jq -r '.max_file_size_mb' "$CONFIG")
ARCHIVE_PASS=$(jq -r '.archive_password' "$CONFIG")
ROTATE_KEEP=$(jq -r '.rotate_keep' "$CONFIG")
TMP_BASE=$(jq -r '.tmp_base' "$CONFIG")
POSTGRES_ENABLED=$(jq -r '.postgres.enabled' "$CONFIG")
POSTGRES_CONTAINER=$(jq -r '.postgres.container_name' "$CONFIG")
POSTGRES_USER=$(jq -r '.postgres.user' "$CONFIG")

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TMP_DIR="$TMP_BASE/backup_$TIMESTAMP"
mkdir -p "$TMP_DIR"
mkdir -p "$OUTPUT_DIR"

# Helper: rsync with max size filter
rsync_copy() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  rsync -a --delete --exclude 'node_modules' --max-size="${MAX_SIZE_MB}M" "$src/" "$dst/"
}

# Copy include dirs (by default home)
for d in "${INCLUDE_DIRS[@]}"; do
  base=$(basename "$d")
  echo "Copying $d -> $TMP_DIR/$base"
  rsync_copy "$d" "$TMP_DIR/$base"
done

# Copy extra dirs from config
for d in "${EXTRA_DIRS[@]}"; do
  base=$(basename "$d")
  echo "Copying extra $d -> $TMP_DIR/extra_$base"
  rsync_copy "$d" "$TMP_DIR/extra_$base"
done

# Copy nginx configs
if [ "$COPY_NGINX" = "true" ]; then
  if [ -d "/etc/nginx" ]; then
    echo "Copying /etc/nginx"
    rsync_copy "/etc/nginx" "$TMP_DIR/etc_nginx"
  else
    echo "/etc/nginx not found, skipping"
  fi
fi

# Copy Let's Encrypt
if [ "$COPY_LETS" = "true" ]; then
  if [ -d "/etc/letsencrypt" ]; then
    echo "Copying /etc/letsencrypt"
    rsync_copy "/etc/letsencrypt" "$TMP_DIR/etc_letsencrypt"
  else
    echo "/etc/letsencrypt not found, skipping"
  fi
fi

# Postgres docker dump
if [ "$POSTGRES_ENABLED" = "true" ]; then
  if docker ps --format '{{.Names}}' | grep -q -w "$POSTGRES_CONTAINER"; then
    echo "Dumping Postgres from container $POSTGRES_CONTAINER"
    docker exec -t "$POSTGRES_CONTAINER" pg_dumpall -U "$POSTGRES_USER" > "$TMP_DIR/postgres_dump.sql" || true
  else
    echo "Postgres container $POSTGRES_CONTAINER not running or not found. Skipping DB dump."
  fi
fi

# Create 7z archive
ARCHIVE_NAME="backup_${TIMESTAMP}.7z"
ARCHIVE_PATH="$TMP_BASE/$ARCHIVE_NAME"

if ! command -v 7z >/dev/null 2>&1; then
  echo "7z not found. Install p7zip-full."
  exit 1
fi

echo "Archiving $TMP_DIR -> $ARCHIVE_PATH"
# -mhe=on to encrypt file list
7z a -t7z -mhe=on -p"$ARCHIVE_PASS" "$ARCHIVE_PATH" "$TMP_DIR" >/dev/null

# Move to output
mv "$ARCHIVE_PATH" "$OUTPUT_DIR/"

# Cleanup tmp
rm -rf "$TMP_DIR"

# Rotate: keep last N archives
cd "$OUTPUT_DIR"
count=$(ls -1t backup_*.7z 2>/dev/null | wc -l)
if [ "$count" -gt "$ROTATE_KEEP" ]; then
  to_delete=$(ls -1t backup_*.7z | tail -n +$((ROTATE_KEEP+1)))
  echo "Deleting old archives:"
  echo "$to_delete"
  echo "$to_delete" | xargs -r rm -f
fi

echo "Backup finished. Stored in $OUTPUT_DIR"