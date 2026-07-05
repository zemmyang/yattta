import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/sync/serializers/todo_file_serializer.dart';
import 'package:yattta/domain/sync/parsed_models.dart';

void main() {
  group('TodoFileSerializer', () {
    final now = DateTime(2023, 10, 27, 10, 0);

    test('should serialize priority labels into the title', () {
      final todos = [
        ParsedTodo(
          id: '11111111-2222-3333-4444-555555555555',
          title: 'High Priority',
          completed: false,
          priority: ParsedPriority.high,
          tags: [],
          updatedAt: now,
        ),
        ParsedTodo(
          id: '22222222-2222-3333-4444-555555555555',
          title: 'Low Priority',
          completed: true,
          priority: ParsedPriority.low,
          tags: [],
          updatedAt: now,
        ),
        ParsedTodo(
          id: '33333333-2222-3333-4444-555555555555',
          title: 'Normal Priority',
          completed: false,
          priority: ParsedPriority.normal,
          tags: [],
          updatedAt: now,
        ),
      ];

      final output = TodoFileSerializer.serialize(todos);

      expect(output, contains('- [ ] (H) High Priority `11111111`'));
      expect(output, contains('- [x] (L) Low Priority `22222222`'));
      expect(output, contains('- [ ] Normal Priority `33333333`'));
    });

    test('should parse priority labels from the title', () {
      const content = '''---
sync:
  - id: 11111111-2222-3333-4444-555555555555
    updated: 2023-10-27T10:00:00.000
  - id: 22222222-2222-3333-4444-555555555555
    updated: 2023-10-27T10:00:00.000
  - id: 33333333-2222-3333-4444-555555555555
    updated: 2023-10-27T10:00:00.000
---

# Todos

- [ ] (H) High Priority `11111111`
- [x] (L) Low Priority `22222222`
- [ ] Normal Priority `33333333`
''';

      final result = TodoFileSerializer.parse(content);

      expect(result.length, 3);
      
      expect(result[0].title, 'High Priority');
      expect(result[0].priority, ParsedPriority.high);
      
      expect(result[1].title, 'Low Priority');
      expect(result[1].priority, ParsedPriority.low);
      
      expect(result[2].title, 'Normal Priority');
      expect(result[2].priority, ParsedPriority.normal);
    });

    test('should prefer label priority over frontmatter if different', () {
      const content = '''---
sync:
  - id: 11111111-2222-3333-4444-555555555555
    priority: low
    updated: 2023-10-27T10:00:00.000
---

# Todos

- [ ] (H) High Priority `11111111`
''';

      final result = TodoFileSerializer.parse(content);

      expect(result[0].priority, ParsedPriority.high);
    });

    test('should serialize due date with time and seconds', () {
      final todos = [
        ParsedTodo(
          id: '11111111-2222-3333-4444-555555555555',
          title: 'Due task',
          completed: false,
          priority: ParsedPriority.normal,
          tags: [],
          updatedAt: now,
          dueAt: DateTime(2023, 10, 30, 14, 45, 30),
        ),
      ];

      final output = TodoFileSerializer.serialize(todos);
      expect(output, contains('due: "2023-10-30 14:45:30"'));
    });

    test('should parse due date with and without time', () {
      const content = '''---
sync:
  - id: 11111111-2222-3333-4444-555555555555
    due: 2023-10-30 14:45:30
    updated: 2023-10-27T10:00:00.000
  - id: 22222222-2222-3333-4444-555555555555
    due: 2023-10-31
    updated: 2023-10-27T10:00:00.000
---

# Todos

- [ ] Due task `11111111`
- [ ] Due date only `22222222`
''';

      final result = TodoFileSerializer.parse(content);
      expect(result[0].dueAt, DateTime(2023, 10, 30, 14, 45, 30));
      expect(result[1].dueAt, DateTime(2023, 10, 31));
    });
  });
}
