import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/onboarding/onboarding_card.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding/onboarding_remote_datasource.dart';
import '../dtos/onboarding_card_row.dart';

/// Server cards with a small on-device cache (one JSON string in
/// SharedPreferences), so an offline launch still shows the last cards.
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(
      {required OnboardingRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  static const cacheKey = 'onboarding.cards.v1';

  final OnboardingRemoteDataSource _remote;

  @override
  Future<List<OnboardingCard>> cachedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return defaultOnboardingCards;
    try {
      final rows = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(OnboardingCardRow.fromJson);
      final cards = _toCards(rows);
      return cards.isEmpty ? defaultOnboardingCards : cards;
    } catch (error, stackTrace) {
      AppLogger.w('Onboarding cache unreadable — using built-in cards',
          error: error, stackTrace: stackTrace);
      return defaultOnboardingCards;
    }
  }

  @override
  Future<List<OnboardingCard>> refresh() async {
    final rows =
        (await _remote.fetchActiveCards()).map(OnboardingCardRow.fromJson);
    final valid = rows.where((r) => r.toDomain() != null).toList();
    final prefs = await SharedPreferences.getInstance();
    if (valid.isEmpty) {
      await prefs.remove(cacheKey);
      return defaultOnboardingCards;
    }
    await prefs.setString(
        cacheKey, jsonEncode([for (final r in valid) r.toJson()]));
    return _toCards(valid);
  }

  List<OnboardingCard> _toCards(Iterable<OnboardingCardRow> rows) => [
        for (final row in rows)
          if (row.toDomain() case final card?) card,
      ];
}
