# Doomsday Wallpaper for macOS

A native macOS countdown wallpaper targeting September 13, 2028.

Inspired by the Android project `Wroughtline/doomsday-live-wallpaper`, rebuilt
as a lightweight native macOS utility.

- One dot per day from September 14, 2026 through the target date
- Elapsed days fade to gray
- Today is enlarged and highlighted in white
- Remaining days stay orange and count down in reverse
- Remaining time is shown as years, months, and days
- Every refresh uses a new filename so macOS cannot display a stale cached image
- The image is regenerated and applied every day at 00:05 local time

## Install

```sh
./install.sh
```

## Refresh immediately

```sh
"$HOME/Library/Application Support/DoomsdayWallpaper/bin/doomsday-wallpaper"
```

## Remove automatic refresh

```sh
./uninstall.sh
```

## License

MIT
