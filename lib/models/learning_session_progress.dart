import 'qualification.dart';
import 'dart:convert';

class LearningSessionProgress {
  const LearningSessionProgress({
    required this.qualificationId,
    required this.qualificationCode,
    required this.qualificationName,
    required this.mode,
    required this.questionCodes,
    required this.nextIndex,
    required this.correctCount,
    required this.updatedAt,
    this.subjectId,
    this.subjectName,
    this.examSessionId,
    this.examSessionName,
    this.bookmarkedOnly = false,
  });

  final int qualificationId;
  final String qualificationCode;
  final String qualificationName;
  final String mode;
  final List<String> questionCodes;
  final int nextIndex;
  final int correctCount;
  final DateTime updatedAt;
  final int? subjectId;
  final String? subjectName;
  final int? examSessionId;
  final String? examSessionName;
  final bool bookmarkedOnly;

  int get totalQuestions => questionCodes.length;

  bool get canResume =>
      questionCodes.isNotEmpty && nextIndex >= 0 && nextIndex < totalQuestions;

  String get modeLabel {
    if (bookmarkedOnly) return 'ブックマーク';
    if (subjectName != null && subjectName!.isNotEmpty) return subjectName!;
    if (examSessionName != null && examSessionName!.isNotEmpty) {
      return examSessionName!;
    }
    return 'ランダム一問一答';
  }

  String get progressLabel => '${nextIndex + 1} / $totalQuestions';

  Map<String, Object?> toMap() => <String, Object?>{
        'qualificationId': qualificationId,
        'qualificationCode': qualificationCode,
        'qualificationName': qualificationName,
        'mode': mode,
        'questionCodes': questionCodes,
        'nextIndex': nextIndex,
        'correctCount': correctCount,
        'updatedAt': updatedAt.toIso8601String(),
        'subjectId': subjectId,
        'subjectName': subjectName,
        'examSessionId': examSessionId,
        'examSessionName': examSessionName,
        'bookmarkedOnly': bookmarkedOnly,
      };

  String toJson() => jsonEncode(toMap());

  factory LearningSessionProgress.fromJson(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('学習再開情報の形式が不正です。');
    }
    return LearningSessionProgress.fromMap(value);
  }

  factory LearningSessionProgress.fromMap(Map<String, dynamic> map) {
    final codesValue = map['questionCodes'];
    final codes = codesValue is List
        ? codesValue.map((value) => value.toString()).toList(growable: false)
        : const <String>[];

    return LearningSessionProgress(
      qualificationId: _readInt(map['qualificationId']),
      qualificationCode: map['qualificationCode']?.toString() ?? '',
      qualificationName: map['qualificationName']?.toString() ?? '',
      mode: map['mode']?.toString() ?? 'random',
      questionCodes: codes,
      nextIndex: _readInt(map['nextIndex']),
      correctCount: _readInt(map['correctCount']),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      subjectId: _readNullableInt(map['subjectId']),
      subjectName: _readNullableString(map['subjectName']),
      examSessionId: _readNullableInt(map['examSessionId']),
      examSessionName: _readNullableString(map['examSessionName']),
      bookmarkedOnly: map['bookmarkedOnly'] == true,
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _readNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class LearningSessionRouteArguments {
  const LearningSessionRouteArguments({
    required this.qualification,
    required this.progress,
  });

  final Qualification qualification;
  final LearningSessionProgress progress;
}
