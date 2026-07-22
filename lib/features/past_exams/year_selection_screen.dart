import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exam_session.dart';
import '../../models/qualification.dart';
import '../../shared/app_page.dart';
import '../qualifications/selected_qualification_provider.dart';
import '../learning_progress/resume_guard.dart';
import 'year_provider.dart';

class YearSelectionScreen extends ConsumerWidget {
  const YearSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedQualification = ref.watch(selectedQualificationProvider);

    return AppPage(
      title: '過去問',
      body: selectedQualification.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(selectedQualificationProvider),
        ),
        data: (qualification) {
          if (qualification == null) return const _EmptyQualificationView();
          return _SessionListView(qualification: qualification);
        },
      ),
    );
  }
}

class _SessionListView extends ConsumerWidget {
  const _SessionListView({required this.qualification});

  final Qualification qualification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(examSessionsProvider(qualification));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(examSessionsProvider(qualification));
        await ref.read(examSessionsProvider(qualification).future);
      },
      child: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _SessionErrorView(
          error: error,
          onRetry: () =>
              ref.invalidate(examSessionsProvider(qualification)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptySessionView(qualificationName: qualification.name);
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _QualificationHeader(qualificationName: qualification.name),
              const SizedBox(height: 16),
              Text(
                '試験期を選択',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final session in items)
                _SessionCard(
                  session: session,
                  onTap: session.questionCount <= 0
                      ? null
                      : () async {
                          if (!await confirmDiscardInterruptedMockExam(context, ref)) {
                  return;
                }
                          if (!context.mounted) return;
                          context.push(
                            '/past-exams/${qualification.id}/${session.id}',
                            extra: ExamSessionRouteArguments(
                              qualification: qualification,
                              session: session,
                            ),
                          );
                        },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QualificationHeader extends StatelessWidget {
  const _QualificationHeader({required this.qualificationName});

  final String qualificationName;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '選択中の資格',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    qualificationName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
  });

  final ExamSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.history),
        title: Text(session.displayName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${session.questionCount}問'),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class ExamSessionRouteArguments {
  const ExamSessionRouteArguments({
    required this.qualification,
    required this.session,
  });

  final Qualification qualification;
  final ExamSession session;
}

class _EmptyQualificationView extends StatelessWidget {
  const _EmptyQualificationView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              '資格が選択されていません。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/qualifications'),
              child: const Text('資格を選択する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessionView extends StatelessWidget {
  const _EmptySessionView({required this.qualificationName});

  final String qualificationName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.calendar_month_outlined, size: 48),
        const SizedBox(height: 16),
        Text(
          '$qualificationNameには、試験期が設定された問題がありません。',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SessionErrorView extends StatelessWidget {
  const _SessionErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        const Text(
          '試験期情報を読み込めませんでした。',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('再読み込み'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text(
            '資格情報を読み込めませんでした。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }
}
