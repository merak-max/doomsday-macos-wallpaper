#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
support_dir="$HOME/Library/Application Support/DoomsdayWallpaper"
binary_dir="$support_dir/bin"
binary_path="$binary_dir/doomsday-wallpaper"
config_path="$support_dir/config.json"
agent_path="$HOME/Library/LaunchAgents/io.github.doomsday-wallpaper.plist"
old_agent_path="$HOME/Library/LaunchAgents/com.hemant.doomsday-wallpaper.plist"
source_path="$project_dir/Sources/DoomsdayWallpaper/main.swift"
user_id="$(id -u)"
target_date="${1:-}"
title="${2:-COUNTDOWN}"

if [[ -z "$target_date" && ! -f "$config_path" ]]; then
  echo "Usage: ./install.sh YYYY-MM-DD [\"COUNTDOWN TITLE\"]"
  echo "Example: ./install.sh 2030-01-01 \"New Year 2030\""
  exit 2
fi

mkdir -p "$binary_dir" "$HOME/Library/LaunchAgents"
swiftc -O -framework AppKit "$source_path" -o "$binary_path"
chmod 755 "$binary_path"

temp_agent="$(mktemp)"
trap 'rm -f "$temp_agent"' EXIT
sed -e "s|__BINARY_PATH__|$binary_path|g" \
  "$project_dir/io.github.doomsday-wallpaper.plist.template" > "$temp_agent"
cp "$temp_agent" "$agent_path"
chmod 644 "$agent_path"

launchctl bootout "gui/$user_id" "$old_agent_path" 2>/dev/null || true
launchctl bootout "gui/$user_id" "$agent_path" 2>/dev/null || true
rm -f "$old_agent_path"

if [[ -n "$target_date" ]]; then
  "$binary_path" --configure "$target_date" "$title"
else
  "$binary_path"
fi

launchctl bootstrap "gui/$user_id" "$agent_path"

echo ""
echo "Doomsday Wallpaper is installed."
echo "Daily refresh: 00:05 local time"
echo "Change target: ./configure.sh YYYY-MM-DD \"Title\""
