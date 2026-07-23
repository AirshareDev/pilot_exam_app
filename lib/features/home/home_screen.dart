import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_app_bar.dart';
import '../../design/app_card.dart';
import '../../design/app_colors.dart';
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
        title: const Text('航空従事者技能証明試験ー学科試験対策'),
        flexibleSpace: const AppBarBackground(),
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            children: [
              _SelectedQualificationCard(
                qualifications: qualifications,
                selectedQualificationId: selectedQualificationId,
                onTap: () => context.push('/qualifications'),
              ),
              learningProgress.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (progress) {
                  if (progress == null) return const SizedBox.shrink();
                  final qualification = _findQualificationByProgress(
                    qualifications.valueOrNull ?? const <Qualification>[],
                    progress,
                  );
                  if (qualification == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
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
              const SizedBox(height: 28),
              const _SectionTitle(
                title: '学習メニュー',
                subtitle: '学習方法を選択してください',
              ),
              const SizedBox(height: 14),
              _LearningMenuGrid(
                selectedQualification: selectedQualification,
                ref: ref,
              ),
              const SizedBox(height: 30),
              const _SectionTitle(
                title: '学習記録',
                subtitle: '成績や復習対象を確認できます',
              ),
              const SizedBox(height: 14),
              _RecordMenuRow(
                onResults: () => context.push('/results'),
                onIncorrectQuestions: () => context.push('/review'),
                onBookmarks: () => context.push('/bookmarks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      );
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
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123D73), Color(0xFF1D5799)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: qualifications.when(
          loading: () => const _QualificationLoadingView(),
          error: (error, _) => _QualificationErrorView(message: error.toString()),
          data: (items) => selectedQualificationId.when(
            loading: () => const _QualificationLoadingView(),
            error: (error, _) => _QualificationErrorView(message: error.toString()),
            data: (selectedId) {
              final selected = _findQualification(items, selectedId);
              if (selected == null) {
                return const _QualificationErrorView(
                  message: '選択中の資格情報が見つかりません。',
                );
              }
              return Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '選択中の資格',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selected.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (selected.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            selected.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
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
  Widget build(BuildContext context) => const Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 14),
          Text('資格情報を読み込んでいます。', style: TextStyle(color: Colors.white)),
        ],
      );
}

class _QualificationErrorView extends StatelessWidget {
  const _QualificationErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      );
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.progress, required this.onTap});
  final LearningSessionProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.green, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('続きから学習', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(progress.qualificationName, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${progress.modeLabel}　問題 ${progress.progressLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      );
}

class _LearningMenuGrid extends StatelessWidget {
  const _LearningMenuGrid({required this.selectedQualification, required this.ref});
  final Qualification? selectedQualification;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuGridItem(
        icon: Icons.shuffle_rounded,
        label: 'ランダム一問一答',
        description: '全問題からランダム出題',
        color: AppColors.blue,
        onTap: selectedQualification == null
            ? null
            : () async {
                if (!await confirmDiscardInterruptedMockExam(context, ref)) return;
                if (!context.mounted) return;
                context.push(
                  '/qualifications/${selectedQualification!.id}/random',
                  extra: selectedQualification,
                );
              },
      ),
      _MenuGridItem(
        icon: Icons.category_outlined,
        label: '科目別',
        description: '苦手科目を集中学習',
        color: AppColors.orange,
        onTap: () => context.push('/quick-practice'),
      ),
      _MenuGridItem(
        icon: Icons.calendar_month_outlined,
        label: '年度別過去問',
        description: '年度・期ごとに演習',
        color: AppColors.purple,
        onTap: () => context.push('/past-exams'),
      ),
      _MenuGridItem(
        icon: Icons.timer_outlined,
        label: '模擬試験',
        description: '本番形式で実力確認',
        color: AppColors.red,
        onTap: () async {
          if (!await confirmDiscardInterruptedMockExam(context, ref)) return;
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
        childAspectRatio: 1.42,
      ),
      itemBuilder: (context, index) => _MenuGridCard(item: items[index]),
    );
  }
}

class _MenuGridCard extends StatelessWidget {
  const _MenuGridCard({required this.item});
  final _MenuGridItem item;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onTap != null;
    return Card(
      margin: EdgeInsets.zero,
      color: item.color.withValues(alpha: 0.085),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: item.color.withValues(alpha: 0.34)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: item.color, size: 30),
                const SizedBox(height: 7),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: item.color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _RecordMenuCard(icon: Icons.insights_outlined, label: '成績', color: AppColors.blue, onTap: onResults)),
          const SizedBox(width: 10),
          Expanded(child: _RecordMenuCard(icon: Icons.replay_rounded, label: '復習', color: AppColors.orange, onTap: onIncorrectQuestions)),
          const SizedBox(width: 10),
          Expanded(child: _RecordMenuCard(icon: Icons.bookmark_outline_rounded, label: '保存', color: AppColors.teal, onTap: onBookmarks)),
        ],
      );
}

class _RecordMenuCard extends StatelessWidget {
  const _RecordMenuCard({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        color: color.withValues(alpha: 0.085),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.30)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 23, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MenuGridItem {
  const _MenuGridItem({required this.icon, required this.label, required this.description, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback? onTap;
}

Qualification? _resolveSelectedQualification(AsyncValue<List<Qualification>> qualifications, AsyncValue<int> selectedQualificationId) {
  final items = qualifications.valueOrNull;
  final selectedId = selectedQualificationId.valueOrNull;
  if (items == null || selectedId == null) return null;
  return _findQualification(items, selectedId);
}

Qualification? _findQualificationByProgress(List<Qualification> qualifications, LearningSessionProgress progress) {
  for (final qualification in qualifications) {
    if (qualification.id == progress.qualificationId || qualification.code == progress.qualificationCode) return qualification;
  }
  return null;
}

Qualification? _findQualification(List<Qualification> qualifications, int qualificationId) {
  for (final qualification in qualifications) {
    if (qualification.id == qualificationId) return qualification;
  }
  return null;
}
