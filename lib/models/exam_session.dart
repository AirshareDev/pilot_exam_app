class ExamSession {
  const ExamSession({
    required this.id,
    required this.year,
    required this.name,
    required this.code,
    required this.sortOrder,
    this.month,
    this.questionCount = 0,
  });

  final int id;
  final int year;
  final int? month;
  final String name;
  final String code;
  final int sortOrder;
  final int questionCount;

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    if (month != null) return '$year年$month月期';
    return '$year年';
  }

  factory ExamSession.fromMap(Map<String, Object?> map) => ExamSession(
        id: map['exam_session_id'] as int,
        year: map['exam_year'] as int,
        month: map['exam_month'] as int?,
        name: (map['session_name'] as String?) ?? '',
        code: (map['session_code'] as String?) ?? '',
        sortOrder: (map['sort_order'] as int?) ?? 0,
        questionCount: (map['question_count'] as int?) ?? 0,
      );
}
