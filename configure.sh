#!/bin/zsh
set -euo pipefail

support_dir="$HOME/Library/Application Support/DoomsdayWallpaper"
binary_path="$support_dir/bin/doomsday-wallpaper"
target_date="${1:-}"
title="${2:-COUNTDOWN}"

if [[ -z "$target_date" ]]; then
  echo "Usage: ./configure.sh YYYY-MM-DD [\"COUNTDOWN TITLE\"]"
  echo "Example: ./configure.sh 2030-01-01 \"New Year 2030\""
  exit 2
fi

if [[ ! -x "$binary_path" ]]; then
  echo "Doomsday Wallpaper is not installed. Run install.sh first."
  exit 1
fi

"$binary_path" --configure "$target_date" "$title"
echo "Countdown updated."
