import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/common.dart';
import '../core/widgets/liquid_glass.dart';
import '../core/widgets/soft_controls.dart';
import '../features/anime/anime.dart';
import '../features/anime/anime_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/downloads/download_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/player_resolve_screen.dart';
import '../features/player/player_screen.dart';
import '../features/settings/bangumi_account_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sources/source_management_screen.dart';
import '../media/sources/media_pipeline.dart';
import '../media/sources/source_models.dart';

class AniViewApp extends StatefulWidget {
  const AniViewApp({super.key});

  @override
  State<AniViewApp> createState() => _AniViewAppState();
}

class _AniViewAppState extends State<AniViewApp> {
  late final _router = GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigation) => _Shell(navigation: navigation),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (_, state) => DiscoverScreen(
                  focusSearch: state.uri.queryParameters['focus'] == '1',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/anime/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id < 1) return const _MissingRoute();
          final extra = state.extra;
          return AnimeScreen(
            id: id,
            preview: extra is Anime && extra.id == id ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/catalog/:type',
        builder: (_, state) {
          final name = state.pathParameters['type'];
          final catalog = Catalog.values
              .where((entry) => entry.name == name)
              .firstOrNull;
          return catalog == null
              ? const _MissingRoute()
              : DiscoverScreen(catalog: catalog);
        },
      ),
      GoRoute(
        path: '/player/resolve',
        pageBuilder: (_, state) {
          final args = state.extra is PlayerResolveArgs
              ? state.extra as PlayerResolveArgs
              : const PlayerResolveArgs(request: MediaSearchRequest());
          return NoTransitionPage(
            key: state.pageKey,
            child: PlayerResolveScreen(
              key: ValueKey(
                'resolve-${args.request.episodeKey}-${args.forceShowSources}-${args.autoPlay}',
              ),
              args: args,
            ),
          );
        },
      ),
      GoRoute(
        path: '/player/:id',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: PlayerScreen(
            mediaId: state.pathParameters['id']!,
            session: state.extra is PlaybackSession
                ? state.extra as PlaybackSession
                : null,
          ),
        ),
      ),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/sources',
        builder: (_, _) => const SourceManagementScreen(),
      ),
      GoRoute(path: '/downloads', builder: (_, _) => const DownloadScreen()),
      GoRoute(
        path: '/account',
        builder: (_, _) => const BangumiAccountScreen(),
      ),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    ],
    errorBuilder: (_, _) => const _MissingRoute(),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'AniView',
    theme: AppTheme.dim,
    scrollBehavior: const _AdaptiveScrollBehavior(),
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: _router,
    builder: (_, child) => AnnotatedRegion(
      value: AppTheme.systemOverlay,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

class _AdaptiveScrollBehavior extends MaterialScrollBehavior {
  const _AdaptiveScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AdaptiveLayout.isApplePlatform
      ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
      : super.getScrollPhysics(context);
}

class _Shell extends StatelessWidget {
  const _Shell({required this.navigation});
  final StatefulNavigationShell navigation;

  void _selectBranch(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    navigation.goBranch(
      index,
      initialLocation: index == navigation.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useRail = AdaptiveLayout.useSideRail(context);
    final isApple = AdaptiveLayout.isApplePlatform;
    return PopScope(
      canPop: navigation.currentIndex == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && navigation.currentIndex != 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          navigation.goBranch(0);
        }
      },
      child: useRail
          ? Row(
              children: [
                SafeArea(
                  right: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.sm,
                      SpacingTokens.sm,
                      SpacingTokens.xs,
                      SpacingTokens.sm,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: LiquidGlassRail(
                        key: const ValueKey('liquid-glass-rail'),
                        index: navigation.currentIndex,
                        onSelect: _selectBranch,
                      ),
                    ),
                  ),
                ),
                Expanded(child: navigation),
              ],
            )
          : Stack(
              children: [
                Positioned.fill(child: navigation),
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      minimum: isApple
                          ? const EdgeInsets.only(bottom: 10)
                          : const EdgeInsets.only(
                              left: SpacingTokens.sm,
                              right: SpacingTokens.sm,
                              bottom: SpacingTokens.xs,
                            ),
                      child: Center(
                        child: isApple
                            ? IosLiquidGlassDock(
                                key: const ValueKey('ios-liquid-dock'),
                                index: navigation.currentIndex,
                                onSelect: _selectBranch,
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: LayoutTokens.contentMax,
                                ),
                                child: GlassNavigationBar(
                                  key: const ValueKey('glass-nav'),
                                  index: navigation.currentIndex,
                                  onSelect: _selectBranch,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MissingRoute extends StatelessWidget {
  const _MissingRoute();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('页面不可用')),
    body: PageColumn(
      children: [
        StatusPanel(
          icon: Icons.search_off_outlined,
          title: '找不到这个页面',
          action: '返回首页',
          onAction: () => context.go('/'),
        ),
      ],
    ),
  );
}
