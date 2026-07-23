import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/user_database.dart';
import '../../models/learning_results.dart';
import '../../shared/app_page.dart';
import '../qualifications/selected_qualification_provider.dart';
import 'results_provider.dart';
import 'widgets/subject_radar_chart.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(learningResultsProvider);

    return AppPage(
      title: '成績',
      actions: [
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
            if (data.totalAnswers == 0) {
              return _EmptyResultsView(
                qualificationName: data.qualificationName,
                onStart: () => context.pop(),
              );
            }
            return _ResultsBody(results: data);
          },
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
  const _ResultsBody({required this.results});

  final LearningResults results;

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
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          results.qualificationName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _OverviewCard(results: results),
        if (weakest != null) ...[
          const SizedBox(height: 12),
          _WeakSubjectCard(subject: weakest),
        ],
        const SizedBox(height: 24),
        Text('科目別成績', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
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
        Text('模擬試験履歴', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (results.examHistory.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('保存された模擬試験結果はありません。'),
            ),
          )
        else
          ...results.examHistory.map(
            (exam) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExamHistoryCard(exam: exam),
            ),
          ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  '最近の回答',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text('直近${results.recentAnswers.length}問'),
                trailing: Icon(
                  _showRecentAnswers
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
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
                            _RecentAnswerTile(
                              answer: results.recentAnswers[i],
                            ),
                            if (i != results.recentAnswers.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('総合正答率', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              _percent(results.accuracy),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: results.accuracy),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _Metric(label: '回答', value: '${results.totalAnswers}回')),
                Expanded(child: _Metric(label: '正解', value: '${results.correctAnswers}回')),
                Expanded(child: _Metric(label: '不正解', value: '${results.wrongAnswers}回')),
                Expanded(child: _Metric(label: '学習問題', value: '${results.answeredQuestions}問')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

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
      child: ListTile(
        leading: const Icon(Icons.trending_down),
        title: const Text('復習候補'),
        subtitle: Text('${subject.subjectName}・正答率 ${_percent(subject.accuracy)}'),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final SubjectLearningResult subject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(subject.subjectName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(
                  _percent(subject.accuracy),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: subject.accuracy),
            const SizedBox(height: 8),
            Text(
              '${subject.totalAnswers}回回答　正解 ${subject.correctAnswers}回　不正解 ${subject.wrongAnswers}回',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamHistoryCard extends StatelessWidget {
  const _ExamHistoryCard({required this.exam});

  final ExamResultHistory exam;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDateTime(exam.completedAt),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  _percent(exam.accuracy),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '合計 ${exam.correctQuestions} / ${exam.totalQuestions}問',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (exam.subjects.isNotEmpty) ...[
              const Divider(height: 24),
              for (final subject in exam.subjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(subject.subjectName)),
                      Text(
                        '正解 ${subject.correctQuestions}　不正解 ${subject.wrongQuestions}',
                      ),
                    ],
                  ),
                ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                '科目別内訳は、この更新後に実施した試験から表示されます。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
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
    return ListTile(
      leading: Icon(
        answer.isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
      ),
      title: Text(answer.questionLabel),
      subtitle: Text('${answer.subjectName}　${_formatDateTime(answer.answeredAt)}'),
      trailing: Text(answer.isCorrect ? '正解' : '不正解'),
    );
  }
}

class _EmptyResultsView extends StatelessWidget {
  const _EmptyResultsView({required this.qualificationName, required this.onStart});

  final String qualificationName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.bar_chart_outlined, size: 64),
        const SizedBox(height: 20),
        Text('まだ回答履歴がありません',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(
          '$qualificationNameの問題を解くと、総合正答率や科目別成績が表示されます。',
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
