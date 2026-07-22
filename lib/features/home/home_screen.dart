import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/learning_session_progress.dart';
import '../../models/qualification.dart';
import '../learning_progress/learning_session_progress_provider.dart';
import '../learning_progress/resume_guard.dart';
import '../qualifications/qualification_provider.dart';
import '../qualifications/selected_qualification_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualifications = ref.watch(qualificationsProvider);
    final selectedQualificationId = ref.watch(selectedQualificationIdProvider);
    final learningProgress = ref.watch(learningSessionProgressProvider);

    final selectedQualification = _resolveSelectedQualification(
      qualifications,
      selectedQualificationId,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('パイロット試験対策'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(qualificationsProvider);
            await ref.read(qualificationsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _SelectedQualificationCard(
                qualifications: qualifications,
                selectedQualificationId: selectedQualificationId,
                onTap: () => context.push('/qualifications'),
              ),
              learningProgress.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (progress) {
                  if (progress == null) return const SizedBox.shrink();
                  final qualification = _findQualificationByProgress(
                    qualifications.valueOrNull ?? const <Qualification>[],
                    progress,
                  );
                  if (qualification == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ContinueLearningCard(
                      progress: progress,
                      onTap: () async {
                        await context.push(
                          '/resume-learning',
                          extra: LearningSessionRouteArguments(
                            qualification: qualification,
                            progress: progress,
                          ),
                        );
                        ref.invalidate(learningSessionProgressProvider);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                '学習メニュー',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _LearningMenuGrid(
                selectedQualification: selectedQualification,
                ref: ref,
              ),
              const SizedBox(height: 28),
              Text(
                '学習記録',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _RecordMenuRow(
                onResults: () => context.push('/results'),
                onIncorrectQuestions: () {
                  _showComingSoon(
                    context,
                    '間違えた問題は、学習履歴機能とあわせて実装します。',
                  );
                },
                onBookmarks: () => context.push('/bookmarks'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static void _showComingSoon(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SelectedQualificationCard extends StatelessWidget {
  const _SelectedQualificationCard({
    required this.qualifications,
    required this.selectedQualificationId,
    required this.onTap,
  });

  final AsyncValue<List<Qualification>> qualifications;
  final AsyncValue<int> selectedQualificationId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: qualifications.when(
            loading: () => const _QualificationLoadingView(),
            error: (error, stackTrace) => _QualificationErrorView(
              message: error.toString(),
            ),
            data: (items) {
              return selectedQualificationId.when(
                loading: () => const _QualificationLoadingView(),
                error: (error, stackTrace) => _QualificationErrorView(
                  message: error.toString(),
                ),
                data: (selectedId) {
                  final selected = _findQualification(
                    items,
                    selectedId,
                  );

                  if (selected == null) {
                    return const _QualificationErrorView(
                      message: '選択中の資格情報が見つかりません。',
                    );
                  }

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        child: Icon(
                          selected.id == defaultQualificationId
                              ? Icons.menu_book_outlined
                              : Icons.flight_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '選択中の資格',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              selected.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (selected.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                selected.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (selected.id == defaultQualificationId) ...[
                              const SizedBox(height: 8),
                              const _FreeLabel(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.expand_more),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QualificationLoadingView extends StatelessWidget {
  const _QualificationLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 14),
        Text('資格情報を読み込んでいます。'),
      ],
    );
  }
}

class _QualificationErrorView extends StatelessWidget {
  const _QualificationErrorView({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('資格情報を読み込めませんでした。'),
              const SizedBox(height: 4),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}

class _FreeLabel extends StatelessWidget {
  const _FreeLabel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 3,
        ),
        child: Text(
          '無料',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.progress,
    required this.onTap,
  });

  final LearningSessionProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: const Icon(Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '続きから学習',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.qualificationName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${progress.modeLabel}　問題 ${progress.progressLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningMenuGrid extends StatelessWidget {
  const _LearningMenuGrid({
    required this.selectedQualification,
    required this.ref,
  });

  final Qualification? selectedQualification;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuGridItem(
        icon: Icons.shuffle,
        label: 'ランダム\n一問一答',
        onTap: selectedQualification == null
            ? null
            : () async {
                if (!await confirmDiscardInterruptedMockExam(context, ref)) {
                  return;
                }
                if (!context.mounted) return;
                context.push(
                  '/qualifications/'
                  '${selectedQualification!.id}/random',
                  extra: selectedQualification,
                );
              },
      ),
      _MenuGridItem(
        icon: Icons.category_outlined,
        label: '科目別',
        onTap: () => context.push('/quick-practice'),
      ),
      _MenuGridItem(
        icon: Icons.history,
        label: '年度別\n過去問',
        onTap: () => context.push('/past-exams'),
      ),
      _MenuGridItem(
        icon: Icons.timer_outlined,
        label: '模擬試験',
        onTap: () async {
          if (!await confirmDiscardInterruptedMockExam(context, ref)) {
                  return;
                }
          if (context.mounted) context.push('/mock-exam');
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return _MenuGridCard(
          icon: item.icon,
          label: item.label,
          onTap: item.onTap,
        );
      },
    );
  }
}

class _MenuGridCard extends StatelessWidget {
  const _MenuGridCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordMenuRow extends StatelessWidget {
  const _RecordMenuRow({
    required this.onResults,
    required this.onIncorrectQuestions,
    required this.onBookmarks,
  });

  final VoidCallback onResults;
  final VoidCallback onIncorrectQuestions;
  final VoidCallback onBookmarks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RecordMenuCard(
            icon: Icons.insights_outlined,
            label: '成績',
            onTap: onResults,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RecordMenuCard(
            icon: Icons.refresh,
            label: '復習',
            onTap: onIncorrectQuestions,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RecordMenuCard(
            icon: Icons.bookmark_outline,
            label: '保存',
            onTap: onBookmarks,
          ),
        ),
      ],
    );
  }
}

class _RecordMenuCard extends StatelessWidget {
  const _RecordMenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuGridItem {
  const _MenuGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

Qualification? _resolveSelectedQualification(
  AsyncValue<List<Qualification>> qualifications,
  AsyncValue<int> selectedQualificationId,
) {
  final items = qualifications.valueOrNull;
  final selectedId = selectedQualificationId.valueOrNull;

  if (items == null || selectedId == null) {
    return null;
  }

  return _findQualification(items, selectedId);
}

Qualification? _findQualificationByProgress(
  List<Qualification> qualifications,
  LearningSessionProgress progress,
) {
  for (final qualification in qualifications) {
    if (qualification.id == progress.qualificationId ||
        qualification.code == progress.qualificationCode) {
      return qualification;
    }
  }
  return null;
}

Qualification? _findQualification(
  List<Qualification> qualifications,
  int qualificationId,
) {
  for (final qualification in qualifications) {
    if (qualification.id == qualificationId) {
      return qualification;
    }
  }

  return null;
}
