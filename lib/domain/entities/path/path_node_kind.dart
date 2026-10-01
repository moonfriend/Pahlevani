/// A stop on the path: a small waypoint ("Godar"), or a bigger "test stage"
/// ("Darvazeh" — the Gate — or a "Khan" — both are the same underlying
/// concept, differing only in display name/graphics, which live in
/// [PathNode.title]/[PathNode.titleFa] rather than a separate type).
enum PathNodeKind {
  godar,
  milestone;

  static PathNodeKind fromDbValue(String value) => switch (value) {
        'godar' => PathNodeKind.godar,
        'milestone' => PathNodeKind.milestone,
        _ => throw ArgumentError('Unknown path_node.kind: $value'),
      };

  String toDbValue() => switch (this) {
        PathNodeKind.godar => 'godar',
        PathNodeKind.milestone => 'milestone',
      };
}
