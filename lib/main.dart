import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/aniview_app.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'libmpv',
    ], await rootBundle.loadString('assets/licenses/LGPL-2.1.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'libmpv-android-video-build',
    ], await rootBundle.loadString('assets/licenses/libmpv-android-build.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/licenses/OFL-1.1.txt'));
  });
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);
  runApp(const ProviderScope(child: AniViewApp()));
}
