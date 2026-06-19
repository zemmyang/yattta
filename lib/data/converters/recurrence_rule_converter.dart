import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../domain/models/recurrence_rule.dart';

class RecurrenceRuleConverter extends TypeConverter<RecurrenceRule, String> {
  const RecurrenceRuleConverter();

  @override
  RecurrenceRule fromSql(String fromDb) {
    return RecurrenceRule.fromJson(jsonDecode(fromDb));
  }

  @override
  String toSql(RecurrenceRule value) {
    return jsonEncode(value.toJson());
  }
}