import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/past_exams/year_selection_screen.dart';
import '../features/placeholder/feature_placeholder_screen.dart';
import '../features/qualifications/qualification_menu_screen.dart';
import '../features/qualifications/qualification_screen.dart';
import '../features/questions/random_question_screen.dart';
import '../features/subjects/subject_selection_screen.dart';
import '../models/qualification.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/qualifications',
      builder: (context, state) => const QualificationScreen(),
      routes: [
        GoRoute(
          path: ':qualificationId',
          builder: (context, state) {
            final qualification = _requireQualification(state.extra);
            if (qualification == null) {
              return const _RouteErrorScreen();
            }
            return QualificationMenuScreen(qualification: qualification);
          },
          routes: [
            GoRoute(
              path: 'random',
              builder: (context, state) {
                final qualification = _requireQualification(state.extra);
                if (qualification == null) {
                  return const _RouteErrorScreen();
                }
                return RandomQuestionScreen(
                  qualification: qualification,
                );
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/quick-practice',
      builder: (context, state) => const SubjectSelectionScreen(),
      routes: [
        GoRoute(
          path: ':qualificationId/:subjectId',
          builder: (context, state) {
            final subjectId = int.tryParse(
                  state.pathParameters['subjectId'] ?? '',
                ) ??
                0;
            final arguments = state.extra is SubjectRouteArguments
                ? state.extra! as SubjectRouteArguments
                : null;
            if (arguments == null || subjectId <= 0) {
              return const _RouteErrorScreen();
            }
            return RandomQuestionScreen(
              qualification: arguments.qualification,
              subjectId: subjectId,
              subjectName: arguments.subjectName,
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/past-exams',
      builder: (context, state) => const YearSelectionScreen(),
      routes: [
        GoRoute(
          path: ':qualificationId/:examSessionId',
          builder: (context, state) {
            final arguments = state.extra is ExamSessionRouteArguments
                ? state.extra! as ExamSessionRouteArguments
                : null;
            if (arguments == null) return const _RouteErrorScreen();
            return RandomQuestionScreen(
              qualification: arguments.qualification,
              examSessionId: arguments.session.id,
              examSessionName: arguments.session.name,
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/mock-exam',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: '模擬試験',
        description: '本試験形式の出題・制限時間・採点を実装します。',
      ),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: '成績',
        description: '回答履歴、正答率、苦手科目を表示します。',
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: '設定',
        description: 'DB情報、表示設定、購入状態などを配置します。',
      ),
    ),
  ],
);

Qualification? _requireQualification(Object? extra) {
  return extra is Qualification ? extra : null;
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('画面を開けません')), 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                '資格情報を取得できませんでした。資格選択画面から開き直してください。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/qualifications'),
                child: const Text('資格選択へ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
