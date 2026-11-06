import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/app_logger.dart';
import '../../domain/entities/usage/usage_event.dart';
import 'usage_scope.dart';

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opens [url] outside the app (browser, store) and logs which [link] it
/// was. The one way the app opens external links, so the study sees all
/// of them. Never throws: a link that can't open returns false.
Future<bool> openExternalLink(
  BuildContext context,
  ExternalLink link,
  String url, {
  Future<bool> Function(Uri uri) launch = _launchExternal,
}) async {
  final uri = Uri.tryParse(url);
  context.usage.track(NavLinkOpened(link: link, urlHost: uri?.host ?? ''));
  if (uri == null) return false;
  try {
    return await launch(uri);
  } catch (error) {
    AppLogger.w('Could not open $link', error: error);
    return false;
  }
}

/// Shows [message] in a snackbar and logs that the user saw it, under a
/// short fixed [key] (never the text itself, which may hold names).
void showUsageSnackBar(BuildContext context, String message,
    {required String key, Duration? duration}) {
  context.usage
      .track(UiErrorShown(kind: ErrorSurface.snackbar, messageKey: key));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(milliseconds: 4000),
    ));
}
