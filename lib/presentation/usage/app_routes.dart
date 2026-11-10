import 'package:flutter/widgets.dart';

/// Names of every screen, dialog and sheet, as the usage study logs them.
///
/// Root content (gates, tabs) isn't a route: it reports itself as a
/// "surface" (TrackedSurface, the shell's tab listener). Everything pushed
/// passes `AppRoutes.settings(name)` so the navigator observer can name it.
abstract final class AppRoutes {
  // ── Surfaces (root content, not routes) ──
  static const loading = 'loading';
  static const versionGate = 'version_gate';
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const account = 'account';
  static const consent = 'consent';
  static const locked = 'locked';

  /// A tab's surface name, from its label: `home`, `library`, `profile`.
  static String tab(String label) => label.toLowerCase();

  // ── Pushed screens ──
  static const sessionPreview = 'session_preview';
  static const player = 'player';
  static const complete = 'complete';
  static const repLog = 'rep_log';
  static const learningCard = 'learning_card';
  static const calendar = 'calendar';
  static const trainerTools = 'trainer_tools';
  static const designPreview = 'design_preview';
  static const editSession = 'edit_session';

  // ── Dialogs and sheets ──
  static const zoorkhanehConfirm = 'zoorkhaneh_confirm';
  static const downloadDialog = 'download_dialog';
  static const errorDialog = 'error_dialog';
  static const morshedSyncWarning = 'morshed_sync_warning';
  static const deleteAccountConfirm = 'delete_account_confirm';

  /// Pop-up routes that fill the view like a page, so they count as
  /// screens rather than dialogs.
  static const popupScreens = {learningCard};

  static RouteSettings settings(String name) => RouteSettings(name: name);
}
