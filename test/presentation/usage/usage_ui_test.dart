import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';
import 'package:pahlevani/presentation/usage/usage_ui.dart';

import '../../fakes/fake_usage_tracker.dart';

void main() {
  late FakeUsageTracker tracker;
  late BuildContext ctx;

  Future<void> pump(WidgetTester tester) async {
    tracker = FakeUsageTracker();
    await tester.pumpWidget(UsageScope(
      tracker: tracker,
      child: MaterialApp(
        home: Scaffold(body: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        })),
      ),
    ));
  }

  testWidgets('opening a link logs which link and its host, then opens it',
      (tester) async {
    await pump(tester);
    final opened = <Uri>[];
    await openExternalLink(
        ctx, ExternalLink.meelGuide, 'https://rahaavi.com/meel?x=1',
        launch: (uri) async {
      opened.add(uri);
      return true;
    });
    final event = tracker.of<NavLinkOpened>().single;
    expect(event.link, ExternalLink.meelGuide);
    expect(event.urlHost, 'rahaavi.com');
    expect(opened.single.toString(), 'https://rahaavi.com/meel?x=1');
  });

  testWidgets('a link that fails to open is still logged, not thrown',
      (tester) async {
    await pump(tester);
    final ok = await openExternalLink(ctx, ExternalLink.store, 'not a url',
        launch: (_) async => throw Exception('no browser'));
    expect(ok, isFalse);
    expect(tracker.of<NavLinkOpened>(), hasLength(1));
  });

  testWidgets('a snackbar message is shown and logged by key', (tester) async {
    await pump(tester);
    showUsageSnackBar(ctx, 'Couldn’t save', key: 'history_save_failed');
    await tester.pump();
    expect(find.text('Couldn’t save'), findsOneWidget);
    final shown = tracker.of<UiErrorShown>().single;
    expect(shown.kind, ErrorSurface.snackbar);
    expect(shown.messageKey, 'history_save_failed');
  });
}
