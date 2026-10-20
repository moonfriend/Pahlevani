import 'package:flutter/material.dart';

import '../../../core/theme/kashi/kashi_colors.dart';
import '../../../domain/usecases/tracking/training_history_aggregations.dart';
import '../../widgets/kashi/kashi_rep_tile.dart';

/// Every counted move as a card, most-counted first. Home only has room for
/// two; this page holds the rest.
class CountedMovesPage extends StatelessWidget {
  const CountedMovesPage({super.key, required this.trends});

  final List<MovementTrend> trends;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<KashiColors>()!;
    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(title: const Text('Counted moves')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 104,
            ),
            itemCount: trends.length,
            itemBuilder: (context, i) => KashiRepTile(trend: trends[i]),
          ),
        ),
      ),
    );
  }
}
