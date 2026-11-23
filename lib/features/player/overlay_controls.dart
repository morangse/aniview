import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/soft_controls.dart';
import '../../media/android_media_access.dart';
import '../../media/media.dart';
import '../../media/overlays/danmaku_client.dart';
import '../../media/overlays/danmaku_layout.dart';
import '../../media/overlays/media_overlays.dart';
import '../../media/playback_controller.dart';

final overlayStoreProvider = Provider<OverlayStore>(
  (ref) => OverlayStore(ref.watch(sourceStoreProvider)),
);

final overlayProvider = FutureProvider.autoDispose
    .family<OverlayBundle, MediaCandidate>(
      (ref, media) => ref.watch(overlayStoreProvider).load(media),
      retry: (_, _) => null,
    );

Future<void> showOverlaySettings(
  BuildContext context,
  MediaCandidate media, {
  PlaybackController? controller,
  required bool danmaku,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: MotionTokens.sheetStyle(context),
  builder: (_) => SafeArea(
    top: false,
    child: FractionallySizedBox(
      heightFactor: 0.72,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg,
          0,
          SpacingTokens.lg,
          SpacingTokens.lg,
        ),
        child: danmaku
            ? DanmakuControlPane(media: media, controller: controller)
            : SubtitleAndAudioPane(media: media, controller: controller),
      ),
    ),
  ),
);

Future<void> showDanmakuComposerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MediaCandidate media,
  required PlaybackController controller,
}) async {
  final submitted = await showDialog<({String text, DanmakuMode mode, int color})>(
    context: context,
    builder: (_) => const _DanmakuComposerDialog(),
  );
  if (submitted == null || submitted.text.isEmpty || !context.mounted) return;
  final store = ref.read(overlayStoreProvider);
  final bundle = await store.load(media);
  final row = await store.appendLocalDanmaku(
    media,
    DanmakuItem(
      controller.positionListenable.value.inMilliseconds,
      submitted.mode,
      submitted.text,
      color: submitted.color,
    ),
    currentDanmakuId: bundle.settings.danmakuId,
  );
  final nextSettings = {
    ...bundle.settings.toJson(),
    'danmakuId': row.id,
    'danmakuEnabled': true,
  };
  await store.save(media, nextSettings);
  ref.invalidate(overlayProvider(media));
}

class _DanmakuComposerDialog extends StatefulWidget {
  const _DanmakuComposerDialog();

  @override
  State<_DanmakuComposerDialog> createState() => _DanmakuComposerDialogState();
}

class _DanmakuComposerDialogState extends State<_DanmakuComposerDialog> {
  static const _palette = <({String label, int color})>[
    (label: '白', color: 0xFFFFFFFF),
    (label: '雾蓝', color: 0xFF7FA6C9),
    (label: '金', color: 0xFFF2C94C),
    (label: '绯红', color: 0xFFEB5757),
    (label: '翠绿', color: 0xFF6FCF97),
    (label: '紫罗兰', color: 0xFFBB6BD9),
  ];

