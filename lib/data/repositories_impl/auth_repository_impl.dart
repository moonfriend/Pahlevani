import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/repositories/auth_repository.dart';

/// [AuthRepository] backed by Supabase auth + the `profiles` table
/// (supabase/migrations/0013_profiles_and_consent.sql).
class AuthRepositoryImpl implements AuthRepository {
  final sb.SupabaseClient _client;

  /// Last profile-merged user, kept so the synchronous [currentUser] getter
  /// can reflect trainer/consent status without a network call. Populated
  /// as soon as a profile fetch resolves (sign-in/up, or the first
  /// [authStateChanges] tick); before that, [currentUser] reports identity
  /// only (isTrainer/consentAccepted default false) — corrects itself the
  /// moment the profile fetch lands.
  AppUser? _cachedProfile;

  AuthRepositoryImpl({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  @override
  AppUser? get currentUser {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    if (_cachedProfile != null && _cachedProfile!.id == authUser.id) {
      return _cachedProfile;
    }
    return AppUser(id: authUser.id, email: authUser.email);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((state) async {
      final authUser = state.session?.user;
      if (authUser == null) {
        _cachedProfile = null;
        return null;
      }
      final user = await _fetchProfile(authUser);
      _cachedProfile = user;
      return user;
    });
  }

  Future<AppUser> _fetchProfile(sb.User authUser) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .single();
      return _userFromRow(authUser.id, authUser.email, row);
    } catch (_) {
      // The profiles row may not have landed yet (trigger lag) or the read
      // failed transiently — fall back to a minimal unconsented user rather
      // than throwing. authStateChanges/the next fetch will correct this.
      return AppUser(id: authUser.id, email: authUser.email);
    }
  }

