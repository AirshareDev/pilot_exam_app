import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exam_session.dart';
import '../../models/qualification.dart';
import '../questions/question_provider.dart';

final examSessionsProvider =
    FutureProvider.family<List<ExamSession>, Qualification>(
  (ref, qualification) {
    return ref.watch(questionRepositoryProvider).loadExamSessions(
          qualification,
        );
  },
);