  final _textCtrl = TextEditingController();
  DanmakuMode _mode = DanmakuMode.scroll;
  int _color = 0xFFFFFFFF;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _textCtrl.text.trim();
    Navigator.of(context).pop(
      trimmed.isEmpty ? null : (text: trimmed, mode: _mode, color: _color),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('发送本地弹幕'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textCtrl,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: '弹幕内容',
              hintText: '仅保存在本机当前剧集',
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Wrap(
            spacing: SpacingTokens.xs,
            children: [
              for (final m in const [
                (mode: DanmakuMode.scroll, label: '滚动'),
                (mode: DanmakuMode.top, label: '顶部'),
                (mode: DanmakuMode.bottom, label: '底部'),
              ])
                ChoiceChip(
                  label: Text(m.label),
                  selected: _mode == m.mode,
                  onSelected: (_) => setState(() => _mode = m.mode),
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          Wrap(
            spacing: SpacingTokens.xs,
            runSpacing: SpacingTokens.xs,
            children: [
              for (final c in _palette)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: Color(c.color),
                    radius: 7,
                  ),
                  label: Text(c.label),
                  selected: _color == c.color,
                  onSelected: (_) => setState(() => _color = c.color),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: _submit,
        child: const Text('发送'),
      ),
    ],
  );
}

class DanmakuControlPane extends ConsumerStatefulWidget {
  const DanmakuControlPane({
    super.key,
    required this.media,
    this.controller,
    this.onCloseForComposer,
  });

  final MediaCandidate media;
  final PlaybackController? controller;
  final VoidCallback? onCloseForComposer;

  @override
  ConsumerState<DanmakuControlPane> createState() => _DanmakuControlPaneState();
}

class _DanmakuControlPaneState extends ConsumerState<DanmakuControlPane> {
  final Map<String, Object?> _pendingSliders = {};
  bool _busy = false;
  String? _message;

  Future<void> _updateSettings(
    OverlayBundle bundle,
    Map<String, Object?> patch,
  ) async {
    final merged = {...bundle.settings.toJson(), ..._pendingSliders, ...patch};
    await ref.read(overlayStoreProvider).save(widget.media, merged);
    if (mounted) {
      setState(() => _pendingSliders.clear());
      ref.invalidate(overlayProvider(widget.media));
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Exception {
      if (mounted) setState(() => _message = '读取或保存弹幕失败。请检查网络、地址格式或文件权限。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importLocal(OverlayBundle bundle) => _perform(() async {
    final attachment = await const AndroidMediaAccess().pickAttachment();
    if (attachment == null || !mounted) return;
    final row = await ref
        .read(overlayStoreProvider)
        .add(widget.media, 'danmaku', attachment.name, attachment.bytes);
    await _updateSettings(bundle, {'danmakuId': row.id, 'danmakuEnabled': true});
    if (mounted) setState(() => _message = '已导入 ${attachment.name}');
  });

  Future<void> _openOnlineSheet(OverlayBundle bundle) async {
    final endpoint =
        ref.read(danmakuEndpointProvider).value ??
        ref.read(danmakuEndpointsProvider).value?.firstOrNull;
    await showDialog<void>(
      context: context,
      builder: (_) => _OnlineDanmakuDialog(
        media: widget.media,
        initialEndpoint: endpoint,
        onLoaded: (downloaded) async {
          final row = await ref
              .read(overlayStoreProvider)
              .saveDanmakuPayload(
                widget.media,
                downloaded.name,
                downloaded.payload,
              );
          await _updateSettings(bundle, {
            'danmakuId': row.id,
            'danmakuEnabled': true,
          });
          if (mounted) {
            setState(() => _message = '已载入 ${downloaded.count} 条弹幕');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(overlayProvider(widget.media));
    final bundle = source.value;
    if (bundle == null) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: source.hasError
            ? const StatusPanel(icon: Icons.error_outline, title: '无法读取弹幕设置')
            : const LinearProgressIndicator(),
      );
    }
    final liveMap = {...bundle.settings.toJson(), ..._pendingSliders};
    final settings = OverlaySettings.fromJson(Map<String, dynamic>.from(liveMap));
    final tracks = bundle.files
        .where((row) => row.kind == 'danmaku')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('开启弹幕'),
          value: settings.danmakuEnabled,
          onChanged: (value) =>
              unawaited(_updateSettings(bundle, {'danmakuEnabled': value})),
        ),
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xs,
          children: [
            SoftButton(
              label: '在线搜索/链接',
              icon: Icons.cloud_download_outlined,
              onPressed: _busy ? null : () => _openOnlineSheet(bundle),
            ),
            SoftButton(
              label: '本地导入',
              icon: Icons.file_open_outlined,
              style: SoftStyle.outline,
              onPressed: _busy ? null : () => _importLocal(bundle),
            ),
            if (widget.controller != null)
              SoftButton(
                label: '发一条',
                icon: Icons.edit_outlined,
                style: SoftStyle.outline,
                onPressed: _busy
                    ? null
                    : () {
                        widget.onCloseForComposer?.call();
                        unawaited(
                          showDanmakuComposerDialog(
                            context: context,
                            ref: ref,
                            media: widget.media,
                            controller: widget.controller!,
                          ),
                        );
                      },
              ),
          ],
        ),
        if (tracks.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.xs),
          for (final track in tracks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              selected: settings.danmakuId == track.id,
              leading: Icon(
                settings.danmakuId == track.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
              ),
              title: Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => unawaited(
                _updateSettings(bundle, {
                  'danmakuId': track.id,
                  'danmakuEnabled': true,
                }),
              ),
            ),
        ],
        const SizedBox(height: SpacingTokens.sm),
        const Text('显示区域'),
        const SizedBox(height: SpacingTokens.xxs),
        Wrap(
          spacing: SpacingTokens.xs,
          children: [
            for (final area in const [0.25, 0.5, 0.75, 1.0])
              ChoiceChip(
                label: Text('${(area * 100).round()}%'),
                selected: (settings.danmakuArea - area).abs() < 0.05,
                onSelected: (_) => unawaited(
                  _updateSettings(bundle, {'danmakuArea': area}),
                ),
              ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        const Text('类型显示'),
        const SizedBox(height: SpacingTokens.xxs),
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xs,
          children: [
            for (final item in [
              (key: 'danmakuShowScroll', label: '滚动', value: settings.danmakuShowScroll),
              (key: 'danmakuShowTop', label: '顶部', value: settings.danmakuShowTop),
              (key: 'danmakuShowBottom', label: '底部', value: settings.danmakuShowBottom),
              (key: 'danmakuShowColor', label: '彩色', value: settings.danmakuShowColor),
            ])
              FilterChip(
                label: Text(item.label),
                selected: item.value,
                onSelected: (selected) => unawaited(
                  _updateSettings(bundle, {item.key: selected}),
                ),
              ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          '时间偏移 ${(settings.danmakuOffset / 1000).toStringAsFixed(2)} 秒',
        ),
        Wrap(
          spacing: SpacingTokens.xs,
          children: [
            SoftButton(
              label: '-0.25s',
              onPressed: () => unawaited(
                _updateSettings(bundle, {
                  'danmakuOffset': (settings.danmakuOffset - 250).clamp(
                    -300000,
                    300000,
                  ),
                }),
              ),
            ),
            SoftButton(
              label: '+0.25s',
              onPressed: () => unawaited(
                _updateSettings(bundle, {
                  'danmakuOffset': (settings.danmakuOffset + 250).clamp(
                    -300000,
                    300000,
                  ),
                }),
              ),
            ),
            SoftButton(
              label: '归零',
              style: SoftStyle.clear,
              onPressed: () =>
                  unawaited(_updateSettings(bundle, {'danmakuOffset': 0})),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.xs),
        _liveSlider(
          bundle,
          label: '不透明度',
          keyName: 'danmakuOpacity',
          value: settings.danmakuOpacity,
          min: 0.1,
          max: 1.0,
        ),
        _liveSlider(
          bundle,
          label: '速度',
          keyName: 'danmakuSpeed',
          value: settings.danmakuSpeed,
          min: 0.6,
          max: 1.7,
        ),
        _liveSlider(
          bundle,
          label: '字号',
          keyName: 'danmakuSize',
          value: settings.danmakuSize,
          min: 12,
          max: 28,
        ),
        _liveSlider(
          bundle,
          label: '同屏上限',
          keyName: 'danmakuLimit',
          value: settings.danmakuLimit.toDouble(),
          min: 4,
          max: 60,
          integer: true,
        ),
        TextFormField(
          key: ValueKey('blocked-${settings.blocked.join(",")}'),
          initialValue: settings.blocked.join('，'),
          decoration: const InputDecoration(labelText: '屏蔽词（逗号分隔，提交后生效）'),
          onFieldSubmitted: (value) => unawaited(
            _updateSettings(bundle, {
              'blocked': value
                  .split(RegExp('[,，]'))
                  .map((w) => w.trim())
                  .where((w) => w.isNotEmpty)
                  .take(100)
                  .toList(),
            }),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: SpacingTokens.xs),
          Text(_message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _liveSlider(
    OverlayBundle bundle, {
    required String label,
    required String keyName,
    required double value,
    required double min,
    required double max,
    bool integer = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label  ${value.toStringAsFixed(integer || max >= 10 ? 0 : 2)}'),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: (next) => setState(
          () => _pendingSliders[keyName] = integer ? next.round() : next,
        ),
        onChangeEnd: (next) => unawaited(
          _updateSettings(bundle, {
            keyName: integer ? next.round() : next,
          }),
        ),
      ),
    ],
  );
}

class SubtitleAndAudioPane extends ConsumerStatefulWidget {
  const SubtitleAndAudioPane({
    super.key,
    required this.media,
    this.controller,
    this.runCommand,
  });

  final MediaCandidate media;
  final PlaybackController? controller;
  final Future<void> Function(Future<void> Function() command)? runCommand;

  @override
  ConsumerState<SubtitleAndAudioPane> createState() =>
      _SubtitleAndAudioPaneState();
}

class _SubtitleAndAudioPaneState extends ConsumerState<SubtitleAndAudioPane> {
  final Map<String, Object?> _pendingSliders = {};
  bool _busy = false;
  String? _message;

  Future<void> _updateSettings(
    OverlayBundle bundle,
    Map<String, Object?> patch,
  ) async {
    final merged = {...bundle.settings.toJson(), ..._pendingSliders, ...patch};
    await ref.read(overlayStoreProvider).save(widget.media, merged);
    if (mounted) {
      setState(() => _pendingSliders.clear());
      ref.invalidate(overlayProvider(widget.media));
    }
  }

  Future<void> _importSubtitle(OverlayBundle bundle) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final attachment = await const AndroidMediaAccess().pickAttachment();
      if (attachment == null || !mounted) return;
      final row = await ref
          .read(overlayStoreProvider)
          .add(widget.media, 'subtitle', attachment.name, attachment.bytes);
      await _updateSettings(bundle, {'subtitleId': row.id});
      if (mounted) setState(() => _message = '已加载 ${attachment.name}');
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Exception {
      if (mounted) setState(() => _message = '读取或保存字幕失败，请检查文件权限。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exec(Future<void> Function() command) async {
    final runner = widget.runCommand;
    if (runner != null) {
      await runner(command);
    } else {
      await command();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundle = ref.watch(overlayProvider(widget.media)).value;
    final liveMap = bundle == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from({
            ...bundle.settings.toJson(),
            ..._pendingSliders,
          });
    final settings = OverlaySettings.fromJson(liveMap);
    final tracks =
        bundle?.files
            .where((row) => row.kind == 'subtitle')
            .toList(growable: false) ??
        const [];
    final selectedExternal = settings.subtitleId == null
        ? null
        : tracks.where((r) => r.id == settings.subtitleId).firstOrNull;
    final isSelectedAss =
        selectedExternal != null &&
        SubtitleManager.isAssFilename(selectedExternal.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller != null)
          ValueListenableBuilder<PlaybackViewState>(
            valueListenable: controller,
            builder: (_, state, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.audioTracks.isNotEmpty) ...[
                  const SectionHeading('内嵌音轨'),
                  const SizedBox(height: SpacingTokens.xs),
                  Wrap(
                    spacing: SpacingTokens.xs,
                    runSpacing: SpacingTokens.xs,
                    children: [
                      for (final track in [
                        (id: 'auto', label: '自动'),
                        ...state.audioTracks,
                      ])
                        SoftButton(
                          label: track.label.isEmpty
                              ? '音轨 ${track.id}'
                              : track.label,
                          selected: state.selectedAudio == track.id,
                          onPressed: () =>
                              _exec(() => controller.setAudioTrack(track.id)),
                        ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.md),
                ],
                if (state.subtitles.isNotEmpty) ...[
                  const SectionHeading('内嵌字幕轨'),
                  const SizedBox(height: SpacingTokens.xs),
                  Wrap(
                    spacing: SpacingTokens.xs,
                    runSpacing: SpacingTokens.xs,
                    children: [
                      for (final track in [
                        (id: 'no', label: '关闭'),
                        (id: 'auto', label: '自动'),
                        ...state.subtitles,
                      ])
                        SoftButton(
                          label: track.label.isEmpty
                              ? '字幕 ${track.id}'
                              : track.label,
                          selected: state.selectedSubtitle == track.id,
                          onPressed: () =>
                              _exec(() => controller.setSubtitle(track.id)),
                        ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.md),
                ],
              ],
            ),
          ),
        const SectionHeading('外挂字幕'),
        const SizedBox(height: SpacingTokens.xs),
        if (bundle == null)
          const LinearProgressIndicator()
        else ...[
          SoftButton(
            label: '导入 SRT / VTT / ASS',
            icon: Icons.file_open_outlined,
            onPressed: _busy ? null : () => _importSubtitle(bundle),
          ),
          for (final track in tracks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              selected: settings.subtitleId == track.id,
              title: Text(
                track.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle:
                  SubtitleManager.stem(track.name) ==
                      SubtitleManager.stem(widget.media.sourceName)
                  ? const Text('与视频文件同名')
                  : null,
              leading: Icon(
                settings.subtitleId == track.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
              ),
              onTap: () => unawaited(
                _updateSettings(bundle, {'subtitleId': track.id}),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: SoftButton(
              label: '关闭外挂字幕',
              selected: settings.subtitleId == null,
              style: SoftStyle.clear,
              onPressed: () =>
                  unawaited(_updateSettings(bundle, {'subtitleId': null})),
            ),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            '时间偏移 ${(settings.subtitleOffset / 1000).toStringAsFixed(2)} 秒',
          ),
          Wrap(
            spacing: SpacingTokens.xs,
            children: [
              SoftButton(
                label: '提前 0.25 秒',
                onPressed: () => unawaited(
                  _updateSettings(bundle, {
                    'subtitleOffset': (settings.subtitleOffset - 250).clamp(
                      -300000,
                      300000,
                    ),
                  }),
                ),
              ),
              SoftButton(
                label: '延后 0.25 秒',
                onPressed: () => unawaited(
                  _updateSettings(bundle, {
                    'subtitleOffset': (settings.subtitleOffset + 250).clamp(
                      -300000,
                      300000,
                    ),
                  }),
                ),
              ),
              SoftButton(
                label: '归零',
                style: SoftStyle.clear,
                onPressed: () =>
                    unawaited(_updateSettings(bundle, {'subtitleOffset': 0})),
              ),
            ],
          ),
          if (isSelectedAss) ...[
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'ASS / SSA 字幕由内置 libass 渲染，保留原始特效与排版；仅时间偏移生效。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            _slider(
              bundle,
              label: '字号',
              keyName: 'subtitleSize',
              value: settings.subtitleSize,
              min: 12,
              max: 32,
            ),
            _slider(
              bundle,
              label: '纵向位置',
              keyName: 'subtitlePosition',
              value: settings.subtitlePosition,
              min: 0.08,
              max: 0.94,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('描边'),
              value: settings.subtitleOutline,
              onChanged: (value) => unawaited(
                _updateSettings(bundle, {'subtitleOutline': value}),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('阴影'),
              value: settings.subtitleShadow,
              onChanged: (value) => unawaited(
                _updateSettings(bundle, {'subtitleShadow': value}),
              ),
            ),
          ],
          if (_message != null) Text(_message!),
        ],
      ],
    );
  }

  Widget _slider(
    OverlayBundle bundle, {
    required String label,
    required String keyName,
    required double value,
    required double min,
    required double max,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label  ${value.toStringAsFixed(max >= 10 ? 0 : 2)}'),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: (v) => setState(() => _pendingSliders[keyName] = v),
        onChangeEnd: (v) =>
            unawaited(_updateSettings(bundle, {keyName: v})),
      ),
    ],
  );
}

class PlayerOverlays extends ConsumerStatefulWidget {
  const PlayerOverlays({
    super.key,
    required this.media,
    required this.controller,
  });
  final MediaCandidate media;
  final PlaybackController controller;

  @override
  ConsumerState<PlayerOverlays> createState() => _PlayerOverlaysState();
}

class _PlayerOverlaysState extends ConsumerState<PlayerOverlays> {
  String? _appliedAssId;
  int? _appliedAssDelay;
  bool _hadExternalAss = false;
  bool _syncedInitial = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerStateChanged);
  }

  @override
  void didUpdateWidget(PlayerOverlays oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerStateChanged);
      widget.controller.addListener(_onControllerStateChanged);
      _resetAssTracking();
    } else if (oldWidget.media != widget.media) {
      _resetAssTracking();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    super.dispose();
  }

  void _resetAssTracking() {
    _appliedAssId = null;
    _appliedAssDelay = null;
    _hadExternalAss = false;
    _syncedInitial = false;
  }

  void _onControllerStateChanged() {
    if (!mounted || !widget.controller.value.ready) return;
    final bundle = ref.read(overlayProvider(widget.media)).value;
    if (bundle != null) unawaited(_syncAss(bundle));
  }

  Future<void> _syncAss(OverlayBundle? bundle) async {
    if (!mounted || bundle == null || !widget.controller.value.ready) return;
    final ass = bundle.assSubtitle;
    try {
      if (ass != null) {
        if (_appliedAssId != ass.id) {
          _appliedAssId = ass.id;
          _hadExternalAss = true;
          await widget.controller.setExternalSubtitle(
            payload: ass.payload,
            title: ass.name,
          );
        }
        final delay = bundle.settings.subtitleOffset;
        if (_appliedAssDelay != delay) {
          _appliedAssDelay = delay;
          await widget.controller.setSubtitleDelayMs(delay);
        }
      } else if (_hadExternalAss) {
        _appliedAssId = null;
        _appliedAssDelay = null;
        _hadExternalAss = false;
        await widget.controller.clearExternalSubtitle();
        await widget.controller.setSubtitleDelayMs(0);
      }
    } on Exception {
      // External subtitle sync is best-effort if the controller closes mid-call.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<OverlayBundle>>(
      overlayProvider(widget.media),
      (_, next) => unawaited(_syncAss(next.value)),
    );
    final bundle = ref.watch(overlayProvider(widget.media)).value;
    if (bundle == null) return const SizedBox.shrink();
    if (!_syncedInitial && widget.controller.value.ready) {
      _syncedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_syncAss(bundle));
      });
    }
    final settings = bundle.settings;
    final subtitle = bundle.subtitle;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (settings.danmakuEnabled && bundle.danmaku != null)
            RepaintBoundary(
              child: _DanmakuLayer(
                controller: widget.controller,
                settings: settings,
                track: bundle.danmaku!,
              ),
            ),
          if (subtitle != null)
            ValueListenableBuilder<Duration>(
              valueListenable: widget.controller.positionListenable,
              builder: (_, position, _) {
                final text = subtitle.textAt(
                  position,
                  offsetMs: settings.subtitleOffset,
                );
                if (text.isEmpty) return const SizedBox.shrink();
                final style = TextStyle(
                  color: ColorTokens.text,
                  fontSize: settings.subtitleSize,
                  fontWeight: FontWeight.w600,
                  shadows: settings.subtitleShadow
                      ? const [
                          Shadow(
                            color: ColorTokens.shadow,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                );
                final alignment = Alignment(
                  0,
                  settings.subtitlePosition * 2 - 1,
                );
                return Align(
                  alignment: alignment,
                  child: Padding(
                    padding: SpacingTokens.horizontal,
                    child: Stack(
                      children: [
                        if (settings.subtitleOutline)
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: settings.subtitleSize,
                              fontWeight: FontWeight.w600,
                              foreground: Paint()
                                ..color = ColorTokens.shadow
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3,
                            ),
                          ),
                        Text(text, textAlign: TextAlign.center, style: style),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DanmakuLayer extends StatefulWidget {
  const _DanmakuLayer({
    required this.controller,
    required this.settings,
    required this.track,
  });
  final PlaybackController controller;
  final OverlaySettings settings;
  final DanmakuTrack track;

  @override
  State<_DanmakuLayer> createState() => _DanmakuLayerState();
}

class _DanmakuLayerState extends State<_DanmakuLayer>
    with SingleTickerProviderStateMixin {
  static const _maxCacheEntries = 300;

  late final Ticker _ticker;
  final _refresh = ValueNotifier<int>(0);
  final _clock = Stopwatch();
  final _layout = DanmakuLayoutEngine();
  final _cache = <String, TextPainter>{};
  Duration _position = Duration.zero;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _refresh.value++);
    widget.controller.addListener(_sync);
    widget.controller.positionListenable.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(_DanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      oldWidget.controller.positionListenable.removeListener(_sync);
      widget.controller.addListener(_sync);
      widget.controller.positionListenable.addListener(_sync);
      _sync();
    }
    if (oldWidget.settings.danmakuSize != widget.settings.danmakuSize ||
        oldWidget.settings.danmakuOpacity != widget.settings.danmakuOpacity ||
        oldWidget.settings.danmakuShowColor != widget.settings.danmakuShowColor) {
      _clearPainterCache();
    }
    if (!identical(oldWidget.track, widget.track)) {
      _layout.reset();
    }
  }

  void _clearPainterCache() {
    for (final painter in _cache.values) {
      painter.dispose();
    }
    _cache.clear();
  }

  TextPainter _painterFor(DanmakuItem item) {
    final effectiveColor = widget.settings.danmakuShowColor
        ? item.color
        : 0xFFFFFFFF;
    final key = '$effectiveColor:${item.text}';
    final existing = _cache.remove(key);
    if (existing != null) {
      _cache[key] = existing;
      return existing;
    }
    if (_cache.length >= _maxCacheEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey)?.dispose();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          color: Color(
            effectiveColor,
          ).withValues(alpha: widget.settings.danmakuOpacity),
          fontSize: widget.settings.danmakuSize,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: ColorTokens.shadow, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _cache[key] = painter;
    return painter;
  }

  void _sync() {
    final state = widget.controller.value;
    final position = widget.controller.positionListenable.value;
    final moving = state.playing && !state.buffering;
    if (_position != position || moving != _moving) {
      _position = position;
      _clock
        ..stop()
        ..reset();
      if (moving) _clock.start();
    }
    _moving = moving;
    if (moving && !_ticker.isActive) _ticker.start();
    if (!moving && _ticker.isActive) _ticker.stop();
    _refresh.value++;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    widget.controller.positionListenable.removeListener(_sync);
    _clearPainterCache();
    _ticker.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DanmakuPainter(
      widget.settings,
      widget.track,
      _layout,
      _painterFor,
      _refresh,
      () =>
          _position.inMilliseconds +
          (_clock.elapsedMilliseconds * widget.controller.value.rate).round(),
    ),
  );
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter(
    this.settings,
    this.track,
    this.layoutEngine,
    this.painterFor,
    Listenable refresh,
    this.now,
  ) : super(repaint: refresh);

  final OverlaySettings settings;
  final DanmakuTrack track;
  final DanmakuLayoutEngine layoutEngine;
  final TextPainter Function(DanmakuItem item) painterFor;
  final int Function() now;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = now() - settings.danmakuOffset;
    final life = (6500 / settings.danmakuSpeed).round();
    final placements = layoutEngine.layout(
      track: track,
      ms: ms,
      lifeMs: life,
      limit: settings.danmakuLimit,
      blocked: settings.blocked,
      viewportWidth: size.width,
      viewportHeight: size.height,
      fontSize: settings.danmakuSize,
      measureWidth: (item) => painterFor(item).width,
      areaRatio: settings.danmakuArea,
      showScroll: settings.danmakuShowScroll,
      showTop: settings.danmakuShowTop,
      showBottom: settings.danmakuShowBottom,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final placed in placements) {
      painterFor(placed.item).paint(canvas, Offset(placed.left, placed.top));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) =>
      oldDelegate.settings != settings ||
      !identical(oldDelegate.track, track) ||
      !identical(oldDelegate.layoutEngine, layoutEngine);
}

typedef _DownloadedDanmaku = ({String name, String payload, int count});

class _OnlineDanmakuDialog extends ConsumerStatefulWidget {
  const _OnlineDanmakuDialog({
    required this.media,
    required this.initialEndpoint,
    required this.onLoaded,
  });

  final MediaCandidate media;
  final String? initialEndpoint;
  final Future<void> Function(_DownloadedDanmaku downloaded) onLoaded;

  @override
  ConsumerState<_OnlineDanmakuDialog> createState() =>
      _OnlineDanmakuDialogState();
}

class _OnlineDanmakuDialogState extends ConsumerState<_OnlineDanmakuDialog> {
  late final _animeCtrl = TextEditingController(
    text: DanmakuClient.suggestSearchKeyword(widget.media.title),
  );
  final _urlCtrl = TextEditingController();
  late final _endpointCtrl = TextEditingController(
    text: widget.initialEndpoint ?? '',
  );
  List<DanmakuEpisodeMatch>? _matches;
  String? _dialogError;
  bool _searching = false;

  @override
  void dispose() {
    _animeCtrl.dispose();
    _urlCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  String _shortEndpointLabel(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return raw;
    final path = uri.path.replaceFirst(RegExp(r'^/+|/+$'), '');
    if (path.isEmpty) return uri.host;
    final shortPath = path.length > 10 ? '${path.substring(0, 10)}…' : path;
    return '${uri.host}/$shortPath';
  }

  Future<void> _runBusy(
    Future<void> Function() task,
    String fallbackError,
  ) async {
    setState(() {
      _searching = true;
      _dialogError = null;
    });
    try {
      await task();
    } on Exception catch (err) {
      if (mounted) {
        setState(
          () => _dialogError = DanmakuClient.describeError(
            err,
            fallback: fallbackError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _runSearch() => _runBusy(() async {
    final normalized = DanmakuClient.normalizeEndpoint(
      _endpointCtrl.text.trim(),
    ).toString();
    await ref.read(libraryProvider).addDanmakuEndpoint(normalized);
    ref.invalidate(danmakuEndpointProvider);
    ref.invalidate(danmakuEndpointsProvider);
    final found = await ref
        .read(danmakuClientProvider)
        .searchEpisodes(
          normalized,
          anime: _animeCtrl.text,
          episode: widget.media.episodeLabel,
        );
    final ordered = DanmakuClient.prioritizeMatches(
      found,
      episodeLabel: widget.media.episodeLabel,
    );
    if (!mounted) return;
    setState(() {
      _endpointCtrl.text = normalized;
      _matches = ordered;
      if (ordered.isEmpty) _dialogError = '未搜到匹配剧集，请调整或精简番剧关键词。';
    });
  }, '请求弹幕服务器失败，请检查地址和网络。');

  Future<void> _loadMatchedEpisode(DanmakuEpisodeMatch match) => _runBusy(() async {
    final downloaded = await ref
        .read(danmakuClientProvider)
        .fetchComments(
          _endpointCtrl.text.trim(),
          match.episodeId,
          title: '${match.animeTitle} ${match.episodeTitle}',
        );
    await widget.onLoaded(downloaded);
    if (mounted) Navigator.of(context).pop();
  }, '拉取该集弹幕失败。');

  Future<void> _loadDirectUrl() => _runBusy(() async {
    final downloaded = await ref
        .read(danmakuClientProvider)
        .fetchDirectUrl(_urlCtrl.text);
    await widget.onLoaded(downloaded);
    if (mounted) Navigator.of(context).pop();
  }, '下载弹幕链接失败，请确认地址可访问。');

  @override
  Widget build(BuildContext context) {
    final savedEndpoints =
        ref.watch(danmakuEndpointsProvider).value ?? const <String>[];
    final currentEndpoint = _endpointCtrl.text.trim();
    return AlertDialog(
      title: const Text('在线弹幕'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (savedEndpoints.isNotEmpty) ...[
                Wrap(
                  spacing: SpacingTokens.xs,
                  runSpacing: SpacingTokens.xs,
                  children: [
                    for (final endpoint in savedEndpoints)
                      ChoiceChip(
                        label: Text(_shortEndpointLabel(endpoint)),
                        selected: endpoint == currentEndpoint,
                        onSelected: _searching
                            ? null
                            : (_) {
                                setState(() {
                                  _endpointCtrl.text = endpoint;
                                  _dialogError = null;
                                });
                                unawaited(
                                  ref
                                      .read(libraryProvider)
                                      .selectDanmakuEndpoint(endpoint),
                                );
                              },
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.xs),
              ],
              TextField(
                controller: _endpointCtrl,
                enabled: !_searching,
                decoration: const InputDecoration(
                  labelText: '兼容弹弹play协议服务器地址',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: SpacingTokens.xs),
              TextField(
                controller: _animeCtrl,
                enabled: !_searching,
                decoration: const InputDecoration(labelText: '番剧关键词'),
              ),
              const SizedBox(height: SpacingTokens.xs),
              SoftButton(
                label: '搜索剧集弹幕',
                icon: Icons.search_rounded,
                onPressed: _searching ? null : _runSearch,
              ),
              if (_searching) ...[
                const SizedBox(height: SpacingTokens.xs),
                const LinearProgressIndicator(),
              ],
              if (_matches != null && _matches!.isNotEmpty) ...[
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  '共 ${_matches!.length} 个匹配剧集，点击即可载入',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SpacingTokens.xs),
                SizedBox(
                  height: (_matches!.length * 56.0).clamp(56.0, 224.0),
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: _matches!.length,
                    itemBuilder: (_, index) {
                      final item = _matches![index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.animeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.episodeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: _searching
                            ? null
                            : () => _loadMatchedEpisode(item),
                      );
                    },
                  ),
                ),
              ],
              const Divider(height: SpacingTokens.lg),
              TextField(
                controller: _urlCtrl,
                enabled: !_searching,
                decoration: const InputDecoration(
                  labelText: '或直接输入 XML / JSON 弹幕链接',
                  hintText: 'https://.../comment.xml',
                ),
              ),
              const SizedBox(height: SpacingTokens.xs),
              SoftButton(
                label: '通过链接下载',
                style: SoftStyle.outline,
                onPressed: _searching ? null : _loadDirectUrl,
              ),
              if (_dialogError != null) ...[
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  _dialogError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
