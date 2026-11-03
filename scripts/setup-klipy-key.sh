#!/usr/bin/env bash
# writes the KLIPY app key from the mac's keychain into apps/multiplexer/.env.local (gitignored),
# where the build reads it (app.json's "env": KLIPY_KEY). the key is never printed.
# KLIPY_ACCOUNT=production picks the production key; the default is the test key (100 calls an hour).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
account="${KLIPY_ACCOUNT:-test}"
key="$(security find-generic-password -s multiplexer-klipy -a "$account" -w)"
env_file="$root/apps/multiplexer/.env.local"
touch "$env_file"
chmod 600 "$env_file"
# keep the file's other lines; replace the key's.
grep -v '^KLIPY_KEY=' "$env_file" > "$env_file.tmp" || true
printf 'KLIPY_KEY=%s\n' "$key" >> "$env_file.tmp"
mv "$env_file.tmp" "$env_file"
chmod 600 "$env_file"
echo "KLIPY_KEY ($account) written to apps/multiplexer/.env.local"
