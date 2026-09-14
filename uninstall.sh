#!/bin/zsh
set -euo pipefail

agent_path="$HOME/Library/LaunchAgents/com.hemant.doomsday-wallpaper.plist"
support_dir="$HOME/Library/Application Support/DoomsdayWallpaper"
user_id="$(id -u)"

launchctl bootout "gui/$user_id" "$agent_path" 2>/dev/null || true
rm -f "$agent_path"

echo "Stopped and removed the daily refresh agent."
echo "Generated wallpaper files remain in: $support_dir"
