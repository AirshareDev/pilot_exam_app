import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/user_database.dart';

class AppSettings {
  const AppSettings({
    this.advanceAfterCorrect = false,
    this.advanceAfterMockAnswer = false,
    this.defaultMockQuestionCount = 100,
    this.defaultMockDurationMinutes = 60,
    this.defaultMockRandom = true,
    this.textScale = 0.9,
  });

  final bool advanceAfterCorrect;
  final bool advanceAfterMockAnswer;
  final int defaultMockQuestionCount;
  final int defaultMockDurationMinutes;
  final bool defaultMockRandom;
  final double textScale;

  AppSettings copyWith({
    bool? advanceAfterCorrect,
    bool? advanceAfterMockAnswer,
    int? defaultMockQuestionCount,
    int? defaultMockDurationMinutes,
    bool? defaultMockRandom,
    double? textScale,
  }) {
    return AppSettings(
      advanceAfterCorrect: advanceAfterCorrect ?? this.advanceAfterCorrect,
      advanceAfterMockAnswer:
          advanceAfterMockAnswer ?? this.advanceAfterMockAnswer,
      defaultMockQuestionCount:
          defaultMockQuestionCount ?? this.defaultMockQuestionCount,
      defaultMockDurationMinutes:
          defaultMockDurationMinutes ?? this.defaultMockDurationMinutes,
      defaultMockRandom: defaultMockRandom ?? this.defaultMockRandom,
      textScale: textScale ?? this.textScale,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  return AppSettingsController(ref.watch(userDatabaseProvider));
});

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._database) : super(const AppSettings()) {
    _load();
  }

  final UserDatabase _database;

  Future<void> _load() async {
    final values = await _database.loadAppSettings();
    state = AppSettings(
      advanceAfterCorrect: values['advance_after_correct'] == '1',
      advanceAfterMockAnswer: values['advance_after_mock_answer'] == '1',
      defaultMockQuestionCount:
          int.tryParse(values['default_mock_question_count'] ?? '') ?? 100,
      defaultMockDurationMinutes:
          int.tryParse(values['default_mock_duration_minutes'] ?? '') ?? 60,
      defaultMockRandom: values['default_mock_random'] != '0',
      textScale: double.tryParse(values['text_scale'] ?? '') ?? 0.9,
    );
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await _database.saveAppSettings({
      'advance_after_correct': next.advanceAfterCorrect ? '1' : '0',
      'advance_after_mock_answer': next.advanceAfterMockAnswer ? '1' : '0',
      'default_mock_question_count':
          next.defaultMockQuestionCount.toString(),
      'default_mock_duration_minutes':
          next.defaultMockDurationMinutes.toString(),
      'default_mock_random': next.defaultMockRandom ? '1' : '0',
      'text_scale': next.textScale.toString(),
    });
  }

}
