#!/usr/bin/env bash
# sets up the mac to run the matrix playbook: ansible (with uv), the playbook at
# the pinned commit with its roles, and the secrets file from the keychain.
# safe to run again. run it again after a change of a pin below.
#
# the first run for a new server: ./server/setup.sh --create-secrets
set -euo pipefail

ansible_version="14.5.0"
playbook_repo="https://github.com/spantaleev/matrix-docker-ansible-deploy.git"
playbook_commit="e3929968b81c9bc87b56c259930f4c5afbc95a96" # master on 2026-10-27
keychain_service="multiplexer-server"
secrets=(matrix_homeserver_generic_secret_key postgres_connection_password)

here="$(cd "$(dirname "$0")" && pwd)"
playbook="$here/vendor/matrix-docker-ansible-deploy"
host_vars="$here/inventory/host_vars/matrix.ramimaalouf.com"

if [ "$(ansible-community --version 2>/dev/null)" != "Ansible community version $ansible_version" ]; then
  uv tool install --force --with-executables-from ansible-core "ansible==$ansible_version"
fi

# only the pinned commit, not the whole history.
if [ ! -d "$playbook/.git" ]; then
  git init -q "$playbook"
  git -C "$playbook" remote add origin "$playbook_repo"
fi
if [ "$(git -C "$playbook" rev-parse -q --verify HEAD || true)" != "$playbook_commit" ]; then
  git -C "$playbook" fetch -q --depth 1 origin "$playbook_commit"
  git -C "$playbook" checkout -q --detach FETCH_HEAD
fi
# the roles come from requirements.yml, so they follow the playbook's pin.
if [ "$(cat "$playbook/roles/galaxy/.commit" 2>/dev/null)" != "$playbook_commit" ]; then
  rm -rf "$playbook/roles/galaxy"
  (cd "$playbook" && ansible-galaxy install -r requirements.yml -p roles/galaxy/ --force)
  echo "$playbook_commit" > "$playbook/roles/galaxy/.commit"
fi

# the keychain is the only copy of the secrets on the mac. a new secret for a
# server that already runs would break it, so only --create-secrets makes them.
secret() { security find-generic-password -s "$keychain_service" -a "$1" -w 2>/dev/null; }
for name in "${secrets[@]}"; do
  if ! secret "$name" > /dev/null; then
    if [ "${1:-}" != "--create-secrets" ]; then
      echo "the keychain has no $name (service $keychain_service)." >&2
      echo "for a new server only: ./server/setup.sh --create-secrets" >&2
      exit 1
    fi
    security add-generic-password -s "$keychain_service" -a "$name" -w "$(openssl rand -hex 32)"
  fi
done
umask 077
{
  echo "# written by server/setup.sh from the keychain (service $keychain_service). do not edit."
  echo "# the server's settings are in config.yml, next to this file."
  for name in "${secrets[@]}"; do
    echo "$name: \"$(secret "$name")\""
  done
} > "$host_vars/vars.yml"

echo "ready: ansible $ansible_version, playbook ${playbook_commit:0:10}, secrets in $host_vars/vars.yml"
