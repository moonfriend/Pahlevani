import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/pages/shell/app_shell.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_side_rail.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_tab_bar.dart';

int _libraryBuilds = 0;

final _tabs = [
  ShellTab(label: 'Home', builder: (_) => const Text('home body')),
  ShellTab(
    label: 'Library',
    builder: (_) {
      _libraryBuilds++;
      return const _Counter(key: Key('library'));
    },
  ),
  ShellTab(label: 'Progress', builder: (_) => const Text('progress body')),
  ShellTab(label: 'Profile', builder: (_) => const Text('profile body')),
];

/// Stateful so the test can prove a tab keeps its state when hidden.
class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('library taps $taps'),
      );
}

Future<void> _pump(WidgetTester tester, {Size? window}) async {
  _libraryBuilds = 0;
  if (window != null) {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: AppShell(tabs: _tabs),
  ));
}

void main() {
  testWidgets('opens on the first tab with the Kashi tab bar', (tester) async {
    await _pump(tester);

    expect(find.text('home body'), findsOneWidget);
    expect(find.byType(KashiTabBar), findsOneWidget);
    expect(_libraryBuilds, 0, reason: 'tabs are built on first visit');
  });

  testWidgets('switches tabs and keeps a visited tab\'s state', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.tap(find.text('library taps 0'));
    await tester.pump();
    expect(find.text('library taps 1'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pump();
    expect(find.text('progress body'), findsOneWidget);
    expect(find.text('library taps 1'), findsNothing);

    await tester.tap(find.text('Library'));
    await tester.pump();
    expect(find.text('library taps 1'), findsOneWidget,
        reason: 'the hidden tab kept its state');
  });

  testWidgets('Back on another tab returns to the first tab', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(find.text('profile body'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue, reason: 'Back must not leave the app here');
    expect(find.text('home body'), findsOneWidget);
  });

  testWidgets('onSelected runs every time a tab is chosen', (tester) async {
    var progressSelections = 0;
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: AppShell(tabs: [
        ShellTab(label: 'Home', builder: (_) => const Text('home body')),
        ShellTab(
          label: 'Progress',
          builder: (_) => const Text('progress body'),
          onSelected: () => progressSelections++,
        ),
      ]),
    ));

    await tester.tap(find.text('Progress'));
    await tester.pump();
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Progress'));
    await tester.pump();

    expect(progressSelections, 2,
        reason: 'reload when shown, e.g. after finishing a session');
  });

  testWidgets('a tab can switch to another tab through AppShell.of',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: PahlevaniTheme.light(),
      home: AppShell(tabs: [
        ShellTab(
          label: 'Home',
          builder: (context) => TextButton(
            onPressed: () => AppShell.of(context).select(1),
            child: const Text('go to progress'),
          ),
        ),
        ShellTab(
            label: 'Progress', builder: (_) => const Text('progress body')),
      ]),
    ));

    await tester.tap(find.text('go to progress'));
    await tester.pump();
    expect(find.text('progress body'), findsOneWidget);
  });

  group('responsive navigation', () {
    testWidgets('phone: the 62px bottom tab bar', (tester) async {
      await _pump(tester, window: const Size(390, 844));
      expect(find.byType(KashiSideRail), findsNothing);
      expect(tester.getSize(find.byType(KashiTabBar)).height, 62);
    });

    testWidgets('tablet: an 80px bottom tab bar', (tester) async {
      await _pump(tester, window: const Size(834, 1194));
      expect(find.byType(KashiSideRail), findsNothing);
      expect(tester.getSize(find.byType(KashiTabBar)).height, 80);
    });

    testWidgets(
        'web: a 232px side rail instead of the tab bar; it switches '
        'tabs', (tester) async {
      await _pump(tester, window: const Size(1440, 900));
      expect(find.byType(KashiTabBar), findsNothing);
      expect(tester.getSize(find.byType(KashiSideRail)).width, 232);

      await tester.tap(find.text('Progress'));
      await tester.pump();
      expect(find.text('progress body'), findsOneWidget);
    });

    testWidgets('resizing keeps the current tab and its state', (tester) async {
      await _pump(tester, window: const Size(1440, 900));
      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.tap(find.text('library taps 0'));
      await tester.pump();

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.byType(KashiTabBar), findsOneWidget);
      expect(find.text('library taps 1'), findsOneWidget);
    });
  });
}
