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
- Channel search and category filtering.
- Persistent pinned channels with a dedicated Pinned category.
- Recently played category that persists across launches.
- Persistent favorites with a dedicated Favorites category.
- Short EPG guide loading for the playing channel, with Now/Next display when provider data is available.
- Native AVKit playback.
- Full-screen theater mode.
- Playback diagnostics with credential-safe copyable status reports.
- Collapsible channel browser.
- Optional account inspector panel.
- HLS `.m3u8` and MPEG-TS `.ts` stream URL modes.
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
- Public builds do not ship provider server URLs, usernames, passwords, playlists, or stream content.

## Planned Features

- iOS app using the same account and playback model.
- iPadOS app with a larger-screen channel browser and player layout.
- Real recorded demo for the website and README.
- Developer ID signing and notarization for smoother macOS installs.
- Full EPG grid and richer schedule browsing.
- More library management controls for saved and recently played channels.
- VOD and series support for compatible provider APIs.
- Picture-in-picture.
- M3U playlist import and export where legally supported.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Command-R` | Reload channels |
| `Space` | Play or pause the current stream |
| `Command-[` | Previous channel |
| `Command-]` | Next channel |
| `Command-D` | Add or remove the current channel from favorites |
| `Command-Shift-D` | Pin or unpin the current channel |
| `Option-Command-C` | Copy playback diagnostics |
| `Command-.` | Stop playback |
| `Control-Command-F` | Enter or exit full-screen player |
| `Escape` | Exit full-screen player |
| `Option-Command-L` | Collapse or show channels |
| `Option-Command-I` | Show or hide account settings |
