#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
support_dir="$HOME/Library/Application Support/DoomsdayWallpaper"
binary_dir="$support_dir/bin"
binary_path="$binary_dir/doomsday-wallpaper"
agent_path="$HOME/Library/LaunchAgents/com.hemant.doomsday-wallpaper.plist"
source_path="$project_dir/Sources/DoomsdayWallpaper/main.swift"
user_id="$(id -u)"

mkdir -p "$binary_dir" "$HOME/Library/LaunchAgents"

swiftc \
  -O \
  -framework AppKit \
  -framework CoreGraphics \
  "$source_path" \
  -o "$binary_path"

chmod 755 "$binary_path"

temp_agent="$(mktemp)"
trap 'rm -f "$temp_agent"' EXIT

sed \
  -e "s|__BINARY_PATH__|$binary_path|g" \
  "$project_dir/com.hemant.doomsday-wallpaper.plist.template" > "$temp_agent"

cp "$temp_agent" "$agent_path"
chmod 644 "$agent_path"

launchctl bootout "gui/$user_id" "$agent_path" 2>/dev/null || true
"$binary_path"
launchctl bootstrap "gui/$user_id" "$agent_path"

echo "Installed Doomsday Wallpaper."
echo "Wallpaper directory: $support_dir"
echo "Daily refresh: 00:05 local time"
