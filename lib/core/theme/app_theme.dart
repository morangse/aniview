import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class ColorTokens {
  static const background = Color(0xFF101923);
  static const surface = Color(0xFF1A2938);
  static const elevated = Color(0xFF283B4E);
  static const accent = Color(0xFFA9C9EF);
  static const text = Color(0xFFF4F7FA);
  static const muted = Color(0xFFA8B7C6);
  static const border = Color(0x29FFFFFF);
  static const faintBorder = Color(0x1AFFFFFF);
  static const shadow = Color(0xFF050A12);
  static const glass = Color(0xD9283B4E);
  static const highlight = Color(0x16000000);
  static const filmScrim = Color(0xE8101923);
  static const glassTint = Color(0x9E1B2B3C);
  static const glassElevated = Color(0xC224394E);
  static const glassSpecularTop = Color(0x52FFFFFF);
  static const glassSpecularBottom = Color(0x1EA9C9EF);
  static const glassLens = Color(0x3AA9C9EF);
  static const glassBorder = Color(0x38FFFFFF);
}

abstract final class RadiusTokens {
  static const card = BorderRadius.all(Radius.circular(16));
  static const hero = BorderRadius.all(Radius.circular(26));
  static const panel = BorderRadius.all(Radius.circular(26));
  static const pill = BorderRadius.all(Radius.circular(1000));
}

abstract final class SpacingTokens {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const tap = 48.0;
  static const horizontal = EdgeInsets.symmetric(horizontal: md);
}

abstract final class LayoutTokens {
  static const contentMax = 640.0;
  static const mediumContentMax = 920.0;
  static const wideContentMax = 1180.0;
  static const railWidth = 88.0;
  static const heroMinHeight = 242.0;
  static const detailArtwork = 288.0;
  static const mistHeight = 630.0;
  static const posterWidth = 84.0;
  static const posterHeight = 128.0;
  static const progressWidth = 132.0;
  static const progressImageHeight = 74.0;
  static const progressCardHeight = 124.0;
  static const navHeight = 64.0;
  static const navReserve = navHeight + SpacingTokens.lg;
}

enum DeviceLayoutClass { compact, medium, expanded }

abstract final class AdaptiveLayout {
  static bool get isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static DeviceLayoutClass sizeClass(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < 768 || size.shortestSide < 600) {
      return DeviceLayoutClass.compact;
    }
    if (size.width >= 1100) return DeviceLayoutClass.expanded;
    return DeviceLayoutClass.medium;
  }

  static bool useSideRail(BuildContext context) =>
      sizeClass(context) != DeviceLayoutClass.compact;

  static bool useWideTheatre(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= 960 && size.shortestSide >= 600;
  }

  static double contentMaxWidth(BuildContext context) => switch (sizeClass(context)) {
    DeviceLayoutClass.compact => LayoutTokens.contentMax,
    DeviceLayoutClass.medium => LayoutTokens.mediumContentMax,
    DeviceLayoutClass.expanded => LayoutTokens.wideContentMax,
  };

  static int gridColumns(
    BuildContext context, {
    int compact = 3,
    int medium = 4,
    int expanded = 5,
  }) => switch (sizeClass(context)) {
    DeviceLayoutClass.compact => compact,
    DeviceLayoutClass.medium => medium,
    DeviceLayoutClass.expanded => expanded,
  };
}

abstract final class ShadowTokens {
  static const soft = [
    BoxShadow(color: Color(0x58050A12), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const pressed = [
    BoxShadow(color: Color(0x31050A12), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x82050A12), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

abstract final class MotionTokens {
  static const press = Duration(milliseconds: 90);
  static const transition = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
  static const pressedScale = .98;

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  static AnimationStyle sheetStyle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: sheet, reverseDuration: transition);
}

abstract final class AppTheme {
  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  static final dim = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: ColorTokens.background,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme.dark(
      primary: ColorTokens.accent,
      onPrimary: ColorTokens.background,
      secondary: ColorTokens.accent,
      surface: ColorTokens.surface,
      onSurface: ColorTokens.text,
      onSurfaceVariant: ColorTokens.muted,
      outline: ColorTokens.border,
      surfaceContainerHighest: ColorTokens.elevated,
      error: ColorTokens.accent,
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      foregroundColor: ColorTokens.text,
      systemOverlayStyle: systemOverlay,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: ColorTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: RadiusTokens.panel),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColorTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: RadiusTokens.panel),
      showDragHandle: true,
    ),
    dividerTheme: const DividerThemeData(color: ColorTokens.faintBorder),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        color: ColorTokens.muted,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    ).apply(bodyColor: ColorTokens.text, displayColor: ColorTokens.text),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: ColorTokens.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      border: const OutlineInputBorder(borderRadius: RadiusTokens.card),
      enabledBorder: const OutlineInputBorder(
        borderRadius: RadiusTokens.card,
        borderSide: BorderSide(color: ColorTokens.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: RadiusTokens.card,
        borderSide: BorderSide(color: ColorTokens.accent),
      ),
    ),
  );
}
