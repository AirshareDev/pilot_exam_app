import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/bundled_database_installer.dart';
import '../core/database/database_update_policy.dart';
import '../models/learning_results.dart';
import '../models/question_learning_status.dart';

const _userAssetPath = 'assets/data/user.db';
const _userInstalledName = 'user.db';

final userDatabaseProvider = Provider<UserDatabase>((ref) {
  return UserDatabase();
});

class UserDatabase {
  UserDatabase({
    BundledDatabaseInstaller installer = const BundledDatabaseInstaller(),
  }) : _installer = installer;

  final BundledDatabaseInstaller _installer;

  Future<Set<String>> loadPurchasedQualificationCodes() async {
    final db = await _open();
    if (db == null) return const {};
    try {
      final rows = await db.query(
        'purchases',
        columns: ['qualification_code'],
        where: 'purchase_status IN (?, ?)',
        whereArgs: ['purchased', 'restored'],
      );
      return rows
          .map((row) => row['qualification_code']?.toString())
          .whereType<String>()
          .toSet();
    } finally {
      await db.close();
    }
  }

  Future<List<Map<String, Object?>>> loadPurchases() async {
    final db = await _open();
    if (db == null) return const [];
    try {
      return await db.query(
        'purchases',
        orderBy: 'updated_at DESC',
      );
    } finally {
      await db.close();
    }
  }


  Future<Map<String, QuestionLearningStatus>> loadQuestionStatuses({
    required String qualificationCode,
    required List<String> questionCodes,
  }) async {
    if (questionCodes.isEmpty) return const {};

    final db = await _open();
    if (db == null) return const {};

    try {
      final placeholders = List.filled(questionCodes.length, '?').join(',');
      final rows = await db.rawQuery(
        '''
        SELECT
          question_code,
          correct_count,
          wrong_count,
          last_result,
          last_selected_choice,
          last_answered,
          is_bookmarked
        FROM user_question_status
        WHERE qualification_code = ?
          AND question_code IN ($placeholders)
        ''',
        <Object?>[qualificationCode, ...questionCodes],
      );

      return {
        for (final row in rows)
          row['question_code']!.toString():
              QuestionLearningStatus.fromMap(row),
      };
    } finally {
      await db.close();
    }
  }

  Future<Set<String>> loadBookmarkedQuestionCodes({
    required String qualificationCode,
  }) async {
    final db = await _open();
    if (db == null) return const {};
    try {
      final rows = await db.query(
        'user_question_status',
        columns: ['question_code'],
        where: 'qualification_code = ? AND is_bookmarked = 1',
        whereArgs: [qualificationCode],
      );
      return rows
          .map((row) => row['question_code']?.toString())
          .whereType<String>()
          .toSet();
    } finally {
      await db.close();
    }
  }

