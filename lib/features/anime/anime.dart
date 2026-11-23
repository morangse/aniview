class Anime {
  const Anime({
    required this.id,
    required this.originalName,
    this.chineseName = '',
    this.summary = '',
    this.date,
    this.platform = '',
    this.cover,
    this.poster,
    this.score,
    this.episodeCount,
    this.tags = const [],
    this.aliases = const [],
  });

  final int id;
  final String originalName;
  final String chineseName;
  final String summary;
  final String? date;
  final String platform;
  final Uri? cover;
  final Uri? poster;
  final double? score;
  final int? episodeCount;
  final List<String> tags;
  final List<String> aliases;

  String get title => chineseName.isEmpty ? originalName : chineseName;
  String? get year => date?.split('-').first;

  Map<String, Object?> toJson() => {
    'id': id,
    'originalName': originalName,
    'chineseName': chineseName,
    'summary': summary,
    'date': date,
    'platform': platform,
    'cover': cover?.toString(),
    'poster': poster?.toString(),
    'score': score,
    'episodeCount': episodeCount,
    'tags': tags,
    'aliases': aliases,
  };

  factory Anime.fromJson(Map<String, dynamic> json) => Anime(
    id: json['id'] as int,
    originalName: json['originalName'] as String,
    chineseName: json['chineseName'] as String,
    summary: json['summary'] as String,
    date: json['date'] as String?,
    platform: json['platform'] as String,
    cover: _readImage(json['cover']),
    poster: _readImage(json['poster']),
    score: (json['score'] as num?)?.toDouble(),
    episodeCount: json['episodeCount'] as int?,
    tags: List<String>.from(json['tags'] as List),
    aliases: List<String>.from(json['aliases'] as List? ?? const []),
  );

  static Uri? _readImage(Object? value) =>
      value is String && value.isNotEmpty ? Uri.tryParse(value) : null;
}

enum CollectionStatus {
  wish(1, '想看'),
  collected(2, '看过'),
  doing(3, '在看'),
  onHold(4, '搁置'),
  dropped(5, '抛弃');

  const CollectionStatus(this.code, this.label);
  final int code;
  final String label;

  static CollectionStatus fromCode(int? code) => switch (code) {
    1 => wish,
    2 => collected,
    3 => doing,
    4 => onHold,
    5 => dropped,
    _ => doing,
  };
}

class FavoriteEntry {
  const FavoriteEntry({
    required this.anime,
    required this.status,
    required this.addedAt,
    required this.updatedAt,
    this.rating,
    this.comment,
    this.dirty = false,
  });

  final Anime anime;
  final CollectionStatus status;
  final int? rating;
  final String? comment;
  final DateTime addedAt;
  final DateTime updatedAt;
  final bool dirty;
}

enum EpisodeKind { regular, special, extra }

class Episode {
  const Episode({
    required this.id,
    required this.number,
    required this.title,
    this.airDate,
    this.runningTime,
    this.kind = EpisodeKind.regular,
  });

  final int id;
  final num number;
  final String title;
  final String? airDate;
  final String? runningTime;
  final EpisodeKind kind;

  String get label {
    final displayNumber = number % 1 == 0 ? number.toInt() : number;
    return switch (kind) {
      EpisodeKind.regular => '第 $displayNumber 集',
      EpisodeKind.special => '特别篇 $displayNumber',
      EpisodeKind.extra => '附加内容 $displayNumber',
    };
  }
}

enum Catalog { season, popular, ranking, all }

typedef SearchQuery = ({String keyword, String? tag, int? year, int offset});

class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.nextOffset,
    this.stale = false,
  });

  final List<Anime> items;
  final int? nextOffset;
  final bool stale;
}

class CatalogValue<T> {
  const CatalogValue(this.value, {this.stale = false});

  final T value;
  final bool stale;
}

abstract interface class AnimeRepository {
  Stream<CatalogPage> browse(Catalog catalog, {int offset = 0});
  Stream<CatalogPage> search(SearchQuery query);
  Future<CatalogValue<Anime>> subject(int id);
  Future<CatalogValue<List<Episode>>> episodes(int subjectId);
}
