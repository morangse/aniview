# AniView

AniView is an open-source, local-first Android anime tracker and personal media player built with Flutter. It integrates Bangumi metadata and progress syncing with flexible local/user-configured media sources and danmaku playback.

## Features

- **Bangumi Tracking & Local-First Library**: Browse seasonal catalogs, search titles, inspect episode details, and track watch progress locally with SQLite (`drift`). Optional Bangumi token / OAuth sync support.
- **Release Title Matcher 2.0**: Extracts fansub group, bilingual titles, season, episode, release version (`v2+`), resolution, video codec, subtitle language tags, and batch flags with transparent matching reasons and filter chips.
- **Media Player (`media_kit` + `libass`)**: Smooth hardware/software playback, vertical brightness/150%-volume gestures, horizontal seek scrub, long-press 2× speed, fullscreen screen lock, Android Picture-in-Picture (API 26+), OP/ED skip markers, auto-next countdown, audio track switching, and external SRT/VTT/ASS subtitle loading.
- **Danmaku 2.0**:
  - Configurable multi-server support for Dandanplay-protocol-compatible API endpoints (plus direct XML/JSON danmaku URLs).
  - Local Dandanplay JSON and Bilibili XML file import.
  - Real-time danmaku settings (opacity, font size, speed, display area, scroll/top/bottom/color toggles, timeline offset, keyword blocking) and in-player local danmaku composer.
- **User-Configured Media Sources**: Local Android file picker, direct streams, Jellyfin/Emby servers, JSON/RSS/Web rules, and offline downloads for authorized sources.

## Build & Verification

Requires Flutter `>=3.44.0`, Dart `>=3.13.0`, Android SDK (minSdk `24`, target/compile SDK `36`), and NDK `28.2.13676358`.

```sh
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

## Third-Party Assets & Licensing

- Source code in this repository is licensed under the [Apache License 2.0](LICENSE).
- Bundled UI/subtitle fallback font `assets/fonts/NotoSansSC-Regular.otf` is distributed under the SIL Open Font License 1.1 (see `assets/licenses/OFL-1.1.txt`).

## Disclaimer

AniView is purely a client application and personal media player. It does **not** host, bundle, index, or distribute any copyrighted video files or pirated streams. Users are solely responsible for their own local files, personal media servers, and third-party API endpoints.

## Docs

- [架构与迁移](docs/ARCHITECTURE.md)
- [测试与证据](docs/TESTING.md)
- [授权来源格式](docs/AUTHORIZED_SOURCES.md)
