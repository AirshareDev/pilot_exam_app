import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/qualification.dart';
import '../../repositories/question_repository.dart';

final qualificationsProvider = FutureProvider<List<Qualification>>((ref) {
  return ref.watch(questionRepositoryProvider).loadQualifications();
});
