import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../layout/kashi_layout.dart';
import '../../widgets/kashi/kashi_side_rail.dart';
import '../../widgets/kashi/kashi_tab_bar.dart';

/// One tab of the [AppShell].
class ShellTab {
  const ShellTab({required this.label, required this.builder, this.onSelected});

  final String label;
  final WidgetBuilder builder;

  /// Runs whenever the user switches to this tab — e.g. to refresh data a
  /// kept-alive tab shows.
  final VoidCallback? onSelected;
}

/// The Kashi app shell: tabs (Home · Library · Progress · Profile) over the
/// lajvard tab bar — 62px on phones, 80px on tablets — or, in the web
/// layout, beside a side rail. Resizing between layouts keeps the current
/// tab and every visited tab's state.
///
/// Tabs are built on first visit (so e.g. Progress doesn't load history
/// until opened) and kept alive afterwards. Back on any tab but the first
/// returns to the first instead of leaving the app.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.tabs, this.railFooter});

  final List<ShellTab> tabs;

  /// Shown at the bottom of the web layout's side rail.
  final Widget? railFooter;

  /// The enclosing shell, so a tab can switch tabs (e.g. Home's shamseh
  /// tile opens Progress).
  static AppShellState of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>()!;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  /// Switches to tab [index].
  void select(int index) => _select(index);

  void _select(int index) {
    if (index != _index) widget.tabs[index].onSelected?.call();
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = KashiLayout.of(context);
    final labels = [for (final tab in widget.tabs) tab.label];
    // Keyed so the tabs keep their state when the rail comes and goes.
    final tabs = Expanded(
      key: const ValueKey('shell-tabs'),
      child: IndexedStack(
        index: _index,
        children: [
          for (final (i, tab) in widget.tabs.indexed)
            _visited.contains(i)
                ? Builder(builder: tab.builder)
                : const SizedBox.shrink(),
        ],
      ),
    );
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).extension<KashiColors>()!.ground,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (layout.isWide)
              KashiSideRail(
                labels: labels,
                selectedIndex: _index,
                onSelected: _select,
                footer: widget.railFooter,
              ),
            tabs,
          ],
        ),
        bottomNavigationBar: layout.isWide
            ? null
            : KashiTabBar(
                labels: labels,
                selectedIndex: _index,
                onSelected: _select,
                height: layout.isPhone
                    ? KashiTabBar.phoneHeight
                    : KashiTabBar.tabletHeight,
              ),
      ),
    );
  }
}
