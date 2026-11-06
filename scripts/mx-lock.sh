#!/usr/bin/env bash
# runs a command while holding one of the shared locks, then always releases it.
#
#   scripts/mx-lock.sh <auth-drive|matrixcore|integrate> <owner> -- <command> [args...]
#
# the lock is a directory, /tmp/mx-<name>.lock, with an "owner" file: "<owner> <pid>".
# the pid is this script's own, alive for the whole command. a lock whose pid is gone is
# stale: it is removed with a note, and the wait goes on. the release removes the lock only
# while its owner file still names this run, so a run never removes another run's lock.
set -u

name="${1:-}"; owner="${2:-}"
if [[ -z "$name" || -z "$owner" || "${3:-}" != "--" || $# -lt 4 ]]; then
  echo "usage: $0 <auth-drive|matrixcore|integrate> <owner> -- <command> [args...]" >&2
  exit 2
fi
shift 3
lock="/tmp/mx-$name.lock"
me="$owner $$"

holder() { cat "$lock/owner" 2>/dev/null || true; }

while ! mkdir "$lock" 2>/dev/null; do
  held="$(holder)"
  pid="${held##* }"
  if [[ -n "$held" && "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
    # the holder is gone: take the lock over, only if it still names that holder.
    if [[ "$(holder)" == "$held" ]]; then
      echo "mx-lock: $lock held by \"$held\", whose process is gone: removing it" >&2
      rm -f "$lock/owner"; rmdir "$lock" 2>/dev/null
    fi
    continue
  fi
  sleep 5
done
echo "$me" > "$lock/owner"

release() {
  if [[ "$(holder)" == "$me" ]]; then rm -f "$lock/owner"; rmdir "$lock" 2>/dev/null; fi
}
trap release EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$@"
