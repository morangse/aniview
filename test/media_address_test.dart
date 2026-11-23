import 'package:aniview/media/media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves source query strings and accepts MP4, HLS and extensionless endpoints', () {
    expect(
      parsePlaybackUrl('  https://media.test/demo.mp4#bookmark  ').toString(),
      'https://media.test/demo.mp4',
    );
    expect(
      parsePlaybackUrl('https://media.test/live.m3u8?start=12').query,
      'start=12',
    );
    expect(parsePlaybackUrl('http://127.0.0.1:8172/stream').port, 8172);
  });

  for (final url in [
    '',
    'foo.mp4',
    'file:///sdcard/video.mp4',
    'content://documents/1',
    'ftp://media.test/file',
    'javascript:alert(1)',
    'https:///file',
    'https://user:pass@media.test/file',
    'https://media.test/a b',
    'https://media.test/a%zz',
    'https://media.test:70000/file',
    'https://media.test\\file',
  ]) {
    test(
      'rejects "$url"',
      () => expect(() => parsePlaybackUrl(url), throwsFormatException),
    );
  }
}
