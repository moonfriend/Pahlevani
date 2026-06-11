import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

// ── Sessions ─────────────────────────────────────────────────────────────────

final testSession1 = TrainingSession(
  id: 1,
  title: 'Beginner Warm-up',
  description: 'A gentle introduction to the Zurkhaneh',
  difficulty: 1,
);

final testSession2 = TrainingSession(
  id: 2,
  title: 'Advanced Drill',
  description: 'For experienced warriors',
  difficulty: 3,
  isUserCreated: true,
);

// ── Exercises ─────────────────────────────────────────────────────────────────

const testExercise1 = Exercise(
  id: 101,
  name: 'Shena',
  audioFileUrl: 'https://example.com/shena.mp3',
  repetitionsDefault: 3,
);

const testExercise2 = Exercise(
  id: 102,
  name: 'Kabbadeh',
  audioFileUrl: 'https://example.com/kabbadeh.mp3',
  repetitionsDefault: 1,
);

const testExercise3 = Exercise(
  id: 103,
  name: 'Charkh',
  audioFileUrl: 'https://example.com/charkh.mp3',
  repetitionsDefault: 2,
);

// ── Training items (id = sessionId * 10000 + position) ───────────────────────

const testItem1 = TrainingItem(
  id: 10001,
  sessionId: 1,
  exerciseId: 101,
  position: 1,
  prescription: RepsPresc(3),
);
const testItem2 = TrainingItem(
  id: 10002,
  sessionId: 1,
  exerciseId: 102,
  position: 2,
  prescription: RepsPresc(1),
);
const testItem3 = TrainingItem(
  id: 20001,
  sessionId: 2,
  exerciseId: 102,
  position: 1,
  prescription: RepsPresc(2),
);
const testItem4 = TrainingItem(
  id: 20002,
  sessionId: 2,
  exerciseId: 103,
  position: 2,
  prescription: RepsPresc(2),
);

// ── Full snapshot ─────────────────────────────────────────────────────────────

DomainSnapshot buildTestSnapshot() => DomainSnapshot(
      sessionsById: {
        testSession1.id: testSession1,
        testSession2.id: testSession2,
      },
      itemsBySessionId: {
        1: [testItem1, testItem2],
        2: [testItem3, testItem4],
      },
      exercisesById: {
        101: testExercise1,
        102: testExercise2,
        103: testExercise3,
      },
    );
