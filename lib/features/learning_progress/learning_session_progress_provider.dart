import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/learning_session_progress.dart';

const _learningSessionProgressKey = 'learning_session_progress_v1';

final learningSessionProgressStoreProvider =
    Provider<LearningSessionProgressStore>((ref) {
  return const LearningSessionProgressStore();
});

final learningSessionProgressProvider =
    FutureProvider<LearningSessionProgress?>((ref) async {
  return ref.watch(learningSessionProgressStoreProvider).load();
});

class LearningSessionProgressStore {
  const LearningSessionProgressStore();

  Future<LearningSessionProgress?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_learningSessionProgressKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final progress = LearningSessionProgress.fromJson(raw);
      if (!progress.canResume) {
        await clear();
        return null;
      }
      return progress;
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> save(LearningSessionProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _learningSessionProgressKey,
      progress.toJson(),
    );
    if (!saved) {
      throw StateError('学習再開情報を保存できませんでした。');
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_learningSessionProgressKey);
  }
}
