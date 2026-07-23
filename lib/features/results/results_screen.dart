import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/questions_database.dart';
import '../../design/app_colors.dart';
import '../../database/user_database.dart';
import '../../models/learning_results.dart';
import '../../shared/app_page.dart';
import '../mock_exam/mock_exam_screen.dart';
import '../qualifications/selected_qualification_provider.dart';
import 'results_provider.dart';
import 'widgets/subject_radar_chart.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({this.historyOnly = false, super.key});

  final bool historyOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(learningResultsProvider);

    return AppPage(
      title: historyOnly ? '復習' : '成績',
      actions: historyOnly ? const <Widget>[] : [
        IconButton(
          tooltip: '成績をリセット',
          onPressed: results.valueOrNull?.totalAnswers == 0
              ? null
              : () => _confirmReset(context, ref),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(learningResultsProvider);
          await ref.read(learningResultsProvider.future);
        },
        child: results.when(
          loading: () => const _ScrollableCentered(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => _ScrollableCentered(
            child: _ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(learningResultsProvider),
            ),
          ),
          data: (data) {
            if (data == null) {
              return _ScrollableCentered(
                child: _NoQualificationView(
                  onSelect: () => context.push('/qualifications'),
                ),
              );
            }
            if ((!historyOnly && data.totalAnswers == 0) ||
                (historyOnly && data.examHistory.isEmpty)) {
              return _EmptyResultsView(
                qualificationName: data.qualificationName,
                onStart: () => context.pop(),
                message: historyOnly
                    ? '保存された模擬試験結果はありません。'
                    : null,
              );
            }
            return _ResultsBody(
              results: data,
              historyOnly: historyOnly,
              onOpenExam: (exam) => _openExamResult(context, ref, exam),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openExamResult(
    BuildContext context,
    WidgetRef ref,
    ExamResultHistory exam,
  ) async {
    if (exam.answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この履歴には問題別データが保存されていません。')),
      );
      return;
    }
    final qualification = await ref.read(selectedQualificationProvider.future);
    if (!context.mounted) return;
    if (qualification == null) return;
    final questionCodes = exam.answers
        .map((answer) => answer.questionCode)
        .toList(growable: false);
    final loaded = await ref.read(questionsDatabaseProvider).loadQuestionsByCodes(
          databaseFileName: qualification.databaseFileName,
          questionCodes: questionCodes,
        );
    final byCode = {for (final question in loaded) question.questionCode: question};
    final questions = [
      for (final code in questionCodes)
        if (byCode[code] != null) byCode[code]!,
    ];
    if (!context.mounted) return;
    if (questions.length != exam.answers.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('履歴の問題データを読み込めませんでした。')),
      );
      return;
    }
    final answers = <int, int>{};
    for (var i = 0; i < exam.answers.length; i++) {
      final selected = exam.answers[i].selectedChoice;
      if (selected != null) answers[i] = selected;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MockExamResultScreen(
          questions: questions,
          answers: answers,
          correct: exam.correctQuestions,
          startedAt: exam.startedAt ?? exam.completedAt ?? DateTime.now(),
          completedAt: exam.completedAt ?? DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final qualification = await ref.read(selectedQualificationProvider.future);
    if (qualification == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成績をリセットしますか？'),
        content: Text(
          '${qualification.name}の回答履歴、正答数、不正答数、模擬試験結果を削除します。ブックマークと購入状態は残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(userDatabaseProvider).resetLearningResults(
          qualificationCode: qualification.code,
        );
    ref.invalidate(learningResultsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('成績をリセットしました。')),
    );
  }
}

class _ResultsBody extends StatefulWidget {
  const _ResultsBody({
    required this.results,
    required this.historyOnly,
    required this.onOpenExam,
  });

  final LearningResults results;
  final bool historyOnly;
  final ValueChanged<ExamResultHistory> onOpenExam;

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  bool _showRecentAnswers = false;

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    final weakest = results.weakestSubject;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: AppColors.navy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  results.qualificationName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
        if (!widget.historyOnly) ...[
          const SizedBox(height: 14),
          _OverviewCard(results: results),
          if (weakest != null) ...[
            const SizedBox(height: 12),
            _WeakSubjectCard(subject: weakest),
          ],
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.radar_rounded,
            title: '科目別成績',
            subtitle: '得意・不得意を科目ごとに確認できます',
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
              child: SubjectRadarChart(subjects: results.subjects),
            ),
          ),
          const SizedBox(height: 10),
          ...results.subjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SubjectCard(subject: subject),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _SectionTitle(
          icon: Icons.history_rounded,
          title: '模擬試験履歴',
          subtitle: widget.historyOnly
              ? '結果を開いて、間違えた問題を復習できます'
              : 'これまでの受験結果を確認できます',
        ),
        const SizedBox(height: 10),
        if (results.examHistory.isEmpty)
          const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('保存された模擬試験結果はありません。'),
            ),
          )
        else
          ...results.examHistory.map(
            (exam) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExamHistoryCard(
                exam: exam,
                onTap: () => widget.onOpenExam(exam),
              ),
            ),
          ),
        if (!widget.historyOnly) ...[
          const SizedBox(height: 14),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fact_check_outlined, color: AppColors.navy),
                  ),
                  title: Text(
                    '最近の回答',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  subtitle: Text('直近${results.recentAnswers.length}問'),
                  trailing: Icon(
                    _showRecentAnswers
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  onTap: () => setState(
                    () => _showRecentAnswers = !_showRecentAnswers,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: _showRecentAnswers
                      ? Column(
                          children: [
                            const Divider(height: 1),
                            for (var i = 0;
                                i < results.recentAnswers.length;
                                i++) ...[
                              _RecentAnswerTile(answer: results.recentAnswers[i]),
                              if (i != results.recentAnswers.length - 1)
                                const Divider(height: 1, indent: 70),
                            ],
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.navy, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.results});

  final LearningResults results;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: results.accuracy,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.blue.withValues(alpha: 0.10),
                      color: AppColors.blue,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _percent(results.accuracy),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '総合正答率',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _Metric(label: '回答', value: '${results.totalAnswers}回')),
                      Expanded(child: _Metric(label: '正解', value: '${results.correctAnswers}回', color: AppColors.green)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Metric(label: '不正解', value: '${results.wrongAnswers}回', color: AppColors.red)),
                      Expanded(child: _Metric(label: '学習問題', value: '${results.answeredQuestions}問')),
                    ],
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? AppColors.navy,
              ),
        ),
      ],
    );
  }
}

