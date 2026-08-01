import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rule.dart';

class RuleDto {
  static Rule fromMap(String id, Map<String, dynamic> data) {
    return Rule(id: id, text: data['text'] as String? ?? '');
  }

  static Map<String, dynamic> toMap(String text) => {
    'text': text,
    'createdAt': Timestamp.fromDate(DateTime.now()),
  };
}
