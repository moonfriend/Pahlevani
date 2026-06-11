import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

/// A ready-to-render aggregate for the UI (read model).
class ItemDetail {
  final TrainingItem item;
  final Exercise exercise;
  const ItemDetail({required this.item, required this.exercise});
}

class SessionDetail {
  final TrainingSession session;
  final List<ItemDetail> items; // ordered by position
  const SessionDetail({required this.session, required this.items});
}
