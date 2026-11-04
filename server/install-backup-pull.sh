#!/usr/bin/env bash
# installs a launchd job that runs pull-backup.sh every day at 21:30 (after the
# server's dumps at 00:00 utc). when the mac sleeps at that time, launchd runs it
# at wake. safe to run again. its log: ~/Library/Logs/multiplexer-server-backup.log
#
# launchd may not read ~/Documents, so the job runs a copy of the script from
# ~/Library/Application Support. run this again after a change to pull-backup.sh.
set -euo pipefail

label="com.ramimaalouf.multiplexer.server-backup"
here="$(cd "$(dirname "$0")" && pwd)"
bin="$HOME/Library/Application Support/multiplexer"
plist="$HOME/Library/LaunchAgents/$label.plist"
log="$HOME/Library/Logs/multiplexer-server-backup.log"

mkdir -p "$bin"
cp "$here/pull-backup.sh" "$bin/pull-backup.sh"
chmod 755 "$bin/pull-backup.sh"

cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$bin/pull-backup.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>30</integer></dict>
  <key>StandardOutPath</key><string>$log</string>
  <key>StandardErrorPath</key><string>$log</string>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
echo "installed $label: every day at 21:30. run it now: launchctl kickstart gui/$(id -u)/$label"
