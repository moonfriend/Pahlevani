import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/audio_catalog/morshed.dart';
import 'package:pahlevani/domain/usecases/audio_catalog/effective_morshed.dart';

void main() {
  const a = Morshed(id: 1, name: 'A');
  const b = Morshed(id: 2, name: 'B', isDefault: true);

  test("the athlete's own choice wins", () {
    expect(effectiveMorshedId(selectedId: 1, morsheds: const [a, b]), 1);
  });

  test('no choice → the default Morshed', () {
    expect(effectiveMorshedId(selectedId: null, morsheds: const [a, b]), 2);
  });

  test('a choice that no longer exists → the default Morshed', () {
    expect(effectiveMorshedId(selectedId: 99, morsheds: const [a, b]), 2);
  });

  test('no choice and no default → null (resolver picks any recording)', () {
    expect(effectiveMorshedId(selectedId: null, morsheds: const [a]), isNull);
  });

  test('Morshed list unknown (empty, e.g. not loaded) → keep the choice', () {
    expect(effectiveMorshedId(selectedId: 2, morsheds: const []), 2);
  });
}
