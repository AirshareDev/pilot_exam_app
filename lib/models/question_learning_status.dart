class QuestionLearningStatus {
  const QuestionLearningStatus({
    required this.questionCode,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastResult,
    this.lastSelectedChoice,
    this.lastAnswered,
    this.isBookmarked = false,
  });

  final String questionCode;
  final int correctCount;
  final int wrongCount;
  final bool? lastResult;
  final int? lastSelectedChoice;
  final DateTime? lastAnswered;
  final bool isBookmarked;

  int get answerCount => correctCount + wrongCount;

  int get correctRate {
    if (answerCount == 0) return 0;
    return ((correctCount / answerCount) * 100).round();
  }

  QuestionLearningStatus copyWith({
    int? correctCount,
    int? wrongCount,
    bool? lastResult,
    int? lastSelectedChoice,
    DateTime? lastAnswered,
    bool? isBookmarked,
  }) {
    return QuestionLearningStatus(
      questionCode: questionCode,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lastResult: lastResult ?? this.lastResult,
      lastSelectedChoice: lastSelectedChoice ?? this.lastSelectedChoice,
      lastAnswered: lastAnswered ?? this.lastAnswered,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  factory QuestionLearningStatus.fromMap(Map<String, Object?> map) {
    final rawLastResult = map['last_result'];
    final rawLastAnswered = map['last_answered']?.toString();

    return QuestionLearningStatus(
      questionCode: map['question_code']?.toString() ?? '',
      correctCount: _asInt(map['correct_count']),
      wrongCount: _asInt(map['wrong_count']),
      lastResult: rawLastResult == null ? null : _asInt(rawLastResult) == 1,
      lastSelectedChoice: map['last_selected_choice'] == null
          ? null
          : _asInt(map['last_selected_choice']),
      lastAnswered: rawLastAnswered == null || rawLastAnswered.isEmpty
          ? null
          : DateTime.tryParse(rawLastAnswered),
      isBookmarked: _asInt(map['is_bookmarked']) == 1,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
