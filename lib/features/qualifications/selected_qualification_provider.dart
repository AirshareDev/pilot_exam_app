import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/qualification.dart';
import 'qualification_provider.dart';

const int defaultQualificationId = 1;
const String _selectedQualificationIdKey = 'selected_qualification_id';

final selectedQualificationIdProvider =
    AsyncNotifierProvider<SelectedQualificationIdNotifier, int>(
  SelectedQualificationIdNotifier.new,
);

final selectedQualificationProvider =
    FutureProvider<Qualification?>((ref) async {
  final qualificationId = await ref.watch(
    selectedQualificationIdProvider.future,
  );
  final qualifications = await ref.watch(qualificationsProvider.future);

  for (final qualification in qualifications) {
    if (qualification.id == qualificationId) {
      return qualification;
    }
  }

  return qualifications.isEmpty ? null : qualifications.first;
});

class SelectedQualificationIdNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_selectedQualificationIdKey) ??
        defaultQualificationId;
  }

  Future<void> selectQualification(int qualificationId) async {
    if (qualificationId <= 0) {
      throw ArgumentError.value(
        qualificationId,
        'qualificationId',
        'Qualification ID must be greater than zero.',
      );
    }

    final previousValue = state.valueOrNull ?? defaultQualificationId;
    state = AsyncData(qualificationId);

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setInt(
        _selectedQualificationIdKey,
        qualificationId,
      );
      if (!saved) {
        throw StateError('Failed to save the selected qualification.');
      }
    } catch (error, stackTrace) {
      state = AsyncData(previousValue);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> resetQualification() async {
    await selectQualification(defaultQualificationId);
  }
}
