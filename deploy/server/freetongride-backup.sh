#!/bin/bash
# Daily PostgreSQL backup for FreeTongRide; keeps 7 days.
set -euo pipefail
DIR=/var/backups/freetongride
mkdir -p "$DIR"
chmod 700 "$DIR"
FILE="$DIR/freetongride-$(date +%Y%m%d-%H%M).dump"
sudo -u postgres pg_dump -Fc freetongride > "$FILE.tmp"
mv "$FILE.tmp" "$FILE"
chmod 600 "$FILE"
# Uploaded driver documents and photos.
tar -czf "$DIR/uploads-$(date +%Y%m%d-%H%M).tar.gz" -C /var/lib/freetongride wwwroot 2>/dev/null || true
chmod 600 "$DIR"/uploads-*.tar.gz 2>/dev/null || true
find "$DIR" -type f -mtime +7 -delete