  AppUser _userFromRow(String id, String? email, Map<String, dynamic> row) {
    return AppUser(
      id: id,
      email: email,
      isTrainer: row['is_trainer'] as bool? ?? false,
      consentAccepted: row['consent_accepted'] as bool? ?? false,
      consentedAt: row['consented_at'] == null
          ? null
          : DateTime.parse(row['consented_at'] as String),
    );
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final authUser = res.user;
    if (authUser == null) throw Exception('Sign up failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res =
        await _client.auth.signInWithPassword(email: email, password: password);
    final authUser = res.user;
    if (authUser == null) throw Exception('Sign in failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  // Usernames aren't a real Supabase auth concept — synthesized into a
  // fake address so this can reuse the same email/password auth machinery
  // as everything else. Never shown to the user; a data-layer detail only.
  String _usernameEmail(String username) =>
      '${username.trim().toLowerCase()}@students.pahlevani.internal';

  @override
  Future<AppUser> signUpWithInviteCode({
    required String username,
    required String password,
    required String inviteCode,
  }) async {
    final isValid = await _client
        .rpc('is_invite_code_valid', params: {'code': inviteCode}) as bool;
    if (!isValid) throw const InvalidInviteCodeException();

    // 0016_invite_code_signup.sql's trigger is the actual enforced gate —
    // this metadata is what it reads. The pre-check above is just so a bad
    // code fails cleanly before this call, rather than surfacing whatever
    // error text GoTrue happens to wrap a rejected-trigger exception in.
    final res = await _client.auth.signUp(
      email: _usernameEmail(username),
      password: password,
      data: {
        'signup_method': 'invite_code',
        'invite_code': inviteCode,
        'username': username.trim(),
      },
    );
    final authUser = res.user;
    if (authUser == null) throw Exception('Sign up failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  @override
  Future<AppUser> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: _usernameEmail(username),
      password: password,
    );
    final authUser = res.user;
    if (authUser == null) throw Exception('Sign in failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  // Memoized rather than a bool flag so concurrent callers (signInWithGoogle
  // racing initializeGoogleSignIn) share one in-flight init instead of both
  // calling GoogleSignIn.initialize() themselves.
  Future<void>? _googleSignInInitFuture;
  final _googleSignInEventsController = StreamController<AppUser>.broadcast();

  // Web-only OIDC nonce (see _initGoogleSignIn's doc). Left null on native
  // platforms, matching Supabase's own documented native-flow example,
  // which doesn't use one either.
  String? _googleSignInRawNonce;

  @override
  Stream<AppUser> get googleSignInEvents =>
      _googleSignInEventsController.stream;

  @override
  Future<void> initializeGoogleSignIn() =>
      _googleSignInInitFuture ??= _initGoogleSignIn();

  Future<void> _initGoogleSignIn() async {
    final googleSignIn = GoogleSignIn.instance;
    // Web's SDK rejects serverClientId outright ("serverClientId is not
    // supported on Web") and instead wants the same value as clientId —
    // native platforms are the reverse (they resolve their own clientId
    // from platform config and only need serverClientId, to get an ID
    // token whose audience Supabase can verify).
    //
    // Web also needs an explicit OIDC nonce: Google's GIS SDK embeds one in
    // the ID token by default, and Supabase requires the nonce it's given
    // and the token's nonce claim to either both be present or both be
    // absent — otherwise it rejects the sign-in
    // ("Passed nonce and nonce in id_token should either both exist or
    // not"). Standard OIDC pattern (the same one used for Sign in with
    // Apple): send Google the SHA-256 hash of a random value, then send
    // Supabase the original, unhashed value — Supabase hashes it itself and
    // compares against the token's claim.
    String? hashedNonce;
    if (kIsWeb) {
      _googleSignInRawNonce = _generateNonce();
      hashedNonce = sha256.convert(utf8.encode(_googleSignInRawNonce!)).toString();
    }
    await googleSignIn.initialize(
      clientId: kIsWeb ? googleWebClientId : null,
      serverClientId: kIsWeb ? null : googleWebClientId,
      nonce: hashedNonce,
    );
    if (!kIsWeb) return;

    // Web has no imperative sign-in call (see signInWithGoogle's doc) — the
    // GIS button drives the flow itself and reports back only through this
    // stream.
    googleSignIn.authenticationEvents.listen((event) async {
      if (event is! GoogleSignInAuthenticationEventSignIn) return;
      try {
        _googleSignInEventsController.add(await _completeGoogleSignIn(event.user));
      } catch (e) {
        _googleSignInEventsController.addError(e);
      }
    });
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await initializeGoogleSignIn();
    // Interactive account picker — not attemptLightweightAuthentication(),
    // which is for silent restore. Supabase already persists its own
    // session locally (reflected via currentUser), so silent restore is
    // handled independently of Google's own cache.
    final googleUser = await GoogleSignIn.instance.authenticate();
    return _completeGoogleSignIn(googleUser);
  }

  Future<AppUser> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) throw Exception('Google sign-in returned no ID token');

    // No authorizeScopes() call here on purpose: it would request an access
    // token via a *second* popup, separate from the sign-in one — which
    // fails on web (GoogleSignInExceptionCode.uiUnavailable) because this
    // runs inside an async stream callback rather than synchronously inside
    // a click handler, so the browser blocks it as non-user-initiated.
    // signInWithIdToken's accessToken param is optional and we don't use it
    // for anything else, so the ID token alone is enough.
    final res = await _client.auth.signInWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: idToken,
      nonce: _googleSignInRawNonce,
    );
    final authUser = res.user;
    if (authUser == null) throw Exception('Google sign-in failed');
    final user = await _fetchProfile(authUser);
    _cachedProfile = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    _cachedProfile = null;
    await _client.auth.signOut();
  }

  @override
  Future<AppUser> acceptPrivacyConsent() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('acceptPrivacyConsent() called with no signed-in user');
    }
    Map<String, dynamic> row;
    try {
      row = await _markConsentAccepted(authUser.id);
    } on sb.PostgrestException catch (e) {
      // PGRST116: the update matched 0 rows — the on_auth_user_created
      // trigger (0013_profiles_and_consent.sql) hasn't landed yet. That
      // migration's own comment documents an own-row insert as the fallback
      // for exactly this race, and its policies/grants already allow it;
      // create the row, then retry. Any other error still propagates —
      // this must never silently look like success.
      if (e.code != 'PGRST116') rethrow;
      await _client
          .from('profiles')
          .insert({'id': authUser.id, 'email': authUser.email});
      row = await _markConsentAccepted(authUser.id);
    }
    final user = _userFromRow(authUser.id, authUser.email, row);
    _cachedProfile = user;
    return user;
  }

  Future<Map<String, dynamic>> _markConsentAccepted(String userId) {
    // .select().single() after .update() throws on 0 rows / RLS reject /
    // network error — this must never silently look like success.
    return _client
        .from('profiles')
        .update({
          'consent_accepted': true,
          'consented_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
  }

  @override
  Future<List<AppUser>> listTrainees() async {
    final rows =
        await _client.from('profiles').select().eq('is_trainer', false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) =>
            _userFromRow(row['id'] as String, row['email'] as String?, row))
        .toList();
  }

  static const _nonceCharset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _nonceCharset[random.nextInt(_nonceCharset.length)],
    ).join();
  }
}
