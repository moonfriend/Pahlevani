import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../widgets/kashi/kashi_tab_bar.dart';

/// One tab of the [AppShell].
class ShellTab {
  const ShellTab({required this.label, required this.builder});

  final String label;
  final WidgetBuilder builder;
}

/// The Kashi app shell: tabs (Home · Library · Progress · Profile) over the
/// lajvard tab bar.
///
/// Tabs are built on first visit (so e.g. Progress doesn't load history
/// until opened) and kept alive afterwards. Back on any tab but the first
/// returns to the first instead of leaving the app.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.tabs});

  final List<ShellTab> tabs;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  void _select(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).extension<KashiColors>()!.ground,
        body: IndexedStack(
          index: _index,
          children: [
            for (final (i, tab) in widget.tabs.indexed)
              _visited.contains(i)
                  ? Builder(builder: tab.builder)
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: KashiTabBar(
          labels: [for (final tab in widget.tabs) tab.label],
          selectedIndex: _index,
          onSelected: _select,
        ),
      ),
    );
  }
}