class _WeakSubjectCard extends StatelessWidget {
  const _WeakSubjectCard({required this.subject});

  final SubjectLearningResult subject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.orange.withValues(alpha: 0.07),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.refresh_rounded, color: AppColors.orange),
        ),
        title: const Text('優先して復習したい科目'),
        subtitle: Text(subject.subjectName),
        trailing: Text(
          _percent(subject.accuracy),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final SubjectLearningResult subject;

  @override
  Widget build(BuildContext context) {
    final color = subject.accuracy >= 0.8
        ? AppColors.green
        : subject.accuracy >= 0.6
            ? AppColors.blue
            : AppColors.orange;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject.subjectName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  _percent(subject.accuracy),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: subject.accuracy,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.10),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${subject.totalAnswers}回回答　正解 ${subject.correctAnswers}回　不正解 ${subject.wrongAnswers}回',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamHistoryCard extends StatelessWidget {
  const _ExamHistoryCard({required this.exam, required this.onTap});

  final ExamResultHistory exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rateColor = exam.accuracy >= 0.8
        ? AppColors.green
        : exam.accuracy >= 0.6
            ? AppColors.orange
            : AppColors.red;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: exam.answers.isEmpty ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rateColor.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _percent(exam.accuracy),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: rateColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(exam.completedAt),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${exam.correctQuestions} / ${exam.totalQuestions}問 正解',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (exam.answers.isEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '問題別データなし',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (exam.answers.isNotEmpty)
                const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAnswerTile extends StatelessWidget {
  const _RecentAnswerTile({required this.answer});

  final RecentAnswerResult answer;

  @override
  Widget build(BuildContext context) {
    final color = answer.isCorrect ? AppColors.green : AppColors.red;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          answer.isCorrect ? Icons.check_rounded : Icons.close_rounded,
          color: color,
        ),
      ),
      title: Text(
        answer.questionLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${answer.subjectName}　${_formatDateTime(answer.answeredAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          answer.isCorrect ? '正解' : '不正解',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _EmptyResultsView extends StatelessWidget {
  const _EmptyResultsView({
    required this.qualificationName,
    required this.onStart,
    this.message,
  });

  final String qualificationName;
  final VoidCallback onStart;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.bar_chart_outlined, size: 64),
        const SizedBox(height: 20),
        Text(
          message ?? 'まだ回答履歴がありません',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          message == null
              ? '$qualificationNameの問題を解くと、総合正答率や科目別成績が表示されます。'
              : '模擬試験を採点すると、ここから結果確認と間違えた問題の復習ができます。',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onStart, child: const Text('学習メニューへ戻る')),
      ],
    );
  }
}

class _NoQualificationView extends StatelessWidget {
  const _NoQualificationView({required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.school_outlined, size: 56),
        const SizedBox(height: 16),
        const Text('資格が選択されていません。'),
        const SizedBox(height: 16),
        FilledButton(onPressed: onSelect, child: const Text('資格を選択する')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 56),
        const SizedBox(height: 16),
        const Text('成績を読み込めませんでした。'),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
      ],
    );
  }
}

class _ScrollableCentered extends StatelessWidget {
  const _ScrollableCentered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _percent(double value) => '${(value * 100).round()}%';

String _formatDateTime(DateTime? value) {
  if (value == null) return '日時不明';
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
