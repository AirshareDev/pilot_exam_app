class LearningResults {
  const LearningResults({
    required this.qualificationName,
    required this.totalAnswers,
    required this.correctAnswers,
    required this.answeredQuestions,
    required this.subjects,
    required this.recentAnswers,
    required this.examHistory,
  });

  final String qualificationName;
  final int totalAnswers;
  final int correctAnswers;
  final int answeredQuestions;
  final List<SubjectLearningResult> subjects;
  final List<RecentAnswerResult> recentAnswers;
  final List<ExamResultHistory> examHistory;

  int get wrongAnswers => totalAnswers - correctAnswers;

  double get accuracy =>
      totalAnswers == 0 ? 0 : correctAnswers / totalAnswers;

  SubjectLearningResult? get weakestSubject {
    final answered = subjects.where((item) => item.totalAnswers > 0).toList();
    if (answered.isEmpty) return null;
    answered.sort((a, b) {
      final accuracyCompare = a.accuracy.compareTo(b.accuracy);
      if (accuracyCompare != 0) return accuracyCompare;
      return b.totalAnswers.compareTo(a.totalAnswers);
    });
    return answered.first;
  }
}

class SubjectLearningResult {
  const SubjectLearningResult({
    required this.subjectName,
    required this.totalAnswers,
    required this.correctAnswers,
  });

  final String subjectName;
  final int totalAnswers;
  final int correctAnswers;

  int get wrongAnswers => totalAnswers - correctAnswers;

  double get accuracy =>
      totalAnswers == 0 ? 0 : correctAnswers / totalAnswers;
}

class RecentAnswerResult {
  const RecentAnswerResult({
    required this.questionCode,
    required this.questionLabel,
    required this.subjectName,
    required this.isCorrect,
    required this.answeredAt,
  });

  final String questionCode;
  final String questionLabel;
  final String subjectName;
  final bool isCorrect;
  final DateTime? answeredAt;
}

class ExamSubjectResultInput {
  const ExamSubjectResultInput({
    required this.subjectName,
    required this.totalQuestions,
    required this.correctQuestions,
  });

  final String subjectName;
  final int totalQuestions;
  final int correctQuestions;
}

class ExamResultHistory {
  const ExamResultHistory({
    required this.completedAt,
    required this.totalQuestions,
    required this.correctQuestions,
    required this.subjects,
  });

  final DateTime? completedAt;
  final int totalQuestions;
  final int correctQuestions;
  final List<ExamSubjectHistory> subjects;

  int get wrongQuestions => totalQuestions - correctQuestions;
  double get accuracy =>
      totalQuestions == 0 ? 0 : correctQuestions / totalQuestions;
}

class ExamSubjectHistory {
  const ExamSubjectHistory({
    required this.subjectName,
    required this.totalQuestions,
    required this.correctQuestions,
  });

  final String subjectName;
  final int totalQuestions;
  final int correctQuestions;

  int get wrongQuestions => totalQuestions - correctQuestions;
}

class UserQuestionAggregate {
  const UserQuestionAggregate({
    required this.questionCode,
    required this.correctCount,
    required this.wrongCount,
  });

  final String questionCode;
  final int correctCount;
  final int wrongCount;

  factory UserQuestionAggregate.fromMap(Map<String, Object?> map) {
    return UserQuestionAggregate(
      questionCode: map['question_code']?.toString() ?? '',
      correctCount: _readInt(map['correct_count']),
      wrongCount: _readInt(map['wrong_count']),
    );
  }
}

class AnswerHistoryRecord {
  const AnswerHistoryRecord({
    required this.questionCode,
    required this.isCorrect,
    required this.answeredAt,
  });

  final String questionCode;
  final bool isCorrect;
  final DateTime? answeredAt;

  factory AnswerHistoryRecord.fromMap(Map<String, Object?> map) {
    return AnswerHistoryRecord(
      questionCode: map['question_code']?.toString() ?? '',
      isCorrect: _readInt(map['is_correct']) == 1,
      answeredAt: DateTime.tryParse(map['answered_at']?.toString() ?? ''),
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
