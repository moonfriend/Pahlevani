import 'dart:math';

final Random _secure = Random.secure();

/// A random (version 4) UUID, e.g. `3f2b…-4…-a…`.
///
/// Event ids are made on the device so an upload retried after a dropped
/// connection can't double-count (the table drops duplicate ids). Ten lines
/// here instead of a package dependency.
String uuidV4([Random? random]) {
  final r = random ?? _secure;
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}
