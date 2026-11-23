import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class PlayerDeviceBridge {
  Future<void> setFullscreen(bool full);
  Future<double> getWindowBrightness();
  Future<void> setWindowBrightness(double value);
  Future<bool> supportsPip();
  Future<bool> enterPip({int width = 16, int height = 9});
  ValueListenable<bool> get pipModeListenable;
}

class AndroidMediaAccess implements PlayerDeviceBridge {
  const AndroidMediaAccess();

  static const _channel = MethodChannel('app.aniview/media');
  static final ValueNotifier<bool> _pipMode = ValueNotifier<bool>(false);
  static bool _channelHandlerRegistered = false;

  static void _ensureChannelHandler() {
    if (_channelHandlerRegistered) return;
    _channelHandlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        _pipMode.value = call.arguments == true;
      }
    });
  }

  Future<({Uri uri, String name})?> pickVideo() async {
    return _pick('pickVideo');
  }

  Future<({String name, Uint8List bytes})?> pickAttachment() async {
    final selection = await _pick('pickAttachment');
    if (selection == null) return null;
    final bytes = await _channel.invokeMethod<Uint8List>(
      'readAttachment',
      selection.uri.toString(),
    );
    if (bytes == null) throw const FormatException('无法读取所选文件。');
    return (name: selection.name, bytes: bytes);
  }

  Future<int?> availableBytes() => _channel.invokeMethod<int>('availableBytes');

  Future<bool> exportBackup(String filename, String content) async =>
      await _channel.invokeMethod<bool>('createBackup', {
        'name': filename,
        'content': content,
      }) ??
      false;

  Future<String?> pickBackup() => _channel.invokeMethod<String>('readBackup');

  Future<void> openBangumi(Uri uri) =>
      _channel.invokeMethod<void>('openBangumi', uri.toString());

  Future<({Uri uri, String name})?> _pick(String method) async {
    final result = await _channel.invokeMapMethod<String, String>(method);
    if (result == null) return null;
    final uri = Uri.tryParse(result['uri'] ?? '');
    final validContent =
        uri != null && uri.isScheme('content') && uri.host.isNotEmpty;
    final validFile =
        uri != null && uri.isScheme('file') && uri.path.isNotEmpty;
    if (!validContent && !validFile) {
      throw const FormatException('未能返回可读取的本地文件。');
    }
    return (uri: uri, name: result['name'] ?? '本地视频');
  }

  @override
  Future<void> setFullscreen(bool full) async {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS;
    await SystemChrome.setPreferredOrientations(
      full
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : isApple
          ? const []
          : const [DeviceOrientation.portraitUp],
    );
    await _channel.invokeMethod<void>('setFullscreen', full);
  }

  @override
  Future<double> getWindowBrightness() async {
    try {
      return await _channel.invokeMethod<double>('getWindowBrightness') ?? -1.0;
    } on PlatformException {
      return -1.0;
    } on MissingPluginException {
      return -1.0;
    }
  }

  @override
  Future<void> setWindowBrightness(double value) async {
    try {
      await _channel.invokeMethod<void>('setWindowBrightness', value);
    } on PlatformException {
      // Window brightness override is unsupported on non-Android platforms.
    } on MissingPluginException {
      // Ignore in widget tests / desktop harnesses.
    }
  }

  @override
  Future<bool> supportsPip() async {
    _ensureChannelHandler();
    try {
      return await _channel.invokeMethod<bool>('supportsPip') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> enterPip({int width = 16, int height = 9}) async {
    _ensureChannelHandler();
    try {
      return await _channel.invokeMethod<bool>('enterPip', {
            'width': width,
            'height': height,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  ValueListenable<bool> get pipModeListenable {
    _ensureChannelHandler();
    return _pipMode;
  }
}
