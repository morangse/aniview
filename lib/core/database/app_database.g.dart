// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    subjectId,
    metadata,
    addedAt,
    status,
    rating,
    comment,
    updatedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final int subjectId;
  final String metadata;
  final int addedAt;
  final int status;
  final int? rating;
  final String? comment;
  final int updatedAt;
  final bool dirty;
  const Favorite({
    required this.subjectId,
    required this.metadata,
    required this.addedAt,
    required this.status,
    this.rating,
    this.comment,
    required this.updatedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_id'] = Variable<int>(subjectId);
    map['metadata'] = Variable<String>(metadata);
    map['added_at'] = Variable<int>(addedAt);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      subjectId: Value(subjectId),
      metadata: Value(metadata),
      addedAt: Value(addedAt),
      status: Value(status),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      updatedAt: Value(updatedAt),
      dirty: Value(dirty),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      subjectId: serializer.fromJson<int>(json['subjectId']),
      metadata: serializer.fromJson<String>(json['metadata']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      status: serializer.fromJson<int>(json['status']),
      rating: serializer.fromJson<int?>(json['rating']),
      comment: serializer.fromJson<String?>(json['comment']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<int>(subjectId),
      'metadata': serializer.toJson<String>(metadata),
      'addedAt': serializer.toJson<int>(addedAt),
      'status': serializer.toJson<int>(status),
      'rating': serializer.toJson<int?>(rating),
      'comment': serializer.toJson<String?>(comment),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  Favorite copyWith({
    int? subjectId,
    String? metadata,
    int? addedAt,
    int? status,
    Value<int?> rating = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    int? updatedAt,
    bool? dirty,
  }) => Favorite(
    subjectId: subjectId ?? this.subjectId,
    metadata: metadata ?? this.metadata,
    addedAt: addedAt ?? this.addedAt,
    status: status ?? this.status,
    rating: rating.present ? rating.value : this.rating,
    comment: comment.present ? comment.value : this.comment,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      status: data.status.present ? data.status.value : this.status,
      rating: data.rating.present ? data.rating.value : this.rating,
      comment: data.comment.present ? data.comment.value : this.comment,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('subjectId: $subjectId, ')
          ..write('metadata: $metadata, ')
          ..write('addedAt: $addedAt, ')
          ..write('status: $status, ')
          ..write('rating: $rating, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    subjectId,
    metadata,
    addedAt,
    status,
    rating,
    comment,
    updatedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.subjectId == this.subjectId &&
          other.metadata == this.metadata &&
          other.addedAt == this.addedAt &&
          other.status == this.status &&
          other.rating == this.rating &&
          other.comment == this.comment &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<int> subjectId;
  final Value<String> metadata;
  final Value<int> addedAt;
  final Value<int> status;
  final Value<int?> rating;
  final Value<String?> comment;
  final Value<int> updatedAt;
  final Value<bool> dirty;
  const FavoritesCompanion({
    this.subjectId = const Value.absent(),
    this.metadata = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rating = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.subjectId = const Value.absent(),
    required String metadata,
    required int addedAt,
    this.status = const Value.absent(),
    this.rating = const Value.absent(),
    this.comment = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
  }) : metadata = Value(metadata),
       addedAt = Value(addedAt);
  static Insertable<Favorite> custom({
    Expression<int>? subjectId,
    Expression<String>? metadata,
    Expression<int>? addedAt,
    Expression<int>? status,
    Expression<int>? rating,
    Expression<String>? comment,
    Expression<int>? updatedAt,
    Expression<bool>? dirty,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subject_id': subjectId,
      if (metadata != null) 'metadata': metadata,
      if (addedAt != null) 'added_at': addedAt,
      if (status != null) 'status': status,
      if (rating != null) 'rating': rating,
      if (comment != null) 'comment': comment,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? subjectId,
    Value<String>? metadata,
    Value<int>? addedAt,
    Value<int>? status,
    Value<int?>? rating,
    Value<String?>? comment,
    Value<int>? updatedAt,
    Value<bool>? dirty,
  }) {
    return FavoritesCompanion(
      subjectId: subjectId ?? this.subjectId,
      metadata: metadata ?? this.metadata,
      addedAt: addedAt ?? this.addedAt,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('metadata: $metadata, ')
          ..write('addedAt: $addedAt, ')
          ..write('status: $status, ')
          ..write('rating: $rating, ')
          ..write('comment: $comment, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }
}

class $MediaEntriesTable extends MediaEntries
    with TableInfo<$MediaEntriesTable, MediaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeLabelMeta = const VerificationMeta(
    'episodeLabel',
  );
  @override
  late final GeneratedColumn<String> episodeLabel = GeneratedColumn<String>(
    'episode_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    location,
    kind,
    title,
    sourceName,
    subjectId,
    episodeId,
    episodeLabel,
    cover,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('episode_label')) {
      context.handle(
        _episodeLabelMeta,
        episodeLabel.isAcceptableOrUnknown(
          data['episode_label']!,
          _episodeLabelMeta,
        ),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      ),
      episodeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_label'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $MediaEntriesTable createAlias(String alias) {
    return $MediaEntriesTable(attachedDatabase, alias);
  }
}

class MediaEntry extends DataClass implements Insertable<MediaEntry> {
  final String id;
  final String location;
  final String kind;
  final String title;
  final String sourceName;
  final int? subjectId;
  final int? episodeId;
  final String? episodeLabel;
  final String? cover;
  final int addedAt;
  const MediaEntry({
    required this.id,
    required this.location,
    required this.kind,
    required this.title,
    required this.sourceName,
    this.subjectId,
    this.episodeId,
    this.episodeLabel,
    this.cover,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['location'] = Variable<String>(location);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['source_name'] = Variable<String>(sourceName);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<int>(subjectId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<int>(episodeId);
    }
    if (!nullToAbsent || episodeLabel != null) {
      map['episode_label'] = Variable<String>(episodeLabel);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  MediaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MediaEntriesCompanion(
      id: Value(id),
      location: Value(location),
      kind: Value(kind),
      title: Value(title),
      sourceName: Value(sourceName),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      episodeLabel: episodeLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeLabel),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      addedAt: Value(addedAt),
    );
  }

  factory MediaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaEntry(
      id: serializer.fromJson<String>(json['id']),
      location: serializer.fromJson<String>(json['location']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      subjectId: serializer.fromJson<int?>(json['subjectId']),
      episodeId: serializer.fromJson<int?>(json['episodeId']),
      episodeLabel: serializer.fromJson<String?>(json['episodeLabel']),
      cover: serializer.fromJson<String?>(json['cover']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'location': serializer.toJson<String>(location),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'sourceName': serializer.toJson<String>(sourceName),
      'subjectId': serializer.toJson<int?>(subjectId),
      'episodeId': serializer.toJson<int?>(episodeId),
      'episodeLabel': serializer.toJson<String?>(episodeLabel),
      'cover': serializer.toJson<String?>(cover),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  MediaEntry copyWith({
    String? id,
    String? location,
    String? kind,
    String? title,
    String? sourceName,
    Value<int?> subjectId = const Value.absent(),
    Value<int?> episodeId = const Value.absent(),
    Value<String?> episodeLabel = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    int? addedAt,
  }) => MediaEntry(
    id: id ?? this.id,
    location: location ?? this.location,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    sourceName: sourceName ?? this.sourceName,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    episodeLabel: episodeLabel.present ? episodeLabel.value : this.episodeLabel,
    cover: cover.present ? cover.value : this.cover,
    addedAt: addedAt ?? this.addedAt,
  );
  MediaEntry copyWithCompanion(MediaEntriesCompanion data) {
    return MediaEntry(
      id: data.id.present ? data.id.value : this.id,
      location: data.location.present ? data.location.value : this.location,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      episodeLabel: data.episodeLabel.present
          ? data.episodeLabel.value
          : this.episodeLabel,
      cover: data.cover.present ? data.cover.value : this.cover,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaEntry(')
          ..write('id: $id, ')
          ..write('location: $location, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('sourceName: $sourceName, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodeId: $episodeId, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('cover: $cover, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    location,
    kind,
    title,
    sourceName,
    subjectId,
    episodeId,
    episodeLabel,
    cover,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaEntry &&
          other.id == this.id &&
          other.location == this.location &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.sourceName == this.sourceName &&
          other.subjectId == this.subjectId &&
          other.episodeId == this.episodeId &&
          other.episodeLabel == this.episodeLabel &&
          other.cover == this.cover &&
          other.addedAt == this.addedAt);
}

class MediaEntriesCompanion extends UpdateCompanion<MediaEntry> {
  final Value<String> id;
  final Value<String> location;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> sourceName;
  final Value<int?> subjectId;
  final Value<int?> episodeId;
  final Value<String?> episodeLabel;
  final Value<String?> cover;
  final Value<int> addedAt;
  final Value<int> rowid;
  const MediaEntriesCompanion({
    this.id = const Value.absent(),
    this.location = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.episodeLabel = const Value.absent(),
    this.cover = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaEntriesCompanion.insert({
    required String id,
    required String location,
    required String kind,
    required String title,
    required String sourceName,
    this.subjectId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.episodeLabel = const Value.absent(),
    this.cover = const Value.absent(),
    required int addedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       location = Value(location),
       kind = Value(kind),
       title = Value(title),
       sourceName = Value(sourceName),
       addedAt = Value(addedAt);
  static Insertable<MediaEntry> custom({
    Expression<String>? id,
    Expression<String>? location,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? sourceName,
    Expression<int>? subjectId,
    Expression<int>? episodeId,
    Expression<String>? episodeLabel,
    Expression<String>? cover,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (location != null) 'location': location,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (sourceName != null) 'source_name': sourceName,
      if (subjectId != null) 'subject_id': subjectId,
      if (episodeId != null) 'episode_id': episodeId,
      if (episodeLabel != null) 'episode_label': episodeLabel,
      if (cover != null) 'cover': cover,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? location,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? sourceName,
    Value<int?>? subjectId,
    Value<int?>? episodeId,
    Value<String?>? episodeLabel,
    Value<String?>? cover,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return MediaEntriesCompanion(
      id: id ?? this.id,
      location: location ?? this.location,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      sourceName: sourceName ?? this.sourceName,
      subjectId: subjectId ?? this.subjectId,
      episodeId: episodeId ?? this.episodeId,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      cover: cover ?? this.cover,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (episodeLabel.present) {
      map['episode_label'] = Variable<String>(episodeLabel.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaEntriesCompanion(')
          ..write('id: $id, ')
          ..write('location: $location, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('sourceName: $sourceName, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodeId: $episodeId, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('cover: $cover, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchSessionsTable extends WatchSessions
    with TableInfo<$WatchSessionsTable, WatchSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _watchedAtMeta = const VerificationMeta(
    'watchedAt',
  );
  @override
  late final GeneratedColumn<int> watchedAt = GeneratedColumn<int>(
    'watched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaId,
    positionMs,
    durationMs,
    completed,
    watchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    } else if (isInserting) {
      context.missing(_completedMeta);
    }
    if (data.containsKey('watched_at')) {
      context.handle(
        _watchedAtMeta,
        watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_watchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId};
  @override
  WatchSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchSession(
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      watchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watched_at'],
      )!,
    );
  }

  @override
  $WatchSessionsTable createAlias(String alias) {
    return $WatchSessionsTable(attachedDatabase, alias);
  }
}

class WatchSession extends DataClass implements Insertable<WatchSession> {
  final String mediaId;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final int watchedAt;
  const WatchSession({
    required this.mediaId,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.watchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['completed'] = Variable<bool>(completed);
    map['watched_at'] = Variable<int>(watchedAt);
    return map;
  }

  WatchSessionsCompanion toCompanion(bool nullToAbsent) {
    return WatchSessionsCompanion(
      mediaId: Value(mediaId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      completed: Value(completed),
      watchedAt: Value(watchedAt),
    );
  }

  factory WatchSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchSession(
      mediaId: serializer.fromJson<String>(json['mediaId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      completed: serializer.fromJson<bool>(json['completed']),
      watchedAt: serializer.fromJson<int>(json['watchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<String>(mediaId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'completed': serializer.toJson<bool>(completed),
      'watchedAt': serializer.toJson<int>(watchedAt),
    };
  }

  WatchSession copyWith({
    String? mediaId,
    int? positionMs,
    int? durationMs,
    bool? completed,
    int? watchedAt,
  }) => WatchSession(
    mediaId: mediaId ?? this.mediaId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    completed: completed ?? this.completed,
    watchedAt: watchedAt ?? this.watchedAt,
  );
  WatchSession copyWithCompanion(WatchSessionsCompanion data) {
    return WatchSession(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      completed: data.completed.present ? data.completed.value : this.completed,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchSession(')
          ..write('mediaId: $mediaId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('watchedAt: $watchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaId, positionMs, durationMs, completed, watchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchSession &&
          other.mediaId == this.mediaId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.completed == this.completed &&
          other.watchedAt == this.watchedAt);
}

class WatchSessionsCompanion extends UpdateCompanion<WatchSession> {
  final Value<String> mediaId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<bool> completed;
  final Value<int> watchedAt;
  final Value<int> rowid;
  const WatchSessionsCompanion({
    this.mediaId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchSessionsCompanion.insert({
    required String mediaId,
    required int positionMs,
    required int durationMs,
    required bool completed,
    required int watchedAt,
    this.rowid = const Value.absent(),
  }) : mediaId = Value(mediaId),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       completed = Value(completed),
       watchedAt = Value(watchedAt);
  static Insertable<WatchSession> custom({
    Expression<String>? mediaId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<bool>? completed,
    Expression<int>? watchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (completed != null) 'completed': completed,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchSessionsCompanion copyWith({
    Value<String>? mediaId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<bool>? completed,
    Value<int>? watchedAt,
    Value<int>? rowid,
  }) {
    return WatchSessionsCompanion(
      mediaId: mediaId ?? this.mediaId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      completed: completed ?? this.completed,
      watchedAt: watchedAt ?? this.watchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<int>(watchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchSessionsCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  final String key;
  final String value;
  const Preference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Preference copyWith({String? key, String? value}) =>
      Preference(key: key ?? this.key, value: value ?? this.value);
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.key == this.key &&
          other.value == this.value);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Preference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetadataCacheTable extends MetadataCache
    with TableInfo<$MetadataCacheTable, MetadataCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetadataCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storedAtMeta = const VerificationMeta(
    'storedAt',
  );
  @override
  late final GeneratedColumn<int> storedAt = GeneratedColumn<int>(
    'stored_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload, expiresAt, storedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metadata_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetadataCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('stored_at')) {
      context.handle(
        _storedAtMeta,
        storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetadataCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetadataCacheData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
      storedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stored_at'],
      )!,
    );
  }

  @override
  $MetadataCacheTable createAlias(String alias) {
    return $MetadataCacheTable(attachedDatabase, alias);
  }
}

class MetadataCacheData extends DataClass
    implements Insertable<MetadataCacheData> {
  final String key;
  final String payload;
  final int expiresAt;
  final int storedAt;
  const MetadataCacheData({
    required this.key,
    required this.payload,
    required this.expiresAt,
    required this.storedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    map['expires_at'] = Variable<int>(expiresAt);
    map['stored_at'] = Variable<int>(storedAt);
    return map;
  }

  MetadataCacheCompanion toCompanion(bool nullToAbsent) {
    return MetadataCacheCompanion(
      key: Value(key),
      payload: Value(payload),
      expiresAt: Value(expiresAt),
      storedAt: Value(storedAt),
    );
  }

  factory MetadataCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetadataCacheData(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
      storedAt: serializer.fromJson<int>(json['storedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'expiresAt': serializer.toJson<int>(expiresAt),
      'storedAt': serializer.toJson<int>(storedAt),
    };
  }

  MetadataCacheData copyWith({
    String? key,
    String? payload,
    int? expiresAt,
    int? storedAt,
  }) => MetadataCacheData(
    key: key ?? this.key,
    payload: payload ?? this.payload,
    expiresAt: expiresAt ?? this.expiresAt,
    storedAt: storedAt ?? this.storedAt,
  );
  MetadataCacheData copyWithCompanion(MetadataCacheCompanion data) {
    return MetadataCacheData(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetadataCacheData(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('storedAt: $storedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, expiresAt, storedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetadataCacheData &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.expiresAt == this.expiresAt &&
          other.storedAt == this.storedAt);
}

class MetadataCacheCompanion extends UpdateCompanion<MetadataCacheData> {
  final Value<String> key;
  final Value<String> payload;
  final Value<int> expiresAt;
  final Value<int> storedAt;
  final Value<int> rowid;
  const MetadataCacheCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetadataCacheCompanion.insert({
    required String key,
    required String payload,
    required int expiresAt,
    required int storedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload),
       expiresAt = Value(expiresAt),
       storedAt = Value(storedAt);
  static Insertable<MetadataCacheData> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<int>? expiresAt,
    Expression<int>? storedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (storedAt != null) 'stored_at': storedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetadataCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<int>? expiresAt,
    Value<int>? storedAt,
    Value<int>? rowid,
  }) {
    return MetadataCacheCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      expiresAt: expiresAt ?? this.expiresAt,
      storedAt: storedAt ?? this.storedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<int>(storedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetadataCacheCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('storedAt: $storedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConfiguredSourcesTable extends ConfiguredSources
    with TableInfo<$ConfiguredSourcesTable, ConfiguredSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConfiguredSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _offlineAllowedMeta = const VerificationMeta(
    'offlineAllowed',
  );
  @override
  late final GeneratedColumn<bool> offlineAllowed = GeneratedColumn<bool>(
    'offline_allowed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("offline_allowed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _subjectTitleMeta = const VerificationMeta(
    'subjectTitle',
  );
  @override
  late final GeneratedColumn<String> subjectTitle = GeneratedColumn<String>(
    'subject_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<int> episodeId = GeneratedColumn<int>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    endpoint,
    userId,
    enabled,
    priority,
    offlineAllowed,
    subjectTitle,
    subjectId,
    episodeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'configured_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfiguredSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('offline_allowed')) {
      context.handle(
        _offlineAllowedMeta,
        offlineAllowed.isAcceptableOrUnknown(
          data['offline_allowed']!,
          _offlineAllowedMeta,
        ),
      );
    }
    if (data.containsKey('subject_title')) {
      context.handle(
        _subjectTitleMeta,
        subjectTitle.isAcceptableOrUnknown(
          data['subject_title']!,
          _subjectTitleMeta,
        ),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConfiguredSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfiguredSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      offlineAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}offline_allowed'],
      )!,
      subjectTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_title'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_id'],
      ),
    );
  }

  @override
  $ConfiguredSourcesTable createAlias(String alias) {
    return $ConfiguredSourcesTable(attachedDatabase, alias);
  }
}

class ConfiguredSource extends DataClass
    implements Insertable<ConfiguredSource> {
  final String id;
  final String kind;
  final String name;
  final String endpoint;
  final String userId;
  final bool enabled;
  final int priority;
  final bool offlineAllowed;
  final String subjectTitle;
  final int? subjectId;
  final int? episodeId;
  const ConfiguredSource({
    required this.id,
    required this.kind,
    required this.name,
    required this.endpoint,
    required this.userId,
    required this.enabled,
    required this.priority,
    required this.offlineAllowed,
    required this.subjectTitle,
    this.subjectId,
    this.episodeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['endpoint'] = Variable<String>(endpoint);
    map['user_id'] = Variable<String>(userId);
    map['enabled'] = Variable<bool>(enabled);
    map['priority'] = Variable<int>(priority);
    map['offline_allowed'] = Variable<bool>(offlineAllowed);
    map['subject_title'] = Variable<String>(subjectTitle);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<int>(subjectId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<int>(episodeId);
    }
    return map;
  }

  ConfiguredSourcesCompanion toCompanion(bool nullToAbsent) {
    return ConfiguredSourcesCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      endpoint: Value(endpoint),
      userId: Value(userId),
      enabled: Value(enabled),
      priority: Value(priority),
      offlineAllowed: Value(offlineAllowed),
      subjectTitle: Value(subjectTitle),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
    );
  }

  factory ConfiguredSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfiguredSource(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      userId: serializer.fromJson<String>(json['userId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      priority: serializer.fromJson<int>(json['priority']),
      offlineAllowed: serializer.fromJson<bool>(json['offlineAllowed']),
      subjectTitle: serializer.fromJson<String>(json['subjectTitle']),
      subjectId: serializer.fromJson<int?>(json['subjectId']),
      episodeId: serializer.fromJson<int?>(json['episodeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'endpoint': serializer.toJson<String>(endpoint),
      'userId': serializer.toJson<String>(userId),
      'enabled': serializer.toJson<bool>(enabled),
      'priority': serializer.toJson<int>(priority),
      'offlineAllowed': serializer.toJson<bool>(offlineAllowed),
      'subjectTitle': serializer.toJson<String>(subjectTitle),
      'subjectId': serializer.toJson<int?>(subjectId),
      'episodeId': serializer.toJson<int?>(episodeId),
    };
  }

  ConfiguredSource copyWith({
    String? id,
    String? kind,
    String? name,
    String? endpoint,
    String? userId,
    bool? enabled,
    int? priority,
    bool? offlineAllowed,
    String? subjectTitle,
    Value<int?> subjectId = const Value.absent(),
    Value<int?> episodeId = const Value.absent(),
  }) => ConfiguredSource(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    endpoint: endpoint ?? this.endpoint,
    userId: userId ?? this.userId,
    enabled: enabled ?? this.enabled,
    priority: priority ?? this.priority,
    offlineAllowed: offlineAllowed ?? this.offlineAllowed,
    subjectTitle: subjectTitle ?? this.subjectTitle,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
  );
  ConfiguredSource copyWithCompanion(ConfiguredSourcesCompanion data) {
    return ConfiguredSource(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      userId: data.userId.present ? data.userId.value : this.userId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      priority: data.priority.present ? data.priority.value : this.priority,
      offlineAllowed: data.offlineAllowed.present
          ? data.offlineAllowed.value
          : this.offlineAllowed,
      subjectTitle: data.subjectTitle.present
          ? data.subjectTitle.value
          : this.subjectTitle,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfiguredSource(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('endpoint: $endpoint, ')
          ..write('userId: $userId, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('offlineAllowed: $offlineAllowed, ')
          ..write('subjectTitle: $subjectTitle, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodeId: $episodeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    endpoint,
    userId,
    enabled,
    priority,
    offlineAllowed,
    subjectTitle,
    subjectId,
    episodeId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfiguredSource &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.endpoint == this.endpoint &&
          other.userId == this.userId &&
          other.enabled == this.enabled &&
          other.priority == this.priority &&
          other.offlineAllowed == this.offlineAllowed &&
          other.subjectTitle == this.subjectTitle &&
          other.subjectId == this.subjectId &&
          other.episodeId == this.episodeId);
}

class ConfiguredSourcesCompanion extends UpdateCompanion<ConfiguredSource> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String> endpoint;
  final Value<String> userId;
  final Value<bool> enabled;
  final Value<int> priority;
  final Value<bool> offlineAllowed;
  final Value<String> subjectTitle;
  final Value<int?> subjectId;
  final Value<int?> episodeId;
  final Value<int> rowid;
  const ConfiguredSourcesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.userId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.offlineAllowed = const Value.absent(),
    this.subjectTitle = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConfiguredSourcesCompanion.insert({
    required String id,
    required String kind,
    required String name,
    this.endpoint = const Value.absent(),
    this.userId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.offlineAllowed = const Value.absent(),
    this.subjectTitle = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name);
  static Insertable<ConfiguredSource> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? endpoint,
    Expression<String>? userId,
    Expression<bool>? enabled,
    Expression<int>? priority,
    Expression<bool>? offlineAllowed,
    Expression<String>? subjectTitle,
    Expression<int>? subjectId,
    Expression<int>? episodeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (endpoint != null) 'endpoint': endpoint,
      if (userId != null) 'user_id': userId,
      if (enabled != null) 'enabled': enabled,
      if (priority != null) 'priority': priority,
      if (offlineAllowed != null) 'offline_allowed': offlineAllowed,
      if (subjectTitle != null) 'subject_title': subjectTitle,
      if (subjectId != null) 'subject_id': subjectId,
      if (episodeId != null) 'episode_id': episodeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConfiguredSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String>? endpoint,
    Value<String>? userId,
    Value<bool>? enabled,
    Value<int>? priority,
    Value<bool>? offlineAllowed,
    Value<String>? subjectTitle,
    Value<int?>? subjectId,
    Value<int?>? episodeId,
    Value<int>? rowid,
  }) {
    return ConfiguredSourcesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      offlineAllowed: offlineAllowed ?? this.offlineAllowed,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      subjectId: subjectId ?? this.subjectId,
      episodeId: episodeId ?? this.episodeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (offlineAllowed.present) {
      map['offline_allowed'] = Variable<bool>(offlineAllowed.value);
    }
    if (subjectTitle.present) {
      map['subject_title'] = Variable<String>(subjectTitle.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<int>(episodeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfiguredSourcesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('endpoint: $endpoint, ')
          ..write('userId: $userId, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('offlineAllowed: $offlineAllowed, ')
          ..write('subjectTitle: $subjectTitle, ')
          ..write('subjectId: $subjectId, ')
          ..write('episodeId: $episodeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResourceMatchesTable extends ResourceMatches
    with TableInfo<$ResourceMatchesTable, ResourceMatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourceMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _episodeKeyMeta = const VerificationMeta(
    'episodeKey',
  );
  @override
  late final GeneratedColumn<String> episodeKey = GeneratedColumn<String>(
    'episode_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceKeyMeta = const VerificationMeta(
    'resourceKey',
  );
  @override
  late final GeneratedColumn<String> resourceKey = GeneratedColumn<String>(
    'resource_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedMeta = const VerificationMeta(
    'confirmed',
  );
  @override
  late final GeneratedColumn<bool> confirmed = GeneratedColumn<bool>(
    'confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("confirmed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    episodeKey,
    resourceKey,
    score,
    reason,
    confirmed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resource_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResourceMatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('episode_key')) {
      context.handle(
        _episodeKeyMeta,
        episodeKey.isAcceptableOrUnknown(data['episode_key']!, _episodeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeKeyMeta);
    }
    if (data.containsKey('resource_key')) {
      context.handle(
        _resourceKeyMeta,
        resourceKey.isAcceptableOrUnknown(
          data['resource_key']!,
          _resourceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resourceKeyMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('confirmed')) {
      context.handle(
        _confirmedMeta,
        confirmed.isAcceptableOrUnknown(data['confirmed']!, _confirmedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {episodeKey, resourceKey};
  @override
  ResourceMatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceMatche(
      episodeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_key'],
      )!,
      resourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_key'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      confirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}confirmed'],
      )!,
    );
  }

  @override
  $ResourceMatchesTable createAlias(String alias) {
    return $ResourceMatchesTable(attachedDatabase, alias);
  }
}

class ResourceMatche extends DataClass implements Insertable<ResourceMatche> {
  final String episodeKey;
  final String resourceKey;
  final int score;
  final String reason;
  final bool confirmed;
  const ResourceMatche({
    required this.episodeKey,
    required this.resourceKey,
    required this.score,
    required this.reason,
    required this.confirmed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['episode_key'] = Variable<String>(episodeKey);
    map['resource_key'] = Variable<String>(resourceKey);
    map['score'] = Variable<int>(score);
    map['reason'] = Variable<String>(reason);
    map['confirmed'] = Variable<bool>(confirmed);
    return map;
  }

  ResourceMatchesCompanion toCompanion(bool nullToAbsent) {
    return ResourceMatchesCompanion(
      episodeKey: Value(episodeKey),
      resourceKey: Value(resourceKey),
      score: Value(score),
      reason: Value(reason),
      confirmed: Value(confirmed),
    );
  }

  factory ResourceMatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResourceMatche(
      episodeKey: serializer.fromJson<String>(json['episodeKey']),
      resourceKey: serializer.fromJson<String>(json['resourceKey']),
      score: serializer.fromJson<int>(json['score']),
      reason: serializer.fromJson<String>(json['reason']),
      confirmed: serializer.fromJson<bool>(json['confirmed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'episodeKey': serializer.toJson<String>(episodeKey),
      'resourceKey': serializer.toJson<String>(resourceKey),
      'score': serializer.toJson<int>(score),
      'reason': serializer.toJson<String>(reason),
      'confirmed': serializer.toJson<bool>(confirmed),
    };
  }

  ResourceMatche copyWith({
    String? episodeKey,
    String? resourceKey,
    int? score,
    String? reason,
    bool? confirmed,
  }) => ResourceMatche(
    episodeKey: episodeKey ?? this.episodeKey,
    resourceKey: resourceKey ?? this.resourceKey,
    score: score ?? this.score,
    reason: reason ?? this.reason,
    confirmed: confirmed ?? this.confirmed,
  );
  ResourceMatche copyWithCompanion(ResourceMatchesCompanion data) {
    return ResourceMatche(
      episodeKey: data.episodeKey.present
          ? data.episodeKey.value
          : this.episodeKey,
      resourceKey: data.resourceKey.present
          ? data.resourceKey.value
          : this.resourceKey,
      score: data.score.present ? data.score.value : this.score,
      reason: data.reason.present ? data.reason.value : this.reason,
      confirmed: data.confirmed.present ? data.confirmed.value : this.confirmed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceMatche(')
          ..write('episodeKey: $episodeKey, ')
          ..write('resourceKey: $resourceKey, ')
          ..write('score: $score, ')
          ..write('reason: $reason, ')
          ..write('confirmed: $confirmed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(episodeKey, resourceKey, score, reason, confirmed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceMatche &&
          other.episodeKey == this.episodeKey &&
          other.resourceKey == this.resourceKey &&
          other.score == this.score &&
          other.reason == this.reason &&
          other.confirmed == this.confirmed);
}

class ResourceMatchesCompanion extends UpdateCompanion<ResourceMatche> {
  final Value<String> episodeKey;
  final Value<String> resourceKey;
  final Value<int> score;
  final Value<String> reason;
  final Value<bool> confirmed;
  final Value<int> rowid;
  const ResourceMatchesCompanion({
    this.episodeKey = const Value.absent(),
    this.resourceKey = const Value.absent(),
    this.score = const Value.absent(),
    this.reason = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourceMatchesCompanion.insert({
    required String episodeKey,
    required String resourceKey,
    required int score,
    required String reason,
    this.confirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : episodeKey = Value(episodeKey),
       resourceKey = Value(resourceKey),
       score = Value(score),
       reason = Value(reason);
  static Insertable<ResourceMatche> custom({
    Expression<String>? episodeKey,
    Expression<String>? resourceKey,
    Expression<int>? score,
    Expression<String>? reason,
    Expression<bool>? confirmed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (episodeKey != null) 'episode_key': episodeKey,
      if (resourceKey != null) 'resource_key': resourceKey,
      if (score != null) 'score': score,
      if (reason != null) 'reason': reason,
      if (confirmed != null) 'confirmed': confirmed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourceMatchesCompanion copyWith({
    Value<String>? episodeKey,
    Value<String>? resourceKey,
    Value<int>? score,
    Value<String>? reason,
    Value<bool>? confirmed,
    Value<int>? rowid,
  }) {
    return ResourceMatchesCompanion(
      episodeKey: episodeKey ?? this.episodeKey,
      resourceKey: resourceKey ?? this.resourceKey,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      confirmed: confirmed ?? this.confirmed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (episodeKey.present) {
      map['episode_key'] = Variable<String>(episodeKey.value);
    }
    if (resourceKey.present) {
      map['resource_key'] = Variable<String>(resourceKey.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (confirmed.present) {
      map['confirmed'] = Variable<bool>(confirmed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourceMatchesCompanion(')
          ..write('episodeKey: $episodeKey, ')
          ..write('resourceKey: $resourceKey, ')
          ..write('score: $score, ')
          ..write('reason: $reason, ')
          ..write('confirmed: $confirmed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaLinksTable extends MediaLinks
    with TableInfo<$MediaLinksTable, MediaLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceKeyMeta = const VerificationMeta(
    'resourceKey',
  );
  @override
  late final GeneratedColumn<String> resourceKey = GeneratedColumn<String>(
    'resource_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaId,
    sourceId,
    resourceKey,
    resourceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('resource_key')) {
      context.handle(
        _resourceKeyMeta,
        resourceKey.isAcceptableOrUnknown(
          data['resource_key']!,
          _resourceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resourceKeyMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId};
  @override
  MediaLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaLink(
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      resourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_key'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
    );
  }

  @override
  $MediaLinksTable createAlias(String alias) {
    return $MediaLinksTable(attachedDatabase, alias);
  }
}

class MediaLink extends DataClass implements Insertable<MediaLink> {
  final String mediaId;
  final String sourceId;
  final String resourceKey;
  final String resourceId;
  const MediaLink({
    required this.mediaId,
    required this.sourceId,
    required this.resourceKey,
    required this.resourceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['source_id'] = Variable<String>(sourceId);
    map['resource_key'] = Variable<String>(resourceKey);
    map['resource_id'] = Variable<String>(resourceId);
    return map;
  }

  MediaLinksCompanion toCompanion(bool nullToAbsent) {
    return MediaLinksCompanion(
      mediaId: Value(mediaId),
      sourceId: Value(sourceId),
      resourceKey: Value(resourceKey),
      resourceId: Value(resourceId),
    );
  }

  factory MediaLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaLink(
      mediaId: serializer.fromJson<String>(json['mediaId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      resourceKey: serializer.fromJson<String>(json['resourceKey']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<String>(mediaId),
      'sourceId': serializer.toJson<String>(sourceId),
      'resourceKey': serializer.toJson<String>(resourceKey),
      'resourceId': serializer.toJson<String>(resourceId),
    };
  }

  MediaLink copyWith({
    String? mediaId,
    String? sourceId,
    String? resourceKey,
    String? resourceId,
  }) => MediaLink(
    mediaId: mediaId ?? this.mediaId,
    sourceId: sourceId ?? this.sourceId,
    resourceKey: resourceKey ?? this.resourceKey,
    resourceId: resourceId ?? this.resourceId,
  );
  MediaLink copyWithCompanion(MediaLinksCompanion data) {
    return MediaLink(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      resourceKey: data.resourceKey.present
          ? data.resourceKey.value
          : this.resourceKey,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaLink(')
          ..write('mediaId: $mediaId, ')
          ..write('sourceId: $sourceId, ')
          ..write('resourceKey: $resourceKey, ')
          ..write('resourceId: $resourceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaId, sourceId, resourceKey, resourceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaLink &&
          other.mediaId == this.mediaId &&
          other.sourceId == this.sourceId &&
          other.resourceKey == this.resourceKey &&
          other.resourceId == this.resourceId);
}

class MediaLinksCompanion extends UpdateCompanion<MediaLink> {
  final Value<String> mediaId;
  final Value<String> sourceId;
  final Value<String> resourceKey;
  final Value<String> resourceId;
  final Value<int> rowid;
  const MediaLinksCompanion({
    this.mediaId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.resourceKey = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaLinksCompanion.insert({
    required String mediaId,
    required String sourceId,
    required String resourceKey,
    required String resourceId,
    this.rowid = const Value.absent(),
  }) : mediaId = Value(mediaId),
       sourceId = Value(sourceId),
       resourceKey = Value(resourceKey),
       resourceId = Value(resourceId);
  static Insertable<MediaLink> custom({
    Expression<String>? mediaId,
    Expression<String>? sourceId,
    Expression<String>? resourceKey,
    Expression<String>? resourceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (sourceId != null) 'source_id': sourceId,
      if (resourceKey != null) 'resource_key': resourceKey,
      if (resourceId != null) 'resource_id': resourceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaLinksCompanion copyWith({
    Value<String>? mediaId,
    Value<String>? sourceId,
    Value<String>? resourceKey,
    Value<String>? resourceId,
    Value<int>? rowid,
  }) {
    return MediaLinksCompanion(
      mediaId: mediaId ?? this.mediaId,
      sourceId: sourceId ?? this.sourceId,
      resourceKey: resourceKey ?? this.resourceKey,
      resourceId: resourceId ?? this.resourceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (resourceKey.present) {
      map['resource_key'] = Variable<String>(resourceKey.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaLinksCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('sourceId: $sourceId, ')
          ..write('resourceKey: $resourceKey, ')
          ..write('resourceId: $resourceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceHealthRowsTable extends SourceHealthRows
    with TableInfo<$SourceHealthRowsTable, SourceHealthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceHealthRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _successesMeta = const VerificationMeta(
    'successes',
  );
  @override
  late final GeneratedColumn<int> successes = GeneratedColumn<int>(
    'successes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failuresMeta = const VerificationMeta(
    'failures',
  );
  @override
  late final GeneratedColumn<int> failures = GeneratedColumn<int>(
    'failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startupMsMeta = const VerificationMeta(
    'startupMs',
  );
  @override
  late final GeneratedColumn<int> startupMs = GeneratedColumn<int>(
    'startup_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _buffersMeta = const VerificationMeta(
    'buffers',
  );
  @override
  late final GeneratedColumn<int> buffers = GeneratedColumn<int>(
    'buffers',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    state,
    successes,
    failures,
    startupMs,
    buffers,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_health_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceHealthRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('successes')) {
      context.handle(
        _successesMeta,
        successes.isAcceptableOrUnknown(data['successes']!, _successesMeta),
      );
    }
    if (data.containsKey('failures')) {
      context.handle(
        _failuresMeta,
        failures.isAcceptableOrUnknown(data['failures']!, _failuresMeta),
      );
    }
    if (data.containsKey('startup_ms')) {
      context.handle(
        _startupMsMeta,
        startupMs.isAcceptableOrUnknown(data['startup_ms']!, _startupMsMeta),
      );
    }
    if (data.containsKey('buffers')) {
      context.handle(
        _buffersMeta,
        buffers.isAcceptableOrUnknown(data['buffers']!, _buffersMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceHealthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceHealthRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      successes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}successes'],
      )!,
      failures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failures'],
      )!,
      startupMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}startup_ms'],
      )!,
      buffers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffers'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SourceHealthRowsTable createAlias(String alias) {
    return $SourceHealthRowsTable(attachedDatabase, alias);
  }
}

class SourceHealthRow extends DataClass implements Insertable<SourceHealthRow> {
  final String id;
  final String state;
  final int successes;
  final int failures;
  final int startupMs;
  final int buffers;
  final int updatedAt;
  const SourceHealthRow({
    required this.id,
    required this.state,
    required this.successes,
    required this.failures,
    required this.startupMs,
    required this.buffers,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['state'] = Variable<String>(state);
    map['successes'] = Variable<int>(successes);
    map['failures'] = Variable<int>(failures);
    map['startup_ms'] = Variable<int>(startupMs);
    map['buffers'] = Variable<int>(buffers);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SourceHealthRowsCompanion toCompanion(bool nullToAbsent) {
    return SourceHealthRowsCompanion(
      id: Value(id),
      state: Value(state),
      successes: Value(successes),
      failures: Value(failures),
      startupMs: Value(startupMs),
      buffers: Value(buffers),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceHealthRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceHealthRow(
      id: serializer.fromJson<String>(json['id']),
      state: serializer.fromJson<String>(json['state']),
      successes: serializer.fromJson<int>(json['successes']),
      failures: serializer.fromJson<int>(json['failures']),
      startupMs: serializer.fromJson<int>(json['startupMs']),
      buffers: serializer.fromJson<int>(json['buffers']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'state': serializer.toJson<String>(state),
      'successes': serializer.toJson<int>(successes),
      'failures': serializer.toJson<int>(failures),
      'startupMs': serializer.toJson<int>(startupMs),
      'buffers': serializer.toJson<int>(buffers),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SourceHealthRow copyWith({
    String? id,
    String? state,
    int? successes,
    int? failures,
    int? startupMs,
    int? buffers,
    int? updatedAt,
  }) => SourceHealthRow(
    id: id ?? this.id,
    state: state ?? this.state,
    successes: successes ?? this.successes,
    failures: failures ?? this.failures,
    startupMs: startupMs ?? this.startupMs,
    buffers: buffers ?? this.buffers,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SourceHealthRow copyWithCompanion(SourceHealthRowsCompanion data) {
    return SourceHealthRow(
      id: data.id.present ? data.id.value : this.id,
      state: data.state.present ? data.state.value : this.state,
      successes: data.successes.present ? data.successes.value : this.successes,
      failures: data.failures.present ? data.failures.value : this.failures,
      startupMs: data.startupMs.present ? data.startupMs.value : this.startupMs,
      buffers: data.buffers.present ? data.buffers.value : this.buffers,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceHealthRow(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('successes: $successes, ')
          ..write('failures: $failures, ')
          ..write('startupMs: $startupMs, ')
          ..write('buffers: $buffers, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    state,
    successes,
    failures,
    startupMs,
    buffers,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceHealthRow &&
          other.id == this.id &&
          other.state == this.state &&
          other.successes == this.successes &&
          other.failures == this.failures &&
          other.startupMs == this.startupMs &&
          other.buffers == this.buffers &&
          other.updatedAt == this.updatedAt);
}

class SourceHealthRowsCompanion extends UpdateCompanion<SourceHealthRow> {
  final Value<String> id;
  final Value<String> state;
  final Value<int> successes;
  final Value<int> failures;
  final Value<int> startupMs;
  final Value<int> buffers;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SourceHealthRowsCompanion({
    this.id = const Value.absent(),
    this.state = const Value.absent(),
    this.successes = const Value.absent(),
    this.failures = const Value.absent(),
    this.startupMs = const Value.absent(),
    this.buffers = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceHealthRowsCompanion.insert({
    required String id,
    required String state,
    this.successes = const Value.absent(),
    this.failures = const Value.absent(),
    this.startupMs = const Value.absent(),
    this.buffers = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       state = Value(state),
       updatedAt = Value(updatedAt);
  static Insertable<SourceHealthRow> custom({
    Expression<String>? id,
    Expression<String>? state,
    Expression<int>? successes,
    Expression<int>? failures,
    Expression<int>? startupMs,
    Expression<int>? buffers,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (state != null) 'state': state,
      if (successes != null) 'successes': successes,
      if (failures != null) 'failures': failures,
      if (startupMs != null) 'startup_ms': startupMs,
      if (buffers != null) 'buffers': buffers,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceHealthRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? state,
    Value<int>? successes,
    Value<int>? failures,
    Value<int>? startupMs,
    Value<int>? buffers,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SourceHealthRowsCompanion(
      id: id ?? this.id,
      state: state ?? this.state,
      successes: successes ?? this.successes,
      failures: failures ?? this.failures,
      startupMs: startupMs ?? this.startupMs,
      buffers: buffers ?? this.buffers,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (successes.present) {
      map['successes'] = Variable<int>(successes.value);
    }
    if (failures.present) {
      map['failures'] = Variable<int>(failures.value);
    }
    if (startupMs.present) {
      map['startup_ms'] = Variable<int>(startupMs.value);
    }
    if (buffers.present) {
      map['buffers'] = Variable<int>(buffers.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceHealthRowsCompanion(')
          ..write('id: $id, ')
          ..write('state: $state, ')
          ..write('successes: $successes, ')
          ..write('failures: $failures, ')
          ..write('startupMs: $startupMs, ')
          ..write('buffers: $buffers, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodeAttachmentsTable extends EpisodeAttachments
    with TableInfo<$EpisodeAttachmentsTable, EpisodeAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeKeyMeta = const VerificationMeta(
    'episodeKey',
  );
  @override
  late final GeneratedColumn<String> episodeKey = GeneratedColumn<String>(
    'episode_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, episodeKey, kind, name, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('episode_key')) {
      context.handle(
        _episodeKeyMeta,
        episodeKey.isAcceptableOrUnknown(data['episode_key']!, _episodeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeKeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpisodeAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      episodeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_key'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $EpisodeAttachmentsTable createAlias(String alias) {
    return $EpisodeAttachmentsTable(attachedDatabase, alias);
  }
}

class EpisodeAttachment extends DataClass
    implements Insertable<EpisodeAttachment> {
  final String id;
  final String episodeKey;
  final String kind;
  final String name;
  final String payload;
  const EpisodeAttachment({
    required this.id,
    required this.episodeKey,
    required this.kind,
    required this.name,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['episode_key'] = Variable<String>(episodeKey);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  EpisodeAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return EpisodeAttachmentsCompanion(
      id: Value(id),
      episodeKey: Value(episodeKey),
      kind: Value(kind),
      name: Value(name),
      payload: Value(payload),
    );
  }

  factory EpisodeAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeAttachment(
      id: serializer.fromJson<String>(json['id']),
      episodeKey: serializer.fromJson<String>(json['episodeKey']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'episodeKey': serializer.toJson<String>(episodeKey),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'payload': serializer.toJson<String>(payload),
    };
  }

  EpisodeAttachment copyWith({
    String? id,
    String? episodeKey,
    String? kind,
    String? name,
    String? payload,
  }) => EpisodeAttachment(
    id: id ?? this.id,
    episodeKey: episodeKey ?? this.episodeKey,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    payload: payload ?? this.payload,
  );
  EpisodeAttachment copyWithCompanion(EpisodeAttachmentsCompanion data) {
    return EpisodeAttachment(
      id: data.id.present ? data.id.value : this.id,
      episodeKey: data.episodeKey.present
          ? data.episodeKey.value
          : this.episodeKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeAttachment(')
          ..write('id: $id, ')
          ..write('episodeKey: $episodeKey, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, episodeKey, kind, name, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeAttachment &&
          other.id == this.id &&
          other.episodeKey == this.episodeKey &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.payload == this.payload);
}

class EpisodeAttachmentsCompanion extends UpdateCompanion<EpisodeAttachment> {
  final Value<String> id;
  final Value<String> episodeKey;
  final Value<String> kind;
  final Value<String> name;
  final Value<String> payload;
  final Value<int> rowid;
  const EpisodeAttachmentsCompanion({
    this.id = const Value.absent(),
    this.episodeKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodeAttachmentsCompanion.insert({
    required String id,
    required String episodeKey,
    required String kind,
    required String name,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       episodeKey = Value(episodeKey),
       kind = Value(kind),
       name = Value(name),
       payload = Value(payload);
  static Insertable<EpisodeAttachment> custom({
    Expression<String>? id,
    Expression<String>? episodeKey,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (episodeKey != null) 'episode_key': episodeKey,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodeAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? episodeKey,
    Value<String>? kind,
    Value<String>? name,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return EpisodeAttachmentsCompanion(
      id: id ?? this.id,
      episodeKey: episodeKey ?? this.episodeKey,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (episodeKey.present) {
      map['episode_key'] = Variable<String>(episodeKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('episodeKey: $episodeKey, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedMeta = const VerificationMeta(
    'received',
  );
  @override
  late final GeneratedColumn<int> received = GeneratedColumn<int>(
    'received',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validatorMeta = const VerificationMeta(
    'validator',
  );
  @override
  late final GeneratedColumn<String> validator = GeneratedColumn<String>(
    'validator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    title,
    state,
    received,
    total,
    validator,
    checksum,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('received')) {
      context.handle(
        _receivedMeta,
        received.isAcceptableOrUnknown(data['received']!, _receivedMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('validator')) {
      context.handle(
        _validatorMeta,
        validator.isAcceptableOrUnknown(data['validator']!, _validatorMeta),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      received: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      ),
      validator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}validator'],
      ),
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DownloadTask extends DataClass implements Insertable<DownloadTask> {
  final String id;
  final String sourceId;
  final String title;
  final String state;
  final int received;
  final int? total;
  final String? validator;
  final String? checksum;
  final String? error;
  const DownloadTask({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.state,
    required this.received,
    this.total,
    this.validator,
    this.checksum,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    map['state'] = Variable<String>(state);
    map['received'] = Variable<int>(received);
    if (!nullToAbsent || total != null) {
      map['total'] = Variable<int>(total);
    }
    if (!nullToAbsent || validator != null) {
      map['validator'] = Variable<String>(validator);
    }
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      title: Value(title),
      state: Value(state),
      received: Value(received),
      total: total == null && nullToAbsent
          ? const Value.absent()
          : Value(total),
      validator: validator == null && nullToAbsent
          ? const Value.absent()
          : Value(validator),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory DownloadTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTask(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      state: serializer.fromJson<String>(json['state']),
      received: serializer.fromJson<int>(json['received']),
      total: serializer.fromJson<int?>(json['total']),
      validator: serializer.fromJson<String?>(json['validator']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'state': serializer.toJson<String>(state),
      'received': serializer.toJson<int>(received),
      'total': serializer.toJson<int?>(total),
      'validator': serializer.toJson<String?>(validator),
      'checksum': serializer.toJson<String?>(checksum),
      'error': serializer.toJson<String?>(error),
    };
  }

  DownloadTask copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? state,
    int? received,
    Value<int?> total = const Value.absent(),
    Value<String?> validator = const Value.absent(),
    Value<String?> checksum = const Value.absent(),
    Value<String?> error = const Value.absent(),
  }) => DownloadTask(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    title: title ?? this.title,
    state: state ?? this.state,
    received: received ?? this.received,
    total: total.present ? total.value : this.total,
    validator: validator.present ? validator.value : this.validator,
    checksum: checksum.present ? checksum.value : this.checksum,
    error: error.present ? error.value : this.error,
  );
  DownloadTask copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTask(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      state: data.state.present ? data.state.value : this.state,
      received: data.received.present ? data.received.value : this.received,
      total: data.total.present ? data.total.value : this.total,
      validator: data.validator.present ? data.validator.value : this.validator,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTask(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('state: $state, ')
          ..write('received: $received, ')
          ..write('total: $total, ')
          ..write('validator: $validator, ')
          ..write('checksum: $checksum, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    title,
    state,
    received,
    total,
    validator,
    checksum,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTask &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.state == this.state &&
          other.received == this.received &&
          other.total == this.total &&
          other.validator == this.validator &&
          other.checksum == this.checksum &&
          other.error == this.error);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTask> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String> state;
  final Value<int> received;
  final Value<int?> total;
  final Value<String?> validator;
  final Value<String?> checksum;
  final Value<String?> error;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.state = const Value.absent(),
    this.received = const Value.absent(),
    this.total = const Value.absent(),
    this.validator = const Value.absent(),
    this.checksum = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String id,
    required String sourceId,
    required String title,
    required String state,
    this.received = const Value.absent(),
    this.total = const Value.absent(),
    this.validator = const Value.absent(),
    this.checksum = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       title = Value(title),
       state = Value(state);
  static Insertable<DownloadTask> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? state,
    Expression<int>? received,
    Expression<int>? total,
    Expression<String>? validator,
    Expression<String>? checksum,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (state != null) 'state': state,
      if (received != null) 'received': received,
      if (total != null) 'total': total,
      if (validator != null) 'validator': validator,
      if (checksum != null) 'checksum': checksum,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? title,
    Value<String>? state,
    Value<int>? received,
    Value<int?>? total,
    Value<String?>? validator,
    Value<String?>? checksum,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      state: state ?? this.state,
      received: received ?? this.received,
      total: total ?? this.total,
      validator: validator ?? this.validator,
      checksum: checksum ?? this.checksum,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (received.present) {
      map['received'] = Variable<int>(received.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (validator.present) {
      map['validator'] = Variable<String>(validator.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('state: $state, ')
          ..write('received: $received, ')
          ..write('total: $total, ')
          ..write('validator: $validator, ')
          ..write('checksum: $checksum, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncSnapshotsTable extends SyncSnapshots
    with TableInfo<$SyncSnapshotsTable, SyncSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncSnapshot(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncSnapshotsTable createAlias(String alias) {
    return $SyncSnapshotsTable(attachedDatabase, alias);
  }
}

class SyncSnapshot extends DataClass implements Insertable<SyncSnapshot> {
  final String key;
  final String value;
  final int updatedAt;
  const SyncSnapshot({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SyncSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SyncSnapshotsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncSnapshot(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SyncSnapshot copyWith({String? key, String? value, int? updatedAt}) =>
      SyncSnapshot(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncSnapshot copyWithCompanion(SyncSnapshotsCompanion data) {
    return SyncSnapshot(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncSnapshot(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncSnapshot &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncSnapshotsCompanion extends UpdateCompanion<SyncSnapshot> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SyncSnapshotsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncSnapshotsCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SyncSnapshot> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncSnapshotsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncSnapshotsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncSnapshotsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $MediaEntriesTable mediaEntries = $MediaEntriesTable(this);
  late final $WatchSessionsTable watchSessions = $WatchSessionsTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $MetadataCacheTable metadataCache = $MetadataCacheTable(this);
  late final $ConfiguredSourcesTable configuredSources =
      $ConfiguredSourcesTable(this);
  late final $ResourceMatchesTable resourceMatches = $ResourceMatchesTable(
    this,
  );
  late final $MediaLinksTable mediaLinks = $MediaLinksTable(this);
  late final $SourceHealthRowsTable sourceHealthRows = $SourceHealthRowsTable(
    this,
  );
  late final $EpisodeAttachmentsTable episodeAttachments =
      $EpisodeAttachmentsTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $SyncSnapshotsTable syncSnapshots = $SyncSnapshotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    favorites,
    mediaEntries,
    watchSessions,
    preferences,
    metadataCache,
    configuredSources,
    resourceMatches,
    mediaLinks,
    sourceHealthRows,
    episodeAttachments,
    downloadTasks,
    syncSnapshots,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('watch_sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_links', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> subjectId,
      required String metadata,
      required int addedAt,
      Value<int> status,
      Value<int?> rating,
      Value<String?> comment,
      Value<int> updatedAt,
      Value<bool> dirty,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> subjectId,
      Value<String> metadata,
      Value<int> addedAt,
      Value<int> status,
      Value<int?> rating,
      Value<String?> comment,
      Value<int> updatedAt,
      Value<bool> dirty,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
              }) => FavoritesCompanion(
                subjectId: subjectId,
                metadata: metadata,
                addedAt: addedAt,
                status: status,
                rating: rating,
                comment: comment,
                updatedAt: updatedAt,
                dirty: dirty,
              ),
          createCompanionCallback:
              ({
                Value<int> subjectId = const Value.absent(),
                required String metadata,
                required int addedAt,
                Value<int> status = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
              }) => FavoritesCompanion.insert(
                subjectId: subjectId,
                metadata: metadata,
                addedAt: addedAt,
                status: status,
                rating: rating,
                comment: comment,
                updatedAt: updatedAt,
                dirty: dirty,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$MediaEntriesTableCreateCompanionBuilder =
    MediaEntriesCompanion Function({
      required String id,
      required String location,
      required String kind,
      required String title,
      required String sourceName,
      Value<int?> subjectId,
      Value<int?> episodeId,
      Value<String?> episodeLabel,
      Value<String?> cover,
      required int addedAt,
      Value<int> rowid,
    });
typedef $$MediaEntriesTableUpdateCompanionBuilder =
    MediaEntriesCompanion Function({
      Value<String> id,
      Value<String> location,
      Value<String> kind,
      Value<String> title,
      Value<String> sourceName,
      Value<int?> subjectId,
      Value<int?> episodeId,
      Value<String?> episodeLabel,
      Value<String?> cover,
      Value<int> addedAt,
      Value<int> rowid,
    });

final class $$MediaEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $MediaEntriesTable, MediaEntry> {
  $$MediaEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WatchSessionsTable, List<WatchSession>>
  _watchSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.watchSessions,
    aliasName: $_aliasNameGenerator(
      db.mediaEntries.id,
      db.watchSessions.mediaId,
    ),
  );

  $$WatchSessionsTableProcessedTableManager get watchSessionsRefs {
    final manager = $$WatchSessionsTableTableManager(
      $_db,
      $_db.watchSessions,
    ).filter((f) => f.mediaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_watchSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MediaLinksTable, List<MediaLink>>
  _mediaLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaLinks,
    aliasName: $_aliasNameGenerator(db.mediaEntries.id, db.mediaLinks.mediaId),
  );

  $$MediaLinksTableProcessedTableManager get mediaLinksRefs {
    final manager = $$MediaLinksTableTableManager(
      $_db,
      $_db.mediaLinks,
    ).filter((f) => f.mediaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MediaEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> watchSessionsRefs(
    Expression<bool> Function($$WatchSessionsTableFilterComposer f) f,
  ) {
    final $$WatchSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchSessions,
      getReferencedColumn: (t) => t.mediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchSessionsTableFilterComposer(
            $db: $db,
            $table: $db.watchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mediaLinksRefs(
    Expression<bool> Function($$MediaLinksTableFilterComposer f) f,
  ) {
    final $$MediaLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaLinks,
      getReferencedColumn: (t) => t.mediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaLinksTableFilterComposer(
            $db: $db,
            $table: $db.mediaLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaEntriesTable> {
  $$MediaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  Expression<T> watchSessionsRefs<T extends Object>(
    Expression<T> Function($$WatchSessionsTableAnnotationComposer a) f,
  ) {
    final $$WatchSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchSessions,
      getReferencedColumn: (t) => t.mediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.watchSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mediaLinksRefs<T extends Object>(
    Expression<T> Function($$MediaLinksTableAnnotationComposer a) f,
  ) {
    final $$MediaLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaLinks,
      getReferencedColumn: (t) => t.mediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaEntriesTable,
          MediaEntry,
          $$MediaEntriesTableFilterComposer,
          $$MediaEntriesTableOrderingComposer,
          $$MediaEntriesTableAnnotationComposer,
          $$MediaEntriesTableCreateCompanionBuilder,
          $$MediaEntriesTableUpdateCompanionBuilder,
          (MediaEntry, $$MediaEntriesTableReferences),
          MediaEntry,
          PrefetchHooks Function({bool watchSessionsRefs, bool mediaLinksRefs})
        > {
  $$MediaEntriesTableTableManager(_$AppDatabase db, $MediaEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<int?> episodeId = const Value.absent(),
                Value<String?> episodeLabel = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaEntriesCompanion(
                id: id,
                location: location,
                kind: kind,
                title: title,
                sourceName: sourceName,
                subjectId: subjectId,
                episodeId: episodeId,
                episodeLabel: episodeLabel,
                cover: cover,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String location,
                required String kind,
                required String title,
                required String sourceName,
                Value<int?> subjectId = const Value.absent(),
                Value<int?> episodeId = const Value.absent(),
                Value<String?> episodeLabel = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                required int addedAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaEntriesCompanion.insert(
                id: id,
                location: location,
                kind: kind,
                title: title,
                sourceName: sourceName,
                subjectId: subjectId,
                episodeId: episodeId,
                episodeLabel: episodeLabel,
                cover: cover,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({watchSessionsRefs = false, mediaLinksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (watchSessionsRefs) db.watchSessions,
                    if (mediaLinksRefs) db.mediaLinks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (watchSessionsRefs)
                        await $_getPrefetchedData<
                          MediaEntry,
                          $MediaEntriesTable,
                          WatchSession
                        >(
                          currentTable: table,
                          referencedTable: $$MediaEntriesTableReferences
                              ._watchSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).watchSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mediaLinksRefs)
                        await $_getPrefetchedData<
                          MediaEntry,
                          $MediaEntriesTable,
                          MediaLink
                        >(
                          currentTable: table,
                          referencedTable: $$MediaEntriesTableReferences
                              ._mediaLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).mediaLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MediaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaEntriesTable,
      MediaEntry,
      $$MediaEntriesTableFilterComposer,
      $$MediaEntriesTableOrderingComposer,
      $$MediaEntriesTableAnnotationComposer,
      $$MediaEntriesTableCreateCompanionBuilder,
      $$MediaEntriesTableUpdateCompanionBuilder,
      (MediaEntry, $$MediaEntriesTableReferences),
      MediaEntry,
      PrefetchHooks Function({bool watchSessionsRefs, bool mediaLinksRefs})
    >;
typedef $$WatchSessionsTableCreateCompanionBuilder =
    WatchSessionsCompanion Function({
      required String mediaId,
      required int positionMs,
      required int durationMs,
      required bool completed,
      required int watchedAt,
      Value<int> rowid,
    });
typedef $$WatchSessionsTableUpdateCompanionBuilder =
    WatchSessionsCompanion Function({
      Value<String> mediaId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<bool> completed,
      Value<int> watchedAt,
      Value<int> rowid,
    });

final class $$WatchSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $WatchSessionsTable, WatchSession> {
  $$WatchSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MediaEntriesTable _mediaIdTable(_$AppDatabase db) =>
      db.mediaEntries.createAlias(
        $_aliasNameGenerator(db.watchSessions.mediaId, db.mediaEntries.id),
      );

  $$MediaEntriesTableProcessedTableManager get mediaId {
    final $_column = $_itemColumn<String>('media_id')!;

    final manager = $$MediaEntriesTableTableManager(
      $_db,
      $_db.mediaEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchSessionsTable> {
  $$WatchSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaEntriesTableFilterComposer get mediaId {
    final $$MediaEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.mediaEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mediaEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchSessionsTable> {
  $$WatchSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaEntriesTableOrderingComposer get mediaId {
    final $$MediaEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.mediaEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.mediaEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchSessionsTable> {
  $$WatchSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  $$MediaEntriesTableAnnotationComposer get mediaId {
    final $$MediaEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.mediaEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchSessionsTable,
          WatchSession,
          $$WatchSessionsTableFilterComposer,
          $$WatchSessionsTableOrderingComposer,
          $$WatchSessionsTableAnnotationComposer,
          $$WatchSessionsTableCreateCompanionBuilder,
          $$WatchSessionsTableUpdateCompanionBuilder,
          (WatchSession, $$WatchSessionsTableReferences),
          WatchSession,
          PrefetchHooks Function({bool mediaId})
        > {
  $$WatchSessionsTableTableManager(_$AppDatabase db, $WatchSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> watchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchSessionsCompanion(
                mediaId: mediaId,
                positionMs: positionMs,
                durationMs: durationMs,
                completed: completed,
                watchedAt: watchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaId,
                required int positionMs,
                required int durationMs,
                required bool completed,
                required int watchedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchSessionsCompanion.insert(
                mediaId: mediaId,
                positionMs: positionMs,
                durationMs: durationMs,
                completed: completed,
                watchedAt: watchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WatchSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaId,
                                referencedTable: $$WatchSessionsTableReferences
                                    ._mediaIdTable(db),
                                referencedColumn: $$WatchSessionsTableReferences
                                    ._mediaIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchSessionsTable,
      WatchSession,
      $$WatchSessionsTableFilterComposer,
      $$WatchSessionsTableOrderingComposer,
      $$WatchSessionsTableAnnotationComposer,
      $$WatchSessionsTableCreateCompanionBuilder,
      $$WatchSessionsTableUpdateCompanionBuilder,
      (WatchSession, $$WatchSessionsTableReferences),
      WatchSession,
      PrefetchHooks Function({bool mediaId})
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$AppDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;
typedef $$MetadataCacheTableCreateCompanionBuilder =
    MetadataCacheCompanion Function({
      required String key,
      required String payload,
      required int expiresAt,
      required int storedAt,
      Value<int> rowid,
    });
typedef $$MetadataCacheTableUpdateCompanionBuilder =
    MetadataCacheCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<int> expiresAt,
      Value<int> storedAt,
      Value<int> rowid,
    });

class $$MetadataCacheTableFilterComposer
    extends Composer<_$AppDatabase, $MetadataCacheTable> {
  $$MetadataCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetadataCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $MetadataCacheTable> {
  $$MetadataCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetadataCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetadataCacheTable> {
  $$MetadataCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);
}

class $$MetadataCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetadataCacheTable,
          MetadataCacheData,
          $$MetadataCacheTableFilterComposer,
          $$MetadataCacheTableOrderingComposer,
          $$MetadataCacheTableAnnotationComposer,
          $$MetadataCacheTableCreateCompanionBuilder,
          $$MetadataCacheTableUpdateCompanionBuilder,
          (
            MetadataCacheData,
            BaseReferences<
              _$AppDatabase,
              $MetadataCacheTable,
              MetadataCacheData
            >,
          ),
          MetadataCacheData,
          PrefetchHooks Function()
        > {
  $$MetadataCacheTableTableManager(_$AppDatabase db, $MetadataCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetadataCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetadataCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetadataCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
                Value<int> storedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetadataCacheCompanion(
                key: key,
                payload: payload,
                expiresAt: expiresAt,
                storedAt: storedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                required int expiresAt,
                required int storedAt,
                Value<int> rowid = const Value.absent(),
              }) => MetadataCacheCompanion.insert(
                key: key,
                payload: payload,
                expiresAt: expiresAt,
                storedAt: storedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetadataCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetadataCacheTable,
      MetadataCacheData,
      $$MetadataCacheTableFilterComposer,
      $$MetadataCacheTableOrderingComposer,
      $$MetadataCacheTableAnnotationComposer,
      $$MetadataCacheTableCreateCompanionBuilder,
      $$MetadataCacheTableUpdateCompanionBuilder,
      (
        MetadataCacheData,
        BaseReferences<_$AppDatabase, $MetadataCacheTable, MetadataCacheData>,
      ),
      MetadataCacheData,
      PrefetchHooks Function()
    >;
typedef $$ConfiguredSourcesTableCreateCompanionBuilder =
    ConfiguredSourcesCompanion Function({
      required String id,
      required String kind,
      required String name,
      Value<String> endpoint,
      Value<String> userId,
      Value<bool> enabled,
      Value<int> priority,
      Value<bool> offlineAllowed,
      Value<String> subjectTitle,
      Value<int?> subjectId,
      Value<int?> episodeId,
      Value<int> rowid,
    });
typedef $$ConfiguredSourcesTableUpdateCompanionBuilder =
    ConfiguredSourcesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> name,
      Value<String> endpoint,
      Value<String> userId,
      Value<bool> enabled,
      Value<int> priority,
      Value<bool> offlineAllowed,
      Value<String> subjectTitle,
      Value<int?> subjectId,
      Value<int?> episodeId,
      Value<int> rowid,
    });

class $$ConfiguredSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $ConfiguredSourcesTable> {
  $$ConfiguredSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get offlineAllowed => $composableBuilder(
    column: $table.offlineAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectTitle => $composableBuilder(
    column: $table.subjectTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConfiguredSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConfiguredSourcesTable> {
  $$ConfiguredSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get offlineAllowed => $composableBuilder(
    column: $table.offlineAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectTitle => $composableBuilder(
    column: $table.subjectTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConfiguredSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConfiguredSourcesTable> {
  $$ConfiguredSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get offlineAllowed => $composableBuilder(
    column: $table.offlineAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectTitle => $composableBuilder(
    column: $table.subjectTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<int> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);
}

class $$ConfiguredSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConfiguredSourcesTable,
          ConfiguredSource,
          $$ConfiguredSourcesTableFilterComposer,
          $$ConfiguredSourcesTableOrderingComposer,
          $$ConfiguredSourcesTableAnnotationComposer,
          $$ConfiguredSourcesTableCreateCompanionBuilder,
          $$ConfiguredSourcesTableUpdateCompanionBuilder,
          (
            ConfiguredSource,
            BaseReferences<
              _$AppDatabase,
              $ConfiguredSourcesTable,
              ConfiguredSource
            >,
          ),
          ConfiguredSource,
          PrefetchHooks Function()
        > {
  $$ConfiguredSourcesTableTableManager(
    _$AppDatabase db,
    $ConfiguredSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConfiguredSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConfiguredSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConfiguredSourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> offlineAllowed = const Value.absent(),
                Value<String> subjectTitle = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<int?> episodeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConfiguredSourcesCompanion(
                id: id,
                kind: kind,
                name: name,
                endpoint: endpoint,
                userId: userId,
                enabled: enabled,
                priority: priority,
                offlineAllowed: offlineAllowed,
                subjectTitle: subjectTitle,
                subjectId: subjectId,
                episodeId: episodeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String name,
                Value<String> endpoint = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> offlineAllowed = const Value.absent(),
                Value<String> subjectTitle = const Value.absent(),
                Value<int?> subjectId = const Value.absent(),
                Value<int?> episodeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConfiguredSourcesCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                endpoint: endpoint,
                userId: userId,
                enabled: enabled,
                priority: priority,
                offlineAllowed: offlineAllowed,
                subjectTitle: subjectTitle,
                subjectId: subjectId,
                episodeId: episodeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConfiguredSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConfiguredSourcesTable,
      ConfiguredSource,
      $$ConfiguredSourcesTableFilterComposer,
      $$ConfiguredSourcesTableOrderingComposer,
      $$ConfiguredSourcesTableAnnotationComposer,
      $$ConfiguredSourcesTableCreateCompanionBuilder,
      $$ConfiguredSourcesTableUpdateCompanionBuilder,
      (
        ConfiguredSource,
        BaseReferences<
          _$AppDatabase,
          $ConfiguredSourcesTable,
          ConfiguredSource
        >,
      ),
      ConfiguredSource,
      PrefetchHooks Function()
    >;
typedef $$ResourceMatchesTableCreateCompanionBuilder =
    ResourceMatchesCompanion Function({
      required String episodeKey,
      required String resourceKey,
      required int score,
      required String reason,
      Value<bool> confirmed,
      Value<int> rowid,
    });
typedef $$ResourceMatchesTableUpdateCompanionBuilder =
    ResourceMatchesCompanion Function({
      Value<String> episodeKey,
      Value<String> resourceKey,
      Value<int> score,
      Value<String> reason,
      Value<bool> confirmed,
      Value<int> rowid,
    });

class $$ResourceMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $ResourceMatchesTable> {
  $$ResourceMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResourceMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResourceMatchesTable> {
  $$ResourceMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResourceMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResourceMatchesTable> {
  $$ResourceMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<bool> get confirmed =>
      $composableBuilder(column: $table.confirmed, builder: (column) => column);
}

class $$ResourceMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResourceMatchesTable,
          ResourceMatche,
          $$ResourceMatchesTableFilterComposer,
          $$ResourceMatchesTableOrderingComposer,
          $$ResourceMatchesTableAnnotationComposer,
          $$ResourceMatchesTableCreateCompanionBuilder,
          $$ResourceMatchesTableUpdateCompanionBuilder,
          (
            ResourceMatche,
            BaseReferences<
              _$AppDatabase,
              $ResourceMatchesTable,
              ResourceMatche
            >,
          ),
          ResourceMatche,
          PrefetchHooks Function()
        > {
  $$ResourceMatchesTableTableManager(
    _$AppDatabase db,
    $ResourceMatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourceMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourceMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourceMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> episodeKey = const Value.absent(),
                Value<String> resourceKey = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<bool> confirmed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResourceMatchesCompanion(
                episodeKey: episodeKey,
                resourceKey: resourceKey,
                score: score,
                reason: reason,
                confirmed: confirmed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String episodeKey,
                required String resourceKey,
                required int score,
                required String reason,
                Value<bool> confirmed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResourceMatchesCompanion.insert(
                episodeKey: episodeKey,
                resourceKey: resourceKey,
                score: score,
                reason: reason,
                confirmed: confirmed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResourceMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResourceMatchesTable,
      ResourceMatche,
      $$ResourceMatchesTableFilterComposer,
      $$ResourceMatchesTableOrderingComposer,
      $$ResourceMatchesTableAnnotationComposer,
      $$ResourceMatchesTableCreateCompanionBuilder,
      $$ResourceMatchesTableUpdateCompanionBuilder,
      (
        ResourceMatche,
        BaseReferences<_$AppDatabase, $ResourceMatchesTable, ResourceMatche>,
      ),
      ResourceMatche,
      PrefetchHooks Function()
    >;
typedef $$MediaLinksTableCreateCompanionBuilder =
    MediaLinksCompanion Function({
      required String mediaId,
      required String sourceId,
      required String resourceKey,
      required String resourceId,
      Value<int> rowid,
    });
typedef $$MediaLinksTableUpdateCompanionBuilder =
    MediaLinksCompanion Function({
      Value<String> mediaId,
      Value<String> sourceId,
      Value<String> resourceKey,
      Value<String> resourceId,
      Value<int> rowid,
    });

final class $$MediaLinksTableReferences
    extends BaseReferences<_$AppDatabase, $MediaLinksTable, MediaLink> {
  $$MediaLinksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaEntriesTable _mediaIdTable(_$AppDatabase db) =>
      db.mediaEntries.createAlias(
        $_aliasNameGenerator(db.mediaLinks.mediaId, db.mediaEntries.id),
      );

  $$MediaEntriesTableProcessedTableManager get mediaId {
    final $_column = $_itemColumn<String>('media_id')!;

    final manager = $$MediaEntriesTableTableManager(
      $_db,
      $_db.mediaEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaLinksTableFilterComposer
    extends Composer<_$AppDatabase, $MediaLinksTable> {
  $$MediaLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaEntriesTableFilterComposer get mediaId {
    final $$MediaEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.mediaEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mediaEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaLinksTable> {
  $$MediaLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaEntriesTableOrderingComposer get mediaId {
    final $$MediaEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.mediaEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.mediaEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaLinksTable> {
  $$MediaLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  $$MediaEntriesTableAnnotationComposer get mediaId {
    final $$MediaEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.mediaEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaLinksTable,
          MediaLink,
          $$MediaLinksTableFilterComposer,
          $$MediaLinksTableOrderingComposer,
          $$MediaLinksTableAnnotationComposer,
          $$MediaLinksTableCreateCompanionBuilder,
          $$MediaLinksTableUpdateCompanionBuilder,
          (MediaLink, $$MediaLinksTableReferences),
          MediaLink,
          PrefetchHooks Function({bool mediaId})
        > {
  $$MediaLinksTableTableManager(_$AppDatabase db, $MediaLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> resourceKey = const Value.absent(),
                Value<String> resourceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaLinksCompanion(
                mediaId: mediaId,
                sourceId: sourceId,
                resourceKey: resourceKey,
                resourceId: resourceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaId,
                required String sourceId,
                required String resourceKey,
                required String resourceId,
                Value<int> rowid = const Value.absent(),
              }) => MediaLinksCompanion.insert(
                mediaId: mediaId,
                sourceId: sourceId,
                resourceKey: resourceKey,
                resourceId: resourceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaId,
                                referencedTable: $$MediaLinksTableReferences
                                    ._mediaIdTable(db),
                                referencedColumn: $$MediaLinksTableReferences
                                    ._mediaIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MediaLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaLinksTable,
      MediaLink,
      $$MediaLinksTableFilterComposer,
      $$MediaLinksTableOrderingComposer,
      $$MediaLinksTableAnnotationComposer,
      $$MediaLinksTableCreateCompanionBuilder,
      $$MediaLinksTableUpdateCompanionBuilder,
      (MediaLink, $$MediaLinksTableReferences),
      MediaLink,
      PrefetchHooks Function({bool mediaId})
    >;
typedef $$SourceHealthRowsTableCreateCompanionBuilder =
    SourceHealthRowsCompanion Function({
      required String id,
      required String state,
      Value<int> successes,
      Value<int> failures,
      Value<int> startupMs,
      Value<int> buffers,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SourceHealthRowsTableUpdateCompanionBuilder =
    SourceHealthRowsCompanion Function({
      Value<String> id,
      Value<String> state,
      Value<int> successes,
      Value<int> failures,
      Value<int> startupMs,
      Value<int> buffers,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SourceHealthRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SourceHealthRowsTable> {
  $$SourceHealthRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successes => $composableBuilder(
    column: $table.successes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startupMs => $composableBuilder(
    column: $table.startupMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get buffers => $composableBuilder(
    column: $table.buffers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceHealthRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceHealthRowsTable> {
  $$SourceHealthRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successes => $composableBuilder(
    column: $table.successes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startupMs => $composableBuilder(
    column: $table.startupMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get buffers => $composableBuilder(
    column: $table.buffers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceHealthRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceHealthRowsTable> {
  $$SourceHealthRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get successes =>
      $composableBuilder(column: $table.successes, builder: (column) => column);

  GeneratedColumn<int> get failures =>
      $composableBuilder(column: $table.failures, builder: (column) => column);

  GeneratedColumn<int> get startupMs =>
      $composableBuilder(column: $table.startupMs, builder: (column) => column);

  GeneratedColumn<int> get buffers =>
      $composableBuilder(column: $table.buffers, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SourceHealthRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceHealthRowsTable,
          SourceHealthRow,
          $$SourceHealthRowsTableFilterComposer,
          $$SourceHealthRowsTableOrderingComposer,
          $$SourceHealthRowsTableAnnotationComposer,
          $$SourceHealthRowsTableCreateCompanionBuilder,
          $$SourceHealthRowsTableUpdateCompanionBuilder,
          (
            SourceHealthRow,
            BaseReferences<
              _$AppDatabase,
              $SourceHealthRowsTable,
              SourceHealthRow
            >,
          ),
          SourceHealthRow,
          PrefetchHooks Function()
        > {
  $$SourceHealthRowsTableTableManager(
    _$AppDatabase db,
    $SourceHealthRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceHealthRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceHealthRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceHealthRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> successes = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<int> startupMs = const Value.absent(),
                Value<int> buffers = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceHealthRowsCompanion(
                id: id,
                state: state,
                successes: successes,
                failures: failures,
                startupMs: startupMs,
                buffers: buffers,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String state,
                Value<int> successes = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<int> startupMs = const Value.absent(),
                Value<int> buffers = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceHealthRowsCompanion.insert(
                id: id,
                state: state,
                successes: successes,
                failures: failures,
                startupMs: startupMs,
                buffers: buffers,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceHealthRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceHealthRowsTable,
      SourceHealthRow,
      $$SourceHealthRowsTableFilterComposer,
      $$SourceHealthRowsTableOrderingComposer,
      $$SourceHealthRowsTableAnnotationComposer,
      $$SourceHealthRowsTableCreateCompanionBuilder,
      $$SourceHealthRowsTableUpdateCompanionBuilder,
      (
        SourceHealthRow,
        BaseReferences<_$AppDatabase, $SourceHealthRowsTable, SourceHealthRow>,
      ),
      SourceHealthRow,
      PrefetchHooks Function()
    >;
typedef $$EpisodeAttachmentsTableCreateCompanionBuilder =
    EpisodeAttachmentsCompanion Function({
      required String id,
      required String episodeKey,
      required String kind,
      required String name,
      required String payload,
      Value<int> rowid,
    });
typedef $$EpisodeAttachmentsTableUpdateCompanionBuilder =
    EpisodeAttachmentsCompanion Function({
      Value<String> id,
      Value<String> episodeKey,
      Value<String> kind,
      Value<String> name,
      Value<String> payload,
      Value<int> rowid,
    });

class $$EpisodeAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeAttachmentsTable> {
  $$EpisodeAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodeAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeAttachmentsTable> {
  $$EpisodeAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodeAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeAttachmentsTable> {
  $$EpisodeAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get episodeKey => $composableBuilder(
    column: $table.episodeKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$EpisodeAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodeAttachmentsTable,
          EpisodeAttachment,
          $$EpisodeAttachmentsTableFilterComposer,
          $$EpisodeAttachmentsTableOrderingComposer,
          $$EpisodeAttachmentsTableAnnotationComposer,
          $$EpisodeAttachmentsTableCreateCompanionBuilder,
          $$EpisodeAttachmentsTableUpdateCompanionBuilder,
          (
            EpisodeAttachment,
            BaseReferences<
              _$AppDatabase,
              $EpisodeAttachmentsTable,
              EpisodeAttachment
            >,
          ),
          EpisodeAttachment,
          PrefetchHooks Function()
        > {
  $$EpisodeAttachmentsTableTableManager(
    _$AppDatabase db,
    $EpisodeAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodeAttachmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> episodeKey = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodeAttachmentsCompanion(
                id: id,
                episodeKey: episodeKey,
                kind: kind,
                name: name,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String episodeKey,
                required String kind,
                required String name,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => EpisodeAttachmentsCompanion.insert(
                id: id,
                episodeKey: episodeKey,
                kind: kind,
                name: name,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpisodeAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodeAttachmentsTable,
      EpisodeAttachment,
      $$EpisodeAttachmentsTableFilterComposer,
      $$EpisodeAttachmentsTableOrderingComposer,
      $$EpisodeAttachmentsTableAnnotationComposer,
      $$EpisodeAttachmentsTableCreateCompanionBuilder,
      $$EpisodeAttachmentsTableUpdateCompanionBuilder,
      (
        EpisodeAttachment,
        BaseReferences<
          _$AppDatabase,
          $EpisodeAttachmentsTable,
          EpisodeAttachment
        >,
      ),
      EpisodeAttachment,
      PrefetchHooks Function()
    >;
typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      required String id,
      required String sourceId,
      required String title,
      required String state,
      Value<int> received,
      Value<int?> total,
      Value<String?> validator,
      Value<String?> checksum,
      Value<String?> error,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> title,
      Value<String> state,
      Value<int> received,
      Value<int?> total,
      Value<String?> validator,
      Value<String?> checksum,
      Value<String?> error,
      Value<int> rowid,
    });

class $$DownloadTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get received => $composableBuilder(
    column: $table.received,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validator => $composableBuilder(
    column: $table.validator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get received => $composableBuilder(
    column: $table.received,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validator => $composableBuilder(
    column: $table.validator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get received =>
      $composableBuilder(column: $table.received, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get validator =>
      $composableBuilder(column: $table.validator, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTable,
          DownloadTask,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (
            DownloadTask,
            BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask>,
          ),
          DownloadTask,
          PrefetchHooks Function()
        > {
  $$DownloadTasksTableTableManager(_$AppDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> received = const Value.absent(),
                Value<int?> total = const Value.absent(),
                Value<String?> validator = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion(
                id: id,
                sourceId: sourceId,
                title: title,
                state: state,
                received: received,
                total: total,
                validator: validator,
                checksum: checksum,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String title,
                required String state,
                Value<int> received = const Value.absent(),
                Value<int?> total = const Value.absent(),
                Value<String?> validator = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                id: id,
                sourceId: sourceId,
                title: title,
                state: state,
                received: received,
                total: total,
                validator: validator,
                checksum: checksum,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTable,
      DownloadTask,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (
        DownloadTask,
        BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask>,
      ),
      DownloadTask,
      PrefetchHooks Function()
    >;
typedef $$SyncSnapshotsTableCreateCompanionBuilder =
    SyncSnapshotsCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SyncSnapshotsTableUpdateCompanionBuilder =
    SyncSnapshotsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SyncSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncSnapshotsTable> {
  $$SyncSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncSnapshotsTable> {
  $$SyncSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncSnapshotsTable> {
  $$SyncSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncSnapshotsTable,
          SyncSnapshot,
          $$SyncSnapshotsTableFilterComposer,
          $$SyncSnapshotsTableOrderingComposer,
          $$SyncSnapshotsTableAnnotationComposer,
          $$SyncSnapshotsTableCreateCompanionBuilder,
          $$SyncSnapshotsTableUpdateCompanionBuilder,
          (
            SyncSnapshot,
            BaseReferences<_$AppDatabase, $SyncSnapshotsTable, SyncSnapshot>,
          ),
          SyncSnapshot,
          PrefetchHooks Function()
        > {
  $$SyncSnapshotsTableTableManager(_$AppDatabase db, $SyncSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncSnapshotsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncSnapshotsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncSnapshotsTable,
      SyncSnapshot,
      $$SyncSnapshotsTableFilterComposer,
      $$SyncSnapshotsTableOrderingComposer,
      $$SyncSnapshotsTableAnnotationComposer,
      $$SyncSnapshotsTableCreateCompanionBuilder,
      $$SyncSnapshotsTableUpdateCompanionBuilder,
      (
        SyncSnapshot,
        BaseReferences<_$AppDatabase, $SyncSnapshotsTable, SyncSnapshot>,
      ),
      SyncSnapshot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$MediaEntriesTableTableManager get mediaEntries =>
      $$MediaEntriesTableTableManager(_db, _db.mediaEntries);
  $$WatchSessionsTableTableManager get watchSessions =>
      $$WatchSessionsTableTableManager(_db, _db.watchSessions);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$MetadataCacheTableTableManager get metadataCache =>
      $$MetadataCacheTableTableManager(_db, _db.metadataCache);
  $$ConfiguredSourcesTableTableManager get configuredSources =>
      $$ConfiguredSourcesTableTableManager(_db, _db.configuredSources);
  $$ResourceMatchesTableTableManager get resourceMatches =>
      $$ResourceMatchesTableTableManager(_db, _db.resourceMatches);
  $$MediaLinksTableTableManager get mediaLinks =>
      $$MediaLinksTableTableManager(_db, _db.mediaLinks);
  $$SourceHealthRowsTableTableManager get sourceHealthRows =>
      $$SourceHealthRowsTableTableManager(_db, _db.sourceHealthRows);
  $$EpisodeAttachmentsTableTableManager get episodeAttachments =>
      $$EpisodeAttachmentsTableTableManager(_db, _db.episodeAttachments);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$SyncSnapshotsTableTableManager get syncSnapshots =>
      $$SyncSnapshotsTableTableManager(_db, _db.syncSnapshots);
}
