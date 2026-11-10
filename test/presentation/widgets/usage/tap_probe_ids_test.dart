import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/widgets/usage/tap_probe_ids.dart';

void main() {
  test('ids are unique and screen.element shaped', () {
    expect(TapProbeIds.all.toSet().length, TapProbeIds.all.length);
    for (final id in TapProbeIds.all) {
      expect(id, matches(RegExp(r'^[a-z_]+\.[a-z_]+$')));
    }
  });

  test('every id tags something on a screen', () {
    final source = [
      for (final f in Directory('lib/presentation')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('tap_probe_ids.dart')))
        f.readAsStringSync()
    ].join('\n');
    for (final id in TapProbeIds.all) {
      final constant = TapProbeIds.constantName(id);
      expect(source, contains('TapProbeIds.$constant'), reason: id);
    }
  });

  test('the catalogue documents every id', () {
    final doc = File('docs/usage_study/event_catalogue.md').readAsStringSync();
    for (final id in TapProbeIds.all) {
      expect(doc, contains('`$id`'), reason: id);
    }
  });
}
