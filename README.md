# ChannelDeck

A native IPTV player for accounts that use Xtream-style server login.

The app loads live categories and channels from `player_api.php`, then plays the selected stream with the macOS AVKit player. It also includes copy/open fallbacks for stream URLs, since some IPTV streams may use codecs that AVPlayer cannot decode.

ChannelDeck does not include IPTV content, playlists, provider credentials, or a subscription service. Use it only with accounts and streams you are authorized to access.

Website: https://thromel.github.io/channeldeck/

## Current Status

- macOS app is available now.
- iOS and iPadOS support is planned.
- Demo media will be added after a real recording is captured.

## Features

- Xtream-style account login with server URL, ID, and password.
- Account validation through `player_api.php`.
- Live category loading and live channel loading.
- Home dashboard with pinned, favorite, and recent channel shelves.
- Channel search and category filtering.
- Command-K quick switcher for fast channel lookup, playback, multiview, pinning, and favorites.
- Persistent pinned channels with a dedicated Pinned category.
- Recently played category that persists across launches.
- Persistent favorites with a dedicated Favorites category.
- Short EPG guide loading for the playing channel, with Now/Next display and a richer guide panel when provider data is available.
- Native AVKit playback.
- Full-screen theater mode.
- Picture-in-picture for the primary live player.
- 2-4 channel multiview playback with independent volume and mute per tile.
- Saved multiview layouts.
- Local-only stream recording to `~/Movies/ChannelDeck` for authorized streams.
- Local library for opening, revealing, refreshing, and deleting recordings and saved playlists.
- Playback diagnostics with credential-safe copyable status reports.
- Collapsible channel browser.
- Optional account inspector panel.
- HLS `.m3u8` and MPEG-TS `.ts` stream URL modes.
- Local M3U playlist export, defaulting to the ChannelDeck local library.
- Copy stream URL fallback.
- Open stream URL fallback for external players or browser handoff.
- Password storage in the macOS Keychain.
- Generic public builds with no provider server, username, password, playlist, or stream content bundled.

## Run

```bash
./script/build_and_run.sh
```

For a build plus launch check:

```bash
./script/build_and_run.sh --verify
```

The Codex desktop Run action is wired to the same script through `.codex/environments/environment.toml`.

## Release Build

```bash
./script/package_release.sh
```

This creates `outputs/ChannelDeck-macOS.zip`. The current package is ad-hoc signed for bundle integrity but not Apple Developer ID signed or notarized.

For the current public zip, unzip `ChannelDeck-macOS.zip`, then right-click `ChannelDeck.app` and choose Open the first time. A future Developer ID build should replace this with a notarized package.

## Notes

- Passwords are stored in the macOS Keychain.
- Some IPTV provider servers use HTTP, so the local app bundle allows HTTP network/media loads.
- The app currently focuses on live TV. VOD/series support can be added through the same API.
- Local recordings and M3U exports are for streams you are authorized to access. M3U files contain playable stream URLs.
- Public builds do not ship provider server URLs, usernames, passwords, playlists, or stream content.

## Planned Features

- iOS app using the same account and playback model.
- iPadOS app with a larger-screen channel browser and player layout.
- Real recorded demo for the website and README.
- Developer ID signing and notarization for smoother macOS installs.
- Full EPG grid and richer schedule browsing.
- More library management controls for saved channels, recording metadata, and history.
- VOD and series support for compatible provider APIs.
- M3U playlist import where legally supported.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Command-R` | Reload channels |
| `Space` | Play or pause the current stream |
| `Command-[` | Previous channel |
| `Command-]` | Next channel |
| `Command-K` | Quick open channel switcher |
| `Command-D` | Add or remove the current channel from favorites |
| `Command-Shift-D` | Pin or unpin the current channel |
| `Option-Command-M` | Show multiview |
| `Option-Command-G` | Show current channel guide |
| `Option-Command-P` | Start or stop picture-in-picture |
| `Command-Shift-R` | Start or stop recording the current stream |
| `Option-Command-S` | Save local M3U playlist |
| `Option-Command-J` | Show local recordings and saved playlists |
| `Option-Command-C` | Copy playback diagnostics |
| `Command-.` | Stop playback |
| `Control-Command-F` | Enter or exit full-screen player |
| `Escape` | Exit full-screen player |
| `Option-Command-L` | Collapse or show channels |
| `Option-Command-I` | Show or hide account settings |
