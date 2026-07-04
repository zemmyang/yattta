import 'package:flutter_test/flutter_test.dart';
import 'package:yattta/data/sync/serializers/braindump_file_serializer.dart';
import 'package:yattta/domain/sync/parsed_models.dart';

void main() {
  group('BraindumpFileSerializer', () {
    final now = DateTime(2023, 10, 27, 10, 0);

    test('should serialize and parse a single braindump with tags', () {
      final dump = ParsedBrainDump(
        id: '11111111-2222-3333-4444-555555555555',
        note: 'This is a test note\nwith multiple lines.',
        isReviewed: true,
        tags: ['work', 'urgent'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

      final output = BraindumpFileSerializer.serializeSingle(dump);

      expect(output, contains('id: 11111111-2222-3333-4444-555555555555'));
      expect(output, contains('reviewed: true'));
      expect(output, contains('tags: [work, urgent]'));
      expect(output, contains('This is a test note\nwith multiple lines.'));

      final result = BraindumpFileSerializer.parseSingle(output);

      expect(result.id, dump.id);
      expect(result.note, dump.note);
      expect(result.isReviewed, true);
      expect(result.tags, ['work', 'urgent']);
      expect(result.createdAt, dump.createdAt);
      expect(result.updatedAt, dump.updatedAt);
    });

    test('should serialize and parse legacy single-file format with tags', () {
      final dumps = [
        ParsedBrainDump(
          id: '11111111-2222-3333-4444-555555555555',
          note: 'Note 1',
          isReviewed: false,
          tags: ['personal'],
          createdAt: now,
          updatedAt: now,
        ),
        ParsedBrainDump(
          id: '22222222-2222-3333-4444-555555555555',
          note: 'Note 2',
          isReviewed: true,
          tags: [],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final output = BraindumpFileSerializer.serialize(dumps);

      expect(output, contains('- [ ] Note 1 `11111111`'));
      expect(output, contains('tags: [personal]'));
      expect(output, contains('- [x] Note 2 `22222222`'));

      final result = BraindumpFileSerializer.parse(output);

      expect(result.length, 2);
      expect(result[0].id, dumps[0].id);
      expect(result[0].note, 'Note 1');
      expect(result[0].isReviewed, false);
      expect(result[0].tags, ['personal']);
      expect(result[1].id, dumps[1].id);
      expect(result[1].note, 'Note 2');
      expect(result[1].isReviewed, true);
      expect(result[1].tags, isEmpty);
    });
  });
}
