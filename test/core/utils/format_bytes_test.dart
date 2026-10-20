import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/utils/format_bytes.dart';

void main() {
  test('formats sizes the way a download dialog shows them', () {
    expect(formatBytes(0), '0 KB');
    expect(formatBytes(512), '1 KB');
    expect(formatBytes(1536), '2 KB');
    expect(formatBytes(950 * 1000), '950 KB');
    expect(formatBytes(3 * 1000 * 1000 + 240 * 1000), '3.2 MB');
    expect(formatBytes(193 * 1000 * 1000), '193 MB');
    expect(formatBytes(1450 * 1000 * 1000), '1.45 GB');
  });
}
