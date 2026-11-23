import '../../features/anime/anime.dart';

Anime? parseBangumiAnime(Map<String, dynamic> json) {
  final id = json['id'];
  final name = _text(json['name']);
  final chinese = _text(json['name_cn']);
  if (id is! int || id < 1 || (name.isEmpty && chinese.isEmpty)) return null;
  if (json['type'] != 2 || json['nsfw'] == true) return null;
  final images = json['images'];
  final rating = json['rating'];
  final score = rating is Map ? rating['score'] : null;
  final tags = <String>{};
  final rawTags = json['tags'];
  if (rawTags is List) {
    for (final tag in rawTags.whereType<Map>()) {
      final label = _text(tag['name']);
      if (label.isNotEmpty) tags.add(label);
    }
  }
  Uri? image(String field) => images is Map ? _cover(images[field]) : null;
  final count = json['eps'];
  final total = json['total_episodes'];
  final date = _date(json['date']);
  return Anime(
    id: id,
    originalName: name,
    chineseName: chinese,
    summary: _text(json['summary']),
    platform: _text(json['platform']),
    date: date,
    cover:
        image('common') ?? image('medium') ?? image('large') ?? image('small'),
    poster: image('large') ?? image('common') ?? image('medium'),
    score: score is num && score > 0 && score <= 10 ? score.toDouble() : null,
    episodeCount: count is int && count > 0
        ? count
        : (total is int && total > 0 ? total : null),
    tags: tags.take(12).toList(growable: false),
    aliases: _aliases(json['infobox']),
  );
}

Episode? parseBangumiEpisode(Map<String, dynamic> json) {
  final id = json['id'];
  final number = json['sort'];
  if (id is! int || id < 1 || number is! num || !number.isFinite) return null;
  final chinese = _text(json['name_cn']);
  final length = _text(json['duration']);
  return Episode(
    id: id,
    number: number,
    title: chinese.isEmpty ? _text(json['name']) : chinese,
    airDate: _date(json['airdate']),
    runningTime: length.isEmpty ? null : length,
    kind: switch (json['type']) {
      null || 0 => EpisodeKind.regular,
      1 => EpisodeKind.special,
      _ => EpisodeKind.extra,
    },
  );
}

List<String> _aliases(Object? infobox) {
  if (infobox is! List) return const [];
  final names = <String>{};
  for (final entry in infobox.whereType<Map>()) {
    if (!const {'别名', '英文名', '英语名', 'English', '罗马字'}.contains(entry['key'])) {
      continue;
    }
    final value = entry['value'];
    final values = value is List
        ? value.whereType<Map>().map((item) => item['v'])
        : [value];
    names.addAll(values.map(_text).where((text) => text.isNotEmpty));
  }
  return names.take(20).toList(growable: false);
}

String _text(Object? value) => value is String ? value.trim() : '';

final _isDate = RegExp(r'^\d{4}(-\d{2}(-\d{2})?)?$');

String? _date(Object? value) {
  final date = _text(value);
  return _isDate.hasMatch(date) ? date : null;
}

Uri? _cover(Object? value) {
  var url = _text(value);
  if (url.startsWith('//')) url = 'https:$url';
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.isScheme('https') || uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (!const [
    'bgm.tv',
    'bangumi.tv',
    'chii.in',
  ].any((domain) => host == domain || host.endsWith('.$domain'))) {
    return null;
  }
  return uri;
}
