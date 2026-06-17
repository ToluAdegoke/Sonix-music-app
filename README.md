# 🎵 Sonix — A Spotify-Inspired Flutter Music App

A functional music streaming Android app built with **Flutter (Dart)**, powered by the free public **Deezer API**. Features 30-second song previews, search, a library for liked songs + user playlists, and a Spotify-inspired dark theme with custom purple/teal Sonix branding.

> ⚠️ **IMPORTANT — UNVERIFIED SOURCE CODE**
>
> This Flutter project was scaffolded as **source text files only**. It was **not compiled, built, or run** in the environment it was generated in. Expect to fix minor issues on your machine (e.g. package version bumps, lint warnings, missing Android config files that Flutter auto-generates). Follow the build instructions below carefully.

---

## 📱 Features

- ✅ **Home screen** with featured playlists, trending tracks, popular albums & artists
- ✅ **Search** for songs, artists, and albums (live, debounced)
- ✅ **Music player** with play/pause, skip next/previous, seek bar
- ✅ **Full-screen player** with album art & gradient background
- ✅ **Persistent mini-player** above the bottom nav
- ✅ **Library** — Liked Songs + user-created playlists (persisted locally with SharedPreferences)
- ✅ **Album / Artist / Playlist** detail screens
- ✅ **Dark Spotify-inspired theme** with custom Sonix purple + teal branding
- ✅ **Auto-advance** to next track on completion (30-sec previews)

---

## 🏗️ Project Structure

```
sonix/
├── android/                       # Android-specific config
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/com/sonix/app/MainActivity.kt
│   ├── build.gradle
│   ├── gradle.properties
│   └── settings.gradle
├── lib/
│   ├── main.dart                  # Entry point
│   ├── root_shell.dart            # Bottom nav + mini-player shell
│   ├── theme/
│   │   └── app_theme.dart         # Dark theme + brand colors
│   ├── models/
│   │   ├── track.dart
│   │   ├── album.dart
│   │   ├── artist.dart
│   │   └── playlist.dart
│   ├── services/
│   │   ├── deezer_api.dart        # Deezer REST client
│   │   ├── audio_player_service.dart   # just_audio wrapper
│   │   └── library_service.dart   # Local persistence
│   ├── providers/
│   │   ├── player_provider.dart
│   │   └── library_provider.dart
│   ├── widgets/
│   │   ├── track_tile.dart
│   │   ├── cover_card.dart
│   │   ├── mini_player.dart
│   │   └── section_header.dart
│   └── screens/
│       ├── home_screen.dart
│       ├── search_screen.dart
│       ├── library_screen.dart
│       ├── player_screen.dart
│       ├── playlist_detail_screen.dart
│       ├── album_detail_screen.dart
│       └── artist_detail_screen.dart
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 🚀 How to Build & Run

### Prerequisites

1. **Flutter SDK** installed (≥ 3.10). Verify: `flutter --version`
2. **Android SDK** installed (Android Studio recommended)
3. An **Android device** (with USB debugging) or **emulator** running

### Step 1 — Initialize Flutter platform files

This scaffold intentionally omits some auto-generated platform files (launcher icons, `ios/`, `web/`, `values/styles.xml`, etc.). Regenerate them with:

```bash
flutter create . --project-name sonix --platforms=android --org com.sonix
```

This is **safe** — it will not overwrite the source files in `lib/`, `android/app/src/main/AndroidManifest.xml`, or `android/app/build.gradle` if they already exist. It will fill in the missing Android resource files (`styles.xml`, icons, etc.).

### Step 2 — Install dependencies

```bash
flutter pub get
```

If you get version conflicts, run `flutter pub upgrade` to let pub resolve the latest compatible versions.

### Step 3 — Run on device/emulator

```bash
flutter devices        # confirm your device/emulator is listed
flutter run            # builds & launches in debug mode
```

To build a release APK:

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🌐 Data & API

### Deezer Public API

- **Base URL**: `https://api.deezer.com`
- **Authentication**: None required
- **Rate limits**: ~50 req/5 sec per IP
- **Preview streams**: Every track returns a 30-second MP3 URL in the `preview` field
- **Docs**: https://developers.deezer.com/api

