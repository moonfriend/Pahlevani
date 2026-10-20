import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/info/info_link.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/announcement/announcement_remote_datasource.dart';

/// The server card with an on-device copy (one JSON string in
/// SharedPreferences), so an offline start still shows the last card.
class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl(
      {required AnnouncementRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  static const cacheKey = 'home.announcement.v1';
  static const seenKeyKey = 'home.announcement.seen';

  final AnnouncementRemoteDataSource _remote;

  @override
  Future<InfoLink?> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(cacheKey);
    if (raw == null) return null;
    try {
      return _fromRow(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stackTrace) {
      AppLogger.w('Home card cache unreadable — ignoring it',
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Future<InfoLink?> refresh() async {
    final row = await _remote.fetchActive();
    final link = row == null ? null : _fromRow(row);
    final prefs = await SharedPreferences.getInstance();
    if (link == null) {
      await prefs.remove(cacheKey);
    } else {
      await prefs.setString(
          cacheKey,
          jsonEncode({
            'title': link.title,
            'description': link.description,
            'url': link.url,
          }));
    }
    return link;
  }

  @override
  Future<String?> seenKey() async =>
      (await SharedPreferences.getInstance()).getString(seenKeyKey);

  @override
  Future<void> markSeen(String contentKey) async =>
      (await SharedPreferences.getInstance()).setString(seenKeyKey, contentKey);

  /// Null for a row the app shouldn't show: no title, or not an https link
  /// (the database enforces both; this guards a hand-edited cache).
  InfoLink? _fromRow(Map<String, dynamic> row) {
    final title = (row['title'] as String?)?.trim() ?? '';
    final url = (row['url'] as String?)?.trim() ?? '';
    if (title.isEmpty || !url.startsWith('https://')) return null;
    return InfoLink(
      title: title,
      description: (row['description'] as String?)?.trim() ?? '',
      url: url,
    );
  }
}
