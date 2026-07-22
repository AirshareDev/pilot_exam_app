class Qualification {
  const Qualification({
    required this.id,
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.code,
    required this.name,
    required this.databaseFileName,
    required this.sortOrder,
    required this.isFree,
    required this.priceYen,
    required this.isVisible,
    required this.isEnabled,
    this.shortName,
    this.description = '',
    this.productId,
    this.features = const QualificationFeatures(),
  });

  final int id;
  final int categoryId;
  final String categoryCode;
  final String categoryName;
  final String code;
  final String name;
  final String? shortName;
  final String databaseFileName;
  final String description;
  final int sortOrder;
  final bool isFree;
  final int priceYen;
  final String? productId;
  final bool isVisible;
  final bool isEnabled;
  final QualificationFeatures features;

  factory Qualification.fromMap(Map<String, Object?> map) {
    return Qualification(
      id: _int(map['qualification_id']),
      categoryId: _int(map['category_id']),
      categoryCode: _string(map['category_code']),
      categoryName: _string(map['category_name']),
      code: _string(map['qualification_code']),
      name: _string(map['qualification_name']),
      shortName: _nullableString(map['short_name']),
      databaseFileName: _string(map['database_file_name']),
      description: _nullableString(map['description']) ?? '',
      sortOrder: _int(map['sort_order']),
      isFree: _bool(map['is_free']),
      priceYen: _int(map['price_yen'], defaultValue: 1000),
      productId: _nullableString(map['product_id']),
      isVisible: _bool(map['is_visible'], defaultValue: true),
      isEnabled: _bool(map['is_enabled'], defaultValue: true),
      features: QualificationFeatures.fromMap(map),
    );
  }
}

class QualificationFeatures {
  const QualificationFeatures({
    this.hasExamSessions = true,
    this.hasSubjects = true,
    this.hasMockExam = true,
    this.supportsImage = true,
    this.supportsAudio = false,
    this.supportsMultipleAnswers = false,
    this.maxChoices = 5,
  });

  final bool hasExamSessions;
  final bool hasSubjects;
  final bool hasMockExam;
  final bool supportsImage;
  final bool supportsAudio;
  final bool supportsMultipleAnswers;
  final int maxChoices;

  factory QualificationFeatures.fromMap(Map<String, Object?> map) {
    return QualificationFeatures(
      hasExamSessions: _bool(map['has_exam_sessions'], defaultValue: true),
      hasSubjects: _bool(map['has_subjects'], defaultValue: true),
      hasMockExam: _bool(map['has_mock_exam'], defaultValue: true),
      supportsImage: _bool(map['supports_image'], defaultValue: true),
      supportsAudio: _bool(map['supports_audio']),
      supportsMultipleAnswers: _bool(map['supports_multiple_answers']),
      maxChoices: _int(map['max_choices'], defaultValue: 5),
    );
  }
}

int _int(Object? value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

bool _bool(Object? value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  return _int(value) == 1;
}

String _string(Object? value) {
  if (value == null) throw const FormatException('必須文字列がありません。');
  return value.toString();
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
