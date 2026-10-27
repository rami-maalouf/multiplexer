#!/usr/bin/env bash
# registers a matrix user on our server with a random password that only the mac's
# keychain keeps (service <keychain service>, account @<user>:ramimaalouf.com).
#   ./server/register-user.sh rami multiplexer-matrix admin
#   ./server/register-user.sh test1 multiplexer-test-account
# the password never shows: it goes to ansible in a private file, and the printed log
# has it replaced by <password>.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <user> <keychain service> [admin]" >&2
  exit 1
fi
user="$1"
service="$2"
admin="no"
if [ "${3:-}" = "admin" ]; then admin="yes"; fi
account="@$user:ramimaalouf.com"
here="$(cd "$(dirname "$0")" && pwd)"

# a second run reuses the password, so a failed run can be tried again.
if ! password="$(security find-generic-password -s "$service" -a "$account" -w 2> /dev/null)"; then
  password="$(openssl rand -hex 16)"
  security add-generic-password -s "$service" -a "$account" -w "$password"
fi

umask 077
vars_file="$(mktemp)"
log="$(mktemp)"
trap 'rm -f "$vars_file" "$log"' EXIT
printf '{"username": "%s", "password": "%s", "admin": "%s"}\n' "$user" "$password" "$admin" > "$vars_file"

status=0
"$here/playbook.sh" --extra-vars "@$vars_file" --tags=register-user > "$log" 2>&1 || status=$?
sed "s/$password/<password>/g" "$log"
if [ "$status" -eq 0 ]; then
  echo "registered $account (admin: $admin). password: keychain service $service, account $account"
  # the registration signs the user in once; nobody uses that session.
  uv run "$here/remove-unused-sessions.py" "$user" "$service"
fi
exit "$status"
