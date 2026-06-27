# ChannelDeck

A small native macOS IPTV player for accounts that use Xtream-style server login.

The app loads live categories and channels from `player_api.php`, then plays the selected stream with the macOS AVKit player. It also includes copy/open fallbacks for stream URLs, since some IPTV streams may use codecs that AVPlayer cannot decode.

ChannelDeck does not include IPTV content, playlists, provider credentials, or a subscription service. Use it only with accounts and streams you are authorized to access.

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

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Command-R` | Reload channels |
| `Space` | Play or pause the current stream |
| `Command-[` | Previous channel |
| `Command-]` | Next channel |
| `Command-.` | Stop playback |
| `Control-Command-F` | Enter or exit full-screen player |
| `Escape` | Exit full-screen player |
| `Option-Command-L` | Collapse or show channels |
| `Option-Command-I` | Show or hide account settings |
