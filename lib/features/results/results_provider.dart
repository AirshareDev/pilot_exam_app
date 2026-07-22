import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/questions_database.dart';
import '../../database/user_database.dart';
import '../../models/learning_results.dart';
import '../../models/question.dart';
import '../qualifications/selected_qualification_provider.dart';

final learningResultsProvider = FutureProvider<LearningResults?>((ref) async {
  final qualification = await ref.watch(selectedQualificationProvider.future);
  if (qualification == null) return null;

  final userDatabase = ref.read(userDatabaseProvider);
  final questionsDatabase = ref.read(questionsDatabaseProvider);

  final statuses = await userDatabase.loadAllQuestionStatuses(
    qualificationCode: qualification.code,
  );
  final recentRows = await userDatabase.loadRecentAnswerHistory(
    qualificationCode: qualification.code,
    limit: 20,
  );

  final questionCodes = <String>{
    ...statuses.map((row) => row.questionCode),
    ...recentRows.map((row) => row.questionCode),
  }.toList(growable: false);

  final questions = await questionsDatabase.loadQuestionsByCodes(
    databaseFileName: qualification.databaseFileName,
    questionCodes: questionCodes,
  );
  final questionMap = <String, Question>{
    for (final question in questions) question.questionCode: question,
  };

  var totalAnswers = 0;
  var correctAnswers = 0;
  final subjectTotals = <String, _MutableSubjectResult>{};

  for (final status in statuses) {
    final answers = status.correctCount + status.wrongCount;
    totalAnswers += answers;
    correctAnswers += status.correctCount;

    final question = questionMap[status.questionCode];
    final subjectName = _subjectName(question);
    final subject = subjectTotals.putIfAbsent(
      subjectName,
      () => _MutableSubjectResult(),
    );
    subject.totalAnswers += answers;
    subject.correctAnswers += status.correctCount;
  }

  final subjects = subjectTotals.entries
      .map(
        (entry) => SubjectLearningResult(
          subjectName: entry.key,
          totalAnswers: entry.value.totalAnswers,
          correctAnswers: entry.value.correctAnswers,
        ),
      )
      .toList(growable: false)
    ..sort((a, b) {
      final totalCompare = b.totalAnswers.compareTo(a.totalAnswers);
      if (totalCompare != 0) return totalCompare;
      return a.subjectName.compareTo(b.subjectName);
    });

  final recentAnswers = recentRows.map((row) {
    final question = questionMap[row.questionCode];
    return RecentAnswerResult(
      questionCode: row.questionCode,
      questionLabel: _questionLabel(question, row.questionCode),
      subjectName: _subjectName(question),
      isCorrect: row.isCorrect,
      answeredAt: row.answeredAt,
    );
  }).toList(growable: false);

  return LearningResults(
    qualificationName: qualification.name,
    totalAnswers: totalAnswers,
    correctAnswers: correctAnswers,
    answeredQuestions: statuses
        .where((row) => row.correctCount + row.wrongCount > 0)
        .length,
    subjects: subjects,
    recentAnswers: recentAnswers,
  );
});

String _subjectName(Question? question) {
  final value = question?.subjectName?.trim();
  return value == null || value.isEmpty ? '科目未設定' : value;
}

String _questionLabel(Question? question, String questionCode) {
  if (question == null) return questionCode;
  final metadata = question.metadataText.trim();
  return metadata.isEmpty ? questionCode : metadata;
}

class _MutableSubjectResult {
  int totalAnswers = 0;
  int correctAnswers = 0;
}
