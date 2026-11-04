#!/usr/bin/env bash
# copies the server's backups to the mac, so that they outlive the server:
# the database dumps (a mirror of the server's 7 daily and 2 weekly), the media
# (photos, videos; only added to, never deleted here) and synapse's signing key.
# it only reads on the server. launchd runs it every day (install-backup-pull.sh).
#
# the copy holds secrets (the bridges' login sessions, the signing key), so it
# stays out of git and out of synced folders. time machine copies it.
set -euo pipefail

dest="${MULTIPLEXER_BACKUP_DIR:-$HOME/Backups/multiplexer-server}"
host="oracle"
pull=(rsync -a --rsync-path="sudo rsync")

fail() {
  echo "$(date -u +%FT%TZ) failed: $1" >&2
  osascript -e "display notification \"$1\" with title \"Matrix server backup failed\"" 2>/dev/null || true
  exit 1
}
trap 'fail "line $LINENO"' ERR

mkdir -p "$dest"
chmod 700 "$dest"

# -H keeps the dumps' hard links, so each dump uses its space once, as on the server.
# --delete: the server keeps 7 days; a failed ssh deletes nothing.
"${pull[@]}" -H --delete "$host:/matrix/postgres-backup/data/" "$dest/postgres/"
"${pull[@]}" "$host:/matrix/synapse/storage/media-store/" "$dest/media-store/"
"${pull[@]}" "$host:/matrix/synapse/config/matrix.ramimaalouf.com.signing.key" "$dest/"
chmod 600 "$dest/matrix.ramimaalouf.com.signing.key"

# the newest dump of each database must be whole and at most 2 days old.
for latest in "$dest"/postgres/last/*-latest.sql.gz; do
  file="$(dirname "$latest")/$(readlink "$latest")"
  gzip -t "$file" || fail "$(basename "$file") is not a whole gzip file"
  [ -z "$(find "$file" -mtime +2)" ] || fail "$(basename "$file") is more than 2 days old"
done

echo "$(date -u +%FT%TZ) ok: $(du -sh "$dest" | cut -f1) in $dest"
