import 'package:flutter/services.dart';

class SubtitleFontConfig {
  const SubtitleFontConfig._();

  static const bundledAsset = 'assets/fonts/NotoSansSC-Regular.otf';
  static const bundledFontName = 'Noto Sans SC';
  static const androidFallbackFontsDir = '/system/fonts';
  static const androidFallbackFontName = 'Noto Sans CJK SC';

  static Future<bool> hasBundledFont() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().contains(bundledAsset);
    } on Exception {
      return false;
    }
  }
}