Endpoints used:
| Purpose | Endpoint |
|---|---|
| Search tracks | `GET /search?q={query}` |
| Search artists | `GET /search/artist?q={query}` |
| Search albums | `GET /search/album?q={query}` |
| Top tracks | `GET /chart/0/tracks` |
| Editorial playlists | `GET /chart/0/playlists` |
| Top albums | `GET /chart/0/albums` |
| Top artists | `GET /chart/0/artists` |
| Playlist tracks | `GET /playlist/{id}/tracks` |
| Album tracks | `GET /album/{id}/tracks` |
| Artist top tracks | `GET /artist/{id}/top` |

### Local Storage (SharedPreferences)

| Key | Contents |
|---|---|
| `sonix_liked_tracks_v1` | JSON array of liked `Track` objects |
| `sonix_user_playlists_v1` | JSON map `{playlistName: [Track, ...]}` |

---

## 🧭 App Navigation Map

```
RootShell (bottom nav)
├── Home           → Playlist/Album/Artist detail screens
├── Search         → Artist/Album detail + inline track playback
└── Library
    ├── Liked Songs tab
    └── Playlists tab

MiniPlayer (above bottom nav, when a track is loaded)
   └── tap → PlayerScreen (full-screen)
```

---

## 🎨 Branding

- **Primary**: `#8A5CFF` (vibrant purple)
- **Accent**: `#22D3EE` (teal)
- **Background**: `#0E0B1F` (deep indigo/black)
- **Font**: Inter (via `google_fonts`)
- **Gradient**: Purple → Teal diagonal (used in mini-player, FABs, logo)

---

## 🧩 Dependencies (from `pubspec.yaml`)

| Package | Purpose |
|---|---|
| `http` | Deezer API calls |
| `provider` | State management |
| `just_audio` + `audio_session` | MP3 streaming & playback |
| `shared_preferences` | Local persistence |
| `cached_network_image` | Efficient image caching for album art |
| `google_fonts` | Inter typeface |
| `palette_generator` | (Reserved) Dynamic background colors from album art |
| `marquee` | (Reserved) Scrolling long titles |

---

## 🚧 Not Yet Implemented (Ideas for Next Steps)

- [ ] **Background audio playback** with lock-screen/notification controls (`audio_service` package)
- [ ] **Add-to-playlist** bottom sheet from the track tile menu
- [ ] **Shuffle & repeat** modes (UI exists, logic not wired)
- [ ] **Offline download** of previews
- [ ] **Dynamic player background** colors extracted from album art using `palette_generator`
- [ ] **Scrolling marquee** for very long song titles
- [ ] **Recently played** history screen
- [ ] **User profile / settings** screen
- [ ] **iOS support** (currently Android-only — add Info.plist audio background mode)
- [ ] **Unit tests** for services & providers
- [ ] **Launcher icon** — replace default with Sonix logo using `flutter_launcher_icons`

---

## 🐛 Known Caveats

1. **Only 30-second previews** are available — the Deezer public API does not allow full-track streaming without a paid partnership.
2. **Some tracks have no `preview`** and are filtered out of the UI (no action needed).
3. **Background playback**: When the app goes to background, playback may pause. Adding `audio_service` is the proper fix.
4. **First build may be slow** (~2–5 min) due to Gradle dependency downloads.
5. **Deezer CORS**: The API works fine on native Android but is blocked in browser contexts — so this code cannot be run as a Flutter Web app without a proxy.

---

## 📄 License

This project is for educational/personal use. Deezer trademarks and content belong to Deezer. Spotify is a trademark of Spotify AB and is not affiliated with this project.

---

## 🙏 Credits

- Music data & preview streams: [Deezer API](https://developers.deezer.com/api)
- Audio engine: [just_audio](https://pub.dev/packages/just_audio)
- Design inspiration: Spotify (reimagined with a Sonix twist)
