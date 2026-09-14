#!/bin/zsh
set -euo pipefail

agent_path="$HOME/Library/LaunchAgents/io.github.doomsday-wallpaper.plist"
old_agent_path="$HOME/Library/LaunchAgents/com.hemant.doomsday-wallpaper.plist"
support_dir="$HOME/Library/Application Support/DoomsdayWallpaper"
user_id="$(id -u)"

launchctl bootout "gui/$user_id" "$agent_path" 2>/dev/null || true
launchctl bootout "gui/$user_id" "$old_agent_path" 2>/dev/null || true
rm -f "$agent_path" "$old_agent_path"

echo "Automatic refresh has been removed."
echo "Your configuration and generated images remain in: $support_dir"
echo "The current desktop image remains selected until you choose another wallpaper."
