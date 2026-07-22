import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/qualification.dart';
import '../../models/subject.dart';
import '../questions/question_provider.dart';

final subjectsProvider = FutureProvider.family<List<Subject>, Qualification>(
  (ref, qualification) {
    return ref.watch(questionRepositoryProvider).loadSubjects(
          qualification,
        );
  },
);
