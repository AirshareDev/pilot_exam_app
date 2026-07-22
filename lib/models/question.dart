class Question {
  const Question({
    required this.id,
    required this.questionCode,
    required this.questionText,
    required this.choices,
    required this.correctChoice,
    required this.explanation,
    required this.isActive,
    this.examSessionId,
    this.examYear,
    this.examMonth,
    this.examSessionName,
    this.examSessionCode,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.questionNo,
    this.imagePath,
    this.audioPath,
    this.reference,
    this.isBookmarked = false,
    this.isAllCorrect = false,
  });

  final int id;
  final String questionCode;

  final int? examSessionId;
  final int? examYear;
  final int? examMonth;
  final String? examSessionName;
  final String? examSessionCode;

  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;

  final int? questionNo;

  final String questionText;
  final String? imagePath;
  final String? audioPath;

  final List<String> choices;
  final int? correctChoice;

  final String explanation;
  final String? reference;

  final bool isActive;
  final bool isBookmarked;
  final bool isAllCorrect;

  /// 既存画面との互換用。
  String get text => questionText;

  bool isCorrectChoice(int choiceNumber) {
    if (choiceNumber < 1 || choiceNumber > choices.length) {
      return false;
    }

    return isAllCorrect || choiceNumber == correctChoice;
  }

  String getChoice(int choiceNumber) {
    if (choiceNumber < 1 || choiceNumber > choices.length) {
      throw RangeError.range(
        choiceNumber,
        1,
        choices.length,
        'choiceNumber',
      );
    }

    return choices[choiceNumber - 1];
  }

  String get metadataText {
    final parts = <String>[];

    final currentSubjectName = subjectName;
    if (currentSubjectName != null && currentSubjectName.isNotEmpty) {
      parts.add(currentSubjectName);
    }

    final currentSessionName = examSessionName;
    if (currentSessionName != null && currentSessionName.isNotEmpty) {
      parts.add(currentSessionName);
    } else if (examYear != null) {
      final month = examMonth;
      parts.add(month == null ? '$examYear年' : '$examYear年$month月期');
    }

    if (questionNo != null) {
      parts.add('問$questionNo');
    }

    return parts.join('・');
  }

  Question copyWith({
    int? id,
    String? questionCode,
    int? examSessionId,
    int? examYear,
    int? examMonth,
    String? examSessionName,
    String? examSessionCode,
    int? subjectId,
    String? subjectCode,
    String? subjectName,
    int? questionNo,
    String? questionText,
    String? imagePath,
    String? audioPath,
    List<String>? choices,
    int? correctChoice,
    String? explanation,
    String? reference,
    bool? isActive,
    bool? isBookmarked,
    bool? isAllCorrect,
  }) {
    return Question(
      id: id ?? this.id,
      questionCode: questionCode ?? this.questionCode,
      examSessionId: examSessionId ?? this.examSessionId,
      examYear: examYear ?? this.examYear,
      examMonth: examMonth ?? this.examMonth,
      examSessionName: examSessionName ?? this.examSessionName,
      examSessionCode: examSessionCode ?? this.examSessionCode,
      subjectId: subjectId ?? this.subjectId,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      questionNo: questionNo ?? this.questionNo,
      questionText: questionText ?? this.questionText,
      imagePath: imagePath ?? this.imagePath,
      audioPath: audioPath ?? this.audioPath,
      choices: choices ?? this.choices,
      correctChoice: correctChoice ?? this.correctChoice,
      explanation: explanation ?? this.explanation,
      reference: reference ?? this.reference,
      isActive: isActive ?? this.isActive,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isAllCorrect: isAllCorrect ?? this.isAllCorrect,
    );
  }

  factory Question.fromMap(Map<String, Object?> map) {
    return Question(
      id: _readRequiredInt(
        map,
        const ['question_id', 'id'],
      ),
      questionCode: _readRequiredString(
        map,
        const ['question_code'],
      ),
      examSessionId: _readNullableInt(
        map,
        const ['exam_session_id'],
      ),
      examYear: _readNullableInt(
        map,
        const ['exam_year', 'year'],
      ),
      examMonth: _readNullableInt(
        map,
        const ['exam_month'],
      ),
      examSessionName: _readNullableString(
        map,
        const ['session_name', 'session'],
      ),
      examSessionCode: _readNullableString(
        map,
        const ['session_code'],
      ),
      subjectId: _readNullableInt(
        map,
        const ['subject_id'],
      ),
      subjectCode: _readNullableString(
        map,
        const ['subject_code'],
      ),
      subjectName: _readNullableString(
        map,
        const ['subject_name'],
      ),
      questionNo: _readNullableInt(
        map,
        const ['question_no'],
      ),
      questionText: _readRequiredString(
        map,
        const ['question_text', 'question', 'text'],
      ),
      imagePath: _readNullableString(
        map,
        const ['image_path'],
      ),
      audioPath: _readNullableString(
        map,
        const ['audio_path'],
      ),
      choices: _readChoices(map),
      correctChoice: _readNullableInt(
        map,
        const ['correct_choice'],
      ),
      explanation: _readNullableString(
            map,
            const ['explanation'],
          ) ??
          '',
      reference: _readNullableString(
        map,
        const ['reference'],
      ),
      isActive: (_readNullableInt(
                map,
                const ['is_active'],
              ) ??
              1) ==
          1,
      isBookmarked: (_readNullableInt(
                map,
                const ['is_bookmarked'],
              ) ??
              0) ==
          1,
      isAllCorrect: (_readNullableInt(
                map,
                const ['is_all_correct'],
              ) ??
              0) ==
          1,
    );
  }
}

List<String> _readChoices(Map<String, Object?> map) {
  final choices = <String>[];

  for (var choiceNumber = 1; choiceNumber <= 5; choiceNumber++) {
    final choice = _readNullableString(
      map,
      ['choice_$choiceNumber'],
    );

    if (choice != null) {
      choices.add(choice);
    }
  }

  if (choices.isEmpty) {
    throw const FormatException('選択肢を読み込めませんでした。');
  }

  return choices;
}

Object? _findValue(
  Map<String, Object?> map,
  List<String> keys,
) {
  for (final key in keys) {
    if (map.containsKey(key)) {
      return map[key];
    }
  }

  return null;
}

int _readRequiredInt(
  Map<String, Object?> map,
  List<String> keys,
) {
  final value = _findValue(map, keys);

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    final parsed = int.tryParse(value);

    if (parsed != null) {
      return parsed;
    }
  }

  throw FormatException(
    '整数項目を読み込めませんでした: ${keys.join(', ')}',
  );
}

int? _readNullableInt(
  Map<String, Object?> map,
  List<String> keys,
) {
  final value = _findValue(map, keys);

  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

String _readRequiredString(
  Map<String, Object?> map,
  List<String> keys,
) {
  final value = _findValue(map, keys);

  if (value == null) {
    throw FormatException(
      '文字列項目を読み込めませんでした: ${keys.join(', ')}',
    );
  }

  return value.toString();
}

String? _readNullableString(
  Map<String, Object?> map,
  List<String> keys,
) {
  final value = _findValue(map, keys);

  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return text;
}
