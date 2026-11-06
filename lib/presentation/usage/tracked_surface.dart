import 'package:flutter/widgets.dart';

import '../../domain/entities/usage/usage_event.dart';
import 'usage_scope.dart';

/// Marks root content that swaps in place instead of being pushed (a gate:
/// splash, onboarding, account, consent, locked, loading) so the study
/// sees it as a screen.
class TrackedSurface extends StatefulWidget {
  const TrackedSurface({super.key, required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  State<TrackedSurface> createState() => _TrackedSurfaceState();
}

class _TrackedSurfaceState extends State<TrackedSurface> {
  @override
  void initState() {
    super.initState();
    context.screens?.setSurface(widget.name, NavVia.gate);
  }

  @override
  void didUpdateWidget(TrackedSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      context.screens?.setSurface(widget.name, NavVia.gate);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
