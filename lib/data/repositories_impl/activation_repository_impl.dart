import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/activation/locked_screen_text.dart';
import '../../domain/entities/auth/terms_info.dart';
import '../../domain/repositories/activation_repository.dart';
import '../datasources/activation/activation_remote_datasource.dart';

/// Activation from the server, remembered per account on the device so an
/// activated user can train offline. The server stays the authority: the
/// content itself is only readable once activated (migration 0045), so a
/// tampered device flag unlocks nothing new.
class ActivationRepositoryImpl implements ActivationRepository {
  ActivationRepositoryImpl(
      {required ActivationRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  static String activatedKey(String userId) => 'activation.ok.$userId';
  static const lockedScreenKey = 'activation.locked_screen.v1';
  static const termsKey = 'activation.terms.v1';

  final ActivationRemoteDataSource _remote;

  @override
  Future<bool> isActivated(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final activated = await _remote.isActivated();
      if (activated) {
        await prefs.setBool(activatedKey(userId), true);
      } else {
        await prefs.remove(activatedKey(userId));
      }
      return activated;
    } on ActivationGateNotInstalledException {
      // Nothing is restricted on this database yet; the gate switches on by
      // itself once migration 0045 is applied. Not remembered on purpose.
      AppLogger.w('Activation gate not installed on this database — open');
      return true;
    } catch (error) {
      AppLogger.w('Activation check failed — using this device’s memory',
          error: error);
      return prefs.getBool(activatedKey(userId)) ?? false;
    }
  }

  @override
  Future<void> redeem(String userId, String code) async {
    await _remote.redeem(code.trim());
    await (await SharedPreferences.getInstance())
        .setBool(activatedKey(userId), true);
  }

  @override
  Future<LockedScreenText> lockedScreenText() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final row = await _remote.fetchLockedScreen();
      final text = row == null ? null : _fromRow(row);
      if (text != null) {
        await prefs.setString(lockedScreenKey, jsonEncode(row));
        return text;
      }
    } catch (error) {
      AppLogger.w('Locked-screen text fetch failed', error: error);
    }
    final cached = prefs.getString(lockedScreenKey);
    if (cached != null) {
      try {
        final text = _fromRow(jsonDecode(cached) as Map<String, dynamic>);
        if (text != null) return text;
      } catch (_) {/* unreadable cache: fall through to the built-in text */}
    }
    return LockedScreenText.fallback;
  }

  @override
  Future<bool> isCodeValid(String code) => _remote.isCodeValid(code.trim());

  @override
  Future<TermsInfo> termsInfo() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final row = await _remote.fetchTerms();
      final terms = row == null ? null : _termsFromRow(row);
      if (terms != null) {
        await prefs.setString(termsKey, jsonEncode(row));
        return terms;
      }
    } catch (error) {
      AppLogger.w('Terms version fetch failed', error: error);
    }
    final cached = prefs.getString(termsKey);
    if (cached != null) {
      try {
        final terms = _termsFromRow(jsonDecode(cached) as Map<String, dynamic>);
        if (terms != null) return terms;
      } catch (_) {/* unreadable cache: fall through to the app's own */}
    }
    return TermsInfo.fallback;
  }

  TermsInfo? _termsFromRow(Map<String, dynamic> row) {
    final version = (row['terms_version'] as num?)?.toInt();
    if (version == null || version < 1) return null;
    final updatedOn = row['terms_updated_on'] as String?;
    return TermsInfo(
      version: version,
      updatedOn: updatedOn == null ? null : DateTime.tryParse(updatedOn),
    );
  }

  LockedScreenText? _fromRow(Map<String, dynamic> row) {
    final message = (row['message'] as String?)?.trim() ?? '';
    final url = (row['link_url'] as String?)?.trim() ?? '';
    if (message.isEmpty || !url.startsWith('https://')) return null;
    final label = (row['link_label'] as String?)?.trim() ?? '';
    return LockedScreenText(
      message: message,
      linkLabel: label.isEmpty ? LockedScreenText.fallback.linkLabel : label,
      linkUrl: url,
    );
  }
}
