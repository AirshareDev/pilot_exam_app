class Subject {
  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    this.questionCount = 0,
  });

  final int id;
  final String code;
  final String name;
  final int sortOrder;
  final int questionCount;

  factory Subject.fromMap(Map<String, Object?> map) => Subject(
        id: map['subject_id'] as int,
        code: map['subject_code'] as String,
        name: map['subject_name'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        questionCount: (map['question_count'] as int?) ?? 0,
      );
}
