import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/supabase_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a table that does not exist yet (pre-migration) is recognised', () {
    // Postgres undefined_table, and PostgREST's "not in schema cache".
    expect(
        isMissingTableError(const PostgrestException(
            message: 'relation "public.morshed" does not exist',
            code: '42P01')),
        isTrue);
    expect(
        isMissingTableError(const PostgrestException(
            message: "Could not find the table 'public.morshed'",
            code: 'PGRST205')),
        isTrue);
  });

  test('network and other failures are NOT treated as a missing table', () {
    // Being offline must surface as an error, so callers can fall back to a
    // saved copy instead of mistaking it for "nothing curated yet".
    expect(isMissingTableError(const SocketException('Failed host lookup')),
        isFalse);
    expect(
        isMissingTableError(
            const PostgrestException(message: 'JWT expired', code: 'PGRST301')),
        isFalse);
    expect(isMissingTableError(Exception('timeout')), isFalse);
  });
}
