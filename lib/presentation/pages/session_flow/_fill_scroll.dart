import 'package:flutter/widgets.dart';

/// A column that fills the screen (so [Spacer]s push actions to the bottom)
/// but scrolls instead of overflowing on short screens.
class FillScroll extends StatelessWidget {
  const FillScroll({super.key, required this.padding, required this.children});

  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      );
}
