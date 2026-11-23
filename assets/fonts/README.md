# Bundled Subtitle Font Slot (libass / Android)

To bundle an offline Simplified Chinese font for `libass` ASS/SSA rendering:

1. Download the official SIL Open Font License 1.1 build of **Noto Sans SC**:
   - Font file: `NotoSansSC-Regular.otf` -> save to `assets/fonts/NotoSansSC-Regular.otf`
   - Source: https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
2. Save the matching license text (`SIL Open Font License 1.1`) to `assets/licenses/OFL-1.1.txt` and register it in `lib/main.dart`.

When `assets/fonts/NotoSansSC-Regular.otf` is not present in the asset bundle, `MediaKitPlayback` automatically falls back on Android to `/system/fonts` (`Noto Sans CJK SC`) via mpv `sub-fonts-dir` / `sub-font`.
