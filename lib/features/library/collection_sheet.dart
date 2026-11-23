import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../anime/anime.dart';

Future<void> showCollectionSheet(
  BuildContext context,
  WidgetRef ref,
  Anime anime,
  FavoriteEntry? current,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: MotionTokens.sheetStyle(context),
  builder: (_) => _CollectionSheet(anime: anime, current: current),
);

class _CollectionSheet extends ConsumerStatefulWidget {
  const _CollectionSheet({required this.anime, required this.current});

  final Anime anime;
  final FavoriteEntry? current;

  @override
  ConsumerState<_CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<_CollectionSheet> {
  late CollectionStatus _status =
      widget.current?.status ?? CollectionStatus.doing;
  late int? _rating = widget.current?.rating;
  late final TextEditingController _comment = TextEditingController(
    text: widget.current?.comment ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save({required bool remove}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final library = ref.read(libraryProvider);
      if (remove) {
        await library.setFavorite(widget.anime, false);
      } else {
        await library.setCollection(
          widget.anime,
          _status,
          rating: _rating,
          comment: _comment.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Exception {
      if (mounted) {
        inform(context, '无法更新追番状态，请重试。');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.lg,
            0,
            SpacingTokens.lg,
            SpacingTokens.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(widget.anime.title),
              const SizedBox(height: SpacingTokens.sm),
              Text('收藏状态', style: type.titleSmall),
              const SizedBox(height: SpacingTokens.xs),
              Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: [
                  for (final status in CollectionStatus.values)
                    SoftButton(
                      label: status.label,
                      selected: _status == status,
                      style: _status == status
                          ? SoftStyle.accent
                          : SoftStyle.outline,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.md),
              Text(
                _rating == null ? '评分（可选）' : '评分：$_rating 分',
                style: type.titleSmall,
              ),
              const SizedBox(height: SpacingTokens.xs),
              Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: [
                  SoftButton(
                    label: '暂无',
                    selected: _rating == null,
                    style: SoftStyle.clear,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _rating = null),
                  ),
                  for (var score = 1; score <= 10; score++)
                    SoftButton(
                      label: '$score',
                      selected: _rating == score,
                      style: _rating == score
                          ? SoftStyle.accent
                          : SoftStyle.outline,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _rating = score),
                    ),
                ],
              ),
              const SizedBox(height: SpacingTokens.md),
              TextField(
                controller: _comment,
                enabled: !_saving,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: '短评或备注（可选）',
                  hintText: '记录观感或进度备注',
                ),
              ),
              const SizedBox(height: SpacingTokens.md),
              SoftButton(
                label: '保存收藏',
                style: SoftStyle.accent,
                onPressed: _saving ? null : () => _save(remove: false),
              ),
              if (widget.current != null) ...[
                const SizedBox(height: SpacingTokens.xs),
                SoftButton(
                  label: '取消追番',
                  style: SoftStyle.outline,
                  onPressed: _saving ? null : () => _save(remove: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
