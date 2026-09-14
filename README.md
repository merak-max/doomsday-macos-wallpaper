# Doomsday Wallpaper for macOS

A minimal, native macOS wallpaper that turns any future date into a daily visual countdown.

Every dot represents one day. Remaining days are orange, elapsed days fade to gray, and today is highlighted in white. The wallpaper also shows the exact years, months, and days remaining.

The image regenerates automatically every night and is applied to every connected display. No background app, menu-bar process, analytics, or network connection is required.

## Features

- Choose any future date and your own countdown title
- One-dot-per-day reverse countdown
- Exact years, months, days, and total days remaining
- Adaptive grid for different countdown lengths and display resolutions
- Multiple-monitor and Retina-display support
- Automatic refresh at 12:05 AM local time
- A new image path on every refresh to avoid macOS wallpaper caching
- Swift and AppKit only—no third-party dependencies

## Requirements

- macOS
- Xcode Command Line Tools (`xcode-select --install` if needed)

## Install

Clone the repository and pass a future target date in `YYYY-MM-DD` format:

```sh
git clone https://github.com/merak-max/doomsday-macos-wallpaper.git
cd doomsday-macos-wallpaper
./install.sh 2030-01-01 "New Year 2030"
```

The installer compiles a small native binary, creates your configuration, applies the wallpaper immediately, and registers a daily LaunchAgent.

## Change the countdown

Choose a different date or title at any time without reinstalling:

```sh
./configure.sh 2032-06-15 "Project Launch"
```

The new countdown is applied immediately. Its dot-grid progress begins on the day you configure it.

## Refresh manually

```sh
"$HOME/Library/Application Support/DoomsdayWallpaper/bin/doomsday-wallpaper"
```

## How it works

```text
Target date + title
        ↓
Local JSON configuration
        ↓
Native Swift image renderer
        ↓
Timestamped Retina PNG
        ↓
macOS desktop wallpaper
```

The daily job runs only long enough to generate and apply the image, then exits. Configuration and generated images live in:

```text
~/Library/Application Support/DoomsdayWallpaper/
```

## Upgrade

Pull the latest changes and rerun the installer. Omitting the date preserves your existing configuration:

```sh
git pull
./install.sh
```

## Uninstall

```sh
./uninstall.sh
```

This removes automatic refresh but preserves your configuration and generated images. It leaves the current wallpaper selected until you choose another one in System Settings.

## Troubleshooting

If macOS still shows an older wallpaper, refresh it manually:

```sh
"$HOME/Library/Application Support/DoomsdayWallpaper/bin/doomsday-wallpaper"
killall Dock
```

Automatic-refresh logs are stored at:

```text
/tmp/doomsday-wallpaper.log
/tmp/doomsday-wallpaper.error.log
```

## Privacy

Everything runs locally. The utility does not access the internet, collect analytics, or transmit countdown information.

## Inspiration

Inspired by the Android project [Wroughtline/doomsday-live-wallpaper](https://github.com/Wroughtline/doomsday-live-wallpaper), then rebuilt from scratch as a lightweight macOS utility.

## License

MIT
