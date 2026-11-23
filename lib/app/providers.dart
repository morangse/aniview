import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/backup_service.dart';
import '../core/database/local_library.dart';
import '../core/database/secure_vault.dart';
import '../core/network/bangumi_http.dart';
import '../data/bangumi/bangumi_repository.dart';
import '../features/anime/anime.dart';
import '../media/android_media_access.dart';
import '../media/media.dart';
import '../media/overlays/danmaku_client.dart';
import '../media/sources/media_pipeline.dart';
import '../media/sources/source_adapters.dart';
import '../media/sources/source_store.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  final dio = BangumiHttp.createClient();
  ref.onDispose(() => dio.close(force: true));
  return BangumiRepository(BangumiHttp(dio), ref.watch(databaseProvider));
});

final libraryProvider = Provider<LocalLibrary>(
  (ref) => LocalLibrary(ref.watch(databaseProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

final vaultProvider = Provider<CredentialVault>((ref) => const SecureVault());

final sourceStoreProvider = Provider<SourceStore>(
  (ref) => SourceStore(ref.watch(databaseProvider), ref.watch(vaultProvider)),
);

final sourceRegistryProvider = Provider<MediaSourceRegistry>((ref) {
  final http = createMediaHttp();
  ref.onDispose(() => http.close(force: true));
  return MediaSourceRegistry(
    ref.watch(sourceStoreProvider),
    ref.watch(libraryProvider),
    http,
  );
});

final sourceConfigsProvider = StreamProvider<List<ConfiguredSource>>(
  (ref) => ref.watch(sourceStoreProvider).watchSources(),
);

final resolverProvider = Provider<MediaResolver>(
  (ref) => MediaResolver(
    ref.watch(sourceRegistryProvider),
    ref.watch(sourceStoreProvider),
    ref.watch(libraryProvider),
  ),
);

final favoriteEntriesProvider = StreamProvider<List<FavoriteEntry>>(
  (ref) => ref.watch(libraryProvider).watchFavoriteEntries(),
);

final favoritesProvider = StreamProvider<List<Anime>>(
  (ref) => ref.watch(libraryProvider).watchFavorites(),
);

final historyProvider = StreamProvider<List<WatchEntry>>(
  (ref) => ref.watch(libraryProvider).watchHistory(),
);

final autoplayProvider = StreamProvider<bool>(
  (ref) => ref.watch(libraryProvider).watchAutoplay(),
);

final autoNextProvider = StreamProvider<bool>(
  (ref) => ref.watch(libraryProvider).watchAutoNext(),
);

final danmakuEndpointProvider = StreamProvider<String?>(
  (ref) => ref.watch(libraryProvider).watchDanmakuEndpoint(),
);

final danmakuEndpointsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(libraryProvider).watchDanmakuEndpoints(),
);

final danmakuClientProvider = Provider<DanmakuClient>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 6),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return DanmakuClient(dio);
});

final playerDeviceBridgeProvider = Provider<PlayerDeviceBridge>(
  (_) => const AndroidMediaAccess(),
);

final catalogProvider = FutureProvider.autoDispose.family<CatalogPage, Catalog>(
  (ref, catalog) => ref.watch(animeRepositoryProvider).browse(catalog).first,
  retry: (_, _) => null,
);

final subjectProvider = FutureProvider.autoDispose
    .family<CatalogValue<Anime>, int>(
      (ref, id) => ref.watch(animeRepositoryProvider).subject(id),
      retry: (_, _) => null,
    );

final episodesProvider = FutureProvider.autoDispose
    .family<CatalogValue<List<Episode>>, int>(
      (ref, id) => ref.watch(animeRepositoryProvider).episodes(id),
      retry: (_, _) => null,
    );

final mediaProvider = FutureProvider.autoDispose
    .family<MediaCandidate?, String>(
      (ref, id) => ref.watch(libraryProvider).mediaById(id),
    );