  Future<void> setBookmark({
    required String qualificationCode,
    required String questionCode,
    required bool isBookmarked,
  }) async {
    final db = await _requireOpen();
    try {
      await db.insert(
        'user_question_status',
        {
          'qualification_code': qualificationCode,
          'question_code': questionCode,
          'is_bookmarked': isBookmarked ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.update(
        'user_question_status',
        {'is_bookmarked': isBookmarked ? 1 : 0},
        where: 'qualification_code = ? AND question_code = ?',
        whereArgs: [qualificationCode, questionCode],
      );
    } finally {
      await db.close();
    }
  }

  Future<List<UserQuestionAggregate>> loadAllQuestionStatuses({
    required String qualificationCode,
  }) async {
    final db = await _open();
    if (db == null) return const [];
    try {
      final rows = await db.query(
        'user_question_status',
        columns: ['question_code', 'correct_count', 'wrong_count'],
        where: 'qualification_code = ?',
        whereArgs: [qualificationCode],
        orderBy: 'last_answered DESC',
      );
      return rows.map(UserQuestionAggregate.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<List<AnswerHistoryRecord>> loadRecentAnswerHistory({
    required String qualificationCode,
    int limit = 10,
  }) async {
    final db = await _open();
    if (db == null) return const [];
    try {
      final rows = await db.query(
        'answer_history',
        columns: ['question_code', 'is_correct', 'answered_at'],
        where: 'qualification_code = ?',
        whereArgs: [qualificationCode],
        orderBy: 'answered_at DESC, answer_history_id DESC',
        limit: limit,
      );
      return rows.map(AnswerHistoryRecord.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<List<ExamResultHistory>> loadExamResultHistory({
    required String qualificationCode,
    int limit = 20,
  }) async {
    final db = await _open();
    if (db == null) return const [];
    try {
      final resultRows = await db.rawQuery(
        '''
        SELECT rowid AS result_row_id, completed_at, total_questions,
               correct_questions
        FROM exam_results
        WHERE qualification_code = ?
        ORDER BY completed_at DESC, rowid DESC
        LIMIT ?
        ''',
        [qualificationCode, limit],
      );
      if (resultRows.isEmpty) return const [];

      final ids = resultRows
          .map((row) => _readIntValue(row['result_row_id']))
          .toList(growable: false);
      final placeholders = List.filled(ids.length, '?').join(',');
      final subjectRows = await db.rawQuery(
        '''
        SELECT exam_result_id, subject_name, total_questions, correct_questions
        FROM exam_result_subjects
        WHERE exam_result_id IN ($placeholders)
        ORDER BY exam_result_subject_id ASC
        ''',
        ids,
      );

      final subjectsByResult = <int, List<ExamSubjectHistory>>{};
      for (final row in subjectRows) {
        final resultId = _readIntValue(row['exam_result_id']);
        subjectsByResult.putIfAbsent(resultId, () => []).add(
              ExamSubjectHistory(
                subjectName: row['subject_name']?.toString() ?? '科目未設定',
                totalQuestions: _readIntValue(row['total_questions']),
                correctQuestions: _readIntValue(row['correct_questions']),
              ),
            );
      }

      return resultRows.map((row) {
        final resultId = _readIntValue(row['result_row_id']);
        return ExamResultHistory(
          completedAt: DateTime.tryParse(row['completed_at']?.toString() ?? ''),
          totalQuestions: _readIntValue(row['total_questions']),
          correctQuestions: _readIntValue(row['correct_questions']),
          subjects: List.unmodifiable(subjectsByResult[resultId] ?? const []),
        );
      }).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<void> recordExamResult({
    required String qualificationCode,
    required DateTime startedAt,
    required DateTime completedAt,
    required int totalQuestions,
    required int correctQuestions,
    required int passingScorePercent,
    required List<ExamSubjectResultInput> subjectResults,
    String mockExamPatternCode = 'standard',
  }) async {
    final db = await _requireOpen();
    try {
      final score = totalQuestions == 0
          ? 0.0
          : correctQuestions / totalQuestions * 100;
      await db.transaction((txn) async {
        final resultId = await txn.insert('exam_results', {
          'qualification_code': qualificationCode,
          'mock_exam_pattern_code': mockExamPatternCode,
          'started_at': startedAt.toIso8601String(),
          'completed_at': completedAt.toIso8601String(),
          'total_questions': totalQuestions,
          'correct_questions': correctQuestions,
          'score': score,
          'is_passed': score >= passingScorePercent ? 1 : 0,
        });
        for (final subject in subjectResults) {
          await txn.insert('exam_result_subjects', {
            'exam_result_id': resultId,
            'subject_name': subject.subjectName,
            'total_questions': subject.totalQuestions,
            'correct_questions': subject.correctQuestions,
          });
        }
      });
    } finally {
      await db.close();
    }
  }

  Future<void> resetLearningResults({
    required String qualificationCode,
  }) async {
    final db = await _requireOpen();
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'answer_history',
          where: 'qualification_code = ?',
          whereArgs: [qualificationCode],
        );
        final resultRows = await txn.rawQuery(
          'SELECT rowid AS result_row_id FROM exam_results WHERE qualification_code = ?',
          [qualificationCode],
        );
        final resultIds = resultRows
            .map((row) => _readIntValue(row['result_row_id']))
            .toList(growable: false);
        if (resultIds.isNotEmpty) {
          final placeholders = List.filled(resultIds.length, '?').join(',');
          await txn.rawDelete(
            'DELETE FROM exam_result_subjects WHERE exam_result_id IN ($placeholders)',
            resultIds,
          );
        }
        await txn.delete(
          'exam_results',
          where: 'qualification_code = ?',
          whereArgs: [qualificationCode],
        );
        await txn.rawUpdate(
          '''
          UPDATE user_question_status
          SET correct_count = 0,
              wrong_count = 0,
              last_result = NULL,
              last_selected_choice = NULL,
              last_answered = NULL
          WHERE qualification_code = ?
          ''',
          [qualificationCode],
        );
      });
    } finally {
      await db.close();
    }
  }

  Future<void> recordAnswer({
    required String qualificationCode,
    required String questionCode,
    required int selectedChoice,
    required bool isCorrect,
  }) async {
    final db = await _requireOpen();
    final answeredAt = DateTime.now().toIso8601String();
    try {
      await db.transaction((txn) async {
        await txn.insert(
          'user_question_status',
          {
            'qualification_code': qualificationCode,
            'question_code': questionCode,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.rawUpdate('''
          UPDATE user_question_status
          SET correct_count = correct_count + ?,
              wrong_count = wrong_count + ?,
              last_result = ?,
              last_selected_choice = ?,
              last_answered = ?
          WHERE qualification_code = ? AND question_code = ?
        ''', [
          isCorrect ? 1 : 0,
          isCorrect ? 0 : 1,
          isCorrect ? 1 : 0,
          selectedChoice,
          answeredAt,
          qualificationCode,
          questionCode,
        ]);
        await txn.insert('answer_history', {
          'qualification_code': qualificationCode,
          'question_code': questionCode,
          'selected_choice': selectedChoice,
          'is_correct': isCorrect ? 1 : 0,
          'answered_at': answeredAt,
        });
      });
    } finally {
      await db.close();
    }
  }

  Future<Database?> _open() async {
    final path = await _installer.install(
      assetPath: _userAssetPath,
      installedFileName: _userInstalledName,
      updatePolicy: DatabaseUpdatePolicy.preserveInstalled,
    );
    if (path == null) return null;
    return openDatabase(
      path,
      onOpen: _ensureSchema,
    );
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_result_subjects (
        exam_result_subject_id INTEGER PRIMARY KEY AUTOINCREMENT,
        exam_result_id INTEGER NOT NULL,
        subject_name TEXT NOT NULL,
        total_questions INTEGER NOT NULL DEFAULT 0,
        correct_questions INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exam_result_subjects_result
      ON exam_result_subjects(exam_result_id)
    ''');
  }

  Future<Database> _requireOpen() async {
    final db = await _open();
    if (db == null) throw StateError('user.dbを開けませんでした。');
    return db;
  }
}


int _readIntValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
