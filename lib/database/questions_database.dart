import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/exam_session.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../core/database/bundled_database_installer.dart';
import '../core/database/database_update_policy.dart';

final questionsDatabaseProvider = Provider<QuestionsDatabase>((ref) {
  return QuestionsDatabase();
});

class QuestionsDatabase {
  QuestionsDatabase({
    BundledDatabaseInstaller installer = const BundledDatabaseInstaller(),
  }) : _installer = installer;

  final BundledDatabaseInstaller _installer;

  static const String _questionSelect = '''
    SELECT
      q.*,
      s.subject_code,
      s.subject_name,
      es.exam_year,
      es.exam_month,
      es.session_name,
      es.session_code
    FROM questions q
    LEFT JOIN subjects s ON s.subject_id = q.subject_id
    LEFT JOIN exam_sessions es
      ON es.exam_session_id = q.exam_session_id
  ''';

  Future<List<Subject>> loadSubjects({
    required String databaseFileName,
  }) async {
    final db = await _open(databaseFileName);
    if (db == null) return const [];
    try {
      final rows = await db.rawQuery(
        '''
        SELECT
          s.subject_id,
          s.subject_code,
          s.subject_name,
          s.sort_order,
          COUNT(q.question_id) AS question_count
        FROM subjects s
        LEFT JOIN questions q
          ON q.subject_id = s.subject_id
          AND q.is_active = 1
        WHERE s.is_active = 1
        GROUP BY
          s.subject_id,
          s.subject_code,
          s.subject_name,
          s.sort_order
        ORDER BY s.sort_order, s.subject_id
        ''',
      );
      return rows.map(Subject.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<List<ExamSession>> loadExamSessions({
    required String databaseFileName,
  }) async {
    final db = await _open(databaseFileName);
    if (db == null) return const [];
    try {
      final rows = await db.rawQuery(
        '''
        SELECT
          es.exam_session_id,
          es.exam_year,
          es.exam_month,
          es.session_name,
          es.session_code,
          es.sort_order,
          COUNT(q.question_id) AS question_count
        FROM exam_sessions es
        LEFT JOIN questions q
          ON q.exam_session_id = es.exam_session_id
          AND q.is_active = 1
        WHERE es.is_active = 1
        GROUP BY
          es.exam_session_id,
          es.exam_year,
          es.exam_month,
          es.session_name,
          es.session_code,
          es.sort_order
        ORDER BY
          es.sort_order DESC,
          es.exam_year DESC,
          es.exam_month DESC,
          es.exam_session_id DESC
        ''',
      );
      return rows.map(ExamSession.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<List<Question>> loadRandomQuestions({
    required String databaseFileName,
    int? subjectId,
    int? examSessionId,
    int limit = 20,
  }) async {
    final conditions = <String>['q.is_active = 1'];
    final args = <Object?>[];
    if (subjectId != null) {
      conditions.add('q.subject_id = ?');
      args.add(subjectId);
    }
    if (examSessionId != null) {
      conditions.add('q.exam_session_id = ?');
      args.add(examSessionId);
    }
    args.add(limit);

    return _loadQuestions(
      databaseFileName: databaseFileName,
      suffix: '''
        WHERE ${conditions.join(' AND ')}
        ORDER BY RANDOM()
        LIMIT ?
      ''',
      args: args,
    );
  }

  Future<List<Question>> loadQuestionsBySubject({
    required String databaseFileName,
    required int subjectId,
  }) {
    return _loadQuestions(
      databaseFileName: databaseFileName,
      suffix: '''
        WHERE q.subject_id = ? AND q.is_active = 1
        ORDER BY es.sort_order DESC, q.question_no, q.question_id
      ''',
      args: [subjectId],
    );
  }

  Future<List<Question>> loadQuestionsByExamSession({
    required String databaseFileName,
    required int examSessionId,
    int? subjectId,
  }) {
    final conditions = <String>[
      'q.exam_session_id = ?',
      'q.is_active = 1',
    ];
    final args = <Object?>[examSessionId];
    if (subjectId != null) {
      conditions.add('q.subject_id = ?');
      args.add(subjectId);
    }

    return _loadQuestions(
      databaseFileName: databaseFileName,
      suffix: '''
        WHERE ${conditions.join(' AND ')}
        ORDER BY s.sort_order, q.question_no, q.question_id
      ''',
      args: args,
    );
  }

  Future<List<Question>> loadQuestionsByCodes({
    required String databaseFileName,
    required List<String> questionCodes,
  }) async {
    if (questionCodes.isEmpty) return const [];
    final placeholders = List.filled(questionCodes.length, '?').join(',');
    return _loadQuestions(
      databaseFileName: databaseFileName,
      suffix: 'WHERE q.question_code IN ($placeholders)',
      args: questionCodes,
    );
  }

  Future<List<Question>> _loadQuestions({
    required String databaseFileName,
    required String suffix,
    required List<Object?> args,
  }) async {
    final db = await _open(databaseFileName);
    if (db == null) return const [];
    try {
      final rows = await db.rawQuery('$_questionSelect\n$suffix', args);
      return rows.map(Question.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<Database?> _open(String databaseFileName) async {
    _validateDatabaseFileName(databaseFileName);
    final path = await _installer.install(
      assetPath: 'assets/data/$databaseFileName',
      installedFileName: databaseFileName,
      updatePolicy: DatabaseUpdatePolicy.replaceWhenNewer,
    );
    if (path == null) return null;
    return openDatabase(path, readOnly: true);
  }

  void _validateDatabaseFileName(String value) {
    final valid = RegExp(r'^[A-Za-z0-9_-]+\.db$').hasMatch(value);
    if (!valid) {
      throw ArgumentError.value(value, 'databaseFileName', '不正なDB名です。');
    }
  }
}
