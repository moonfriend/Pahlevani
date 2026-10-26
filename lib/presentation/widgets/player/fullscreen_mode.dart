import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../layout/kashi_layout.dart';
import 'fullscreen/browser_fullscreen.dart';

/// A phone held sideways: its videos go full screen by themselves. Tablets
/// and desktop windows are landscape anyway, so they never do.
bool isLandscapePhone(Size size) =>
    size.shortestSide < KashiLayout.tabletMinWidth && size.width > size.height;

/// While on screen, the video owns the whole display: the system bars hide
/// (Android/iOS) and, on the web, the browser is asked for full screen.
/// Leaving always brings the bars back, also when the page is closed.
class FullscreenScope extends StatefulWidget {
  const FullscreenScope({super.key, required this.child});

  final Widget child;

  @override
  State<FullscreenScope> createState() => _FullscreenScopeState();
}

class _FullscreenScopeState extends State<FullscreenScope> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    enterBrowserFullscreen();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    exitBrowserFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Colors.black, child: widget.child);
}

/// The ⛶ / ✕ square in a video's corner.
class FullscreenToggleButton extends StatelessWidget {
  const FullscreenToggleButton(
      {super.key, required this.fullscreen, required this.onPressed});

  final bool fullscreen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: fullscreen ? 'Exit full screen' : 'Full screen',
      excludeSemantics: true,
      child: Material(
        color: Colors.black45,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
                fullscreen ? Icons.close_fullscreen : Icons.fullscreen_rounded,
                color: Colors.white,
                size: 26),
          ),
        ),
      ),
    );
  }
}
