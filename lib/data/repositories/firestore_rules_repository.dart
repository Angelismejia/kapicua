import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rule.dart';
import '../../domain/repositories/rules_repository.dart';
import '../models/rule_dto.dart';

class FirestoreRulesRepository implements RulesRepository {
  final FirebaseFirestore _db;

  FirestoreRulesRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _rules =>
      _db.collection('rules');

  @override
  Stream<List<Rule>> watchRules() {
    return _rules
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => RuleDto.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> addRule(String text) async {
    await _rules.add(RuleDto.toMap(text));
  }

  @override
  Future<void> updateRule(String ruleId, String text) async {
    await _rules.doc(ruleId).update({'text': text});
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await _rules.doc(ruleId).delete();
  }
}
