# DropIt

A universal media downloader for Android. Share any link from any app — DropIt downloads it instantly.

## Supported Platforms

| Platform | Single | Playlist |
|---|---|---|
| YouTube | ✅ Video / MP3 | ✅ |
| Instagram | ✅ Reels / Videos | ✅ |
| Pinterest | ✅ Videos + Photos | — |
| Threads | ✅ Videos | — |
| JioSaavn | ✅ Songs | ✅ |
| Spotify | ✅ Tracks (via YouTube search) | ✅ |

## Features

- **Share to download** — share any URL to DropIt from any app
- **Multi-link paste** — paste multiple links at once and queue them all
- **Quality selection** — choose MP3 audio, 720p, or 1080p per download
- **Playlist support** — download full playlists with parallel downloads
- **Neumorphic UI** — soft, modern light theme
- **Open / delete files** — long-press any completed download to manage files
- **Background downloads** — continue downloading with the app minimized

## Screenshots

> Coming soon

## Build from Source

### Prerequisites

- Flutter 3.x SDK
- Android Studio / Android SDK (API 26+)
- NDK (for yt-dlp native libs)

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/dropit.git
cd dropit
```

### 2. Download yt-dlp binary

DropIt uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) as its download engine.  
Download the **ARM64 Android binary** from the yt-dlp releases page:

```
https://github.com/yt-dlp/yt-dlp/releases/latest
```

File to download: `yt-dlp_linux_aarch64`

Rename it to `yt-dlp` and place it in:

```
assets/yt-dlp
```

> The binary is excluded from this repo via `.gitignore` because of its size (~10 MB).

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Build

**Debug APK:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 5. Install on device

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Permissions Required

- `INTERNET` — for downloading media
- `MANAGE_EXTERNAL_STORAGE` — to save files to `/Downloads/`
- `POST_NOTIFICATIONS` — for download progress notifications

## Download Location

Files are saved to `/Downloads/DropIt/<Platform>/` on your device.

## Tech Stack

- **Flutter** (Dart) — UI
- **yt-dlp** — download engine (via [youtubedl-android](https://github.com/yausername/youtubedl-android))
- **Kotlin** — Android native layer (MethodChannel, FileProvider)
- **JioSaavn public API** — playlist song resolution
- **Spotify oEmbed API** — track metadata → YouTube search

## License

MIT
