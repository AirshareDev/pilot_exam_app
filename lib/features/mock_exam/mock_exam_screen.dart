import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../database/questions_database.dart';
import '../../database/user_database.dart';
import '../../models/question.dart';
import '../qualifications/selected_qualification_provider.dart';
import '../results/results_provider.dart';

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key});

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  static const int _questionLimit = 20;
  static const Duration _examDuration = Duration(minutes: 60);

  Timer? _timer;
  Duration _remaining = _examDuration;
  DateTime? _startedAt;
  List<Question>? _questions;
  final Map<int, int> _answers = <int, int>{};
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadQuestions);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final qualification = await ref.read(selectedQualificationProvider.future);
      if (qualification == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '資格が選択されていません。';
        });
        return;
      }

      final questions = await ref
          .read(questionsDatabaseProvider)
          .loadRandomQuestions(
            databaseFileName: qualification.databaseFileName,
            limit: _questionLimit,
          );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
        _startedAt = DateTime.now();
      });
      if (questions.isNotEmpty) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (_remaining.inSeconds <= 1) {
            _timer?.cancel();
            setState(() => _remaining = Duration.zero);
            _submit(force: true);
          } else {
            setState(() => _remaining -= const Duration(seconds: 1));
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _submit({bool force = false}) async {
    if (_submitting) return;
    final questions = _questions;
    if (questions == null || questions.isEmpty) return;

    if (!force && _answers.length < questions.length) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('未回答の問題があります'),
          content: Text(
            '${questions.length - _answers.length}問が未回答です。このまま採点しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('採点する'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      final qualification = await ref.read(selectedQualificationProvider.future);
      if (qualification == null) {
        throw StateError('資格が選択されていません。');
      }

      var correct = 0;
      final userDatabase = ref.read(userDatabaseProvider);
      for (var i = 0; i < questions.length; i++) {
        final selected = _answers[i];
        if (selected == null) continue;
        final isCorrect = questions[i].isCorrectChoice(selected);
        if (isCorrect) correct++;
        await userDatabase.recordAnswer(
          qualificationCode: qualification.code,
          questionCode: questions[i].questionCode,
          selectedChoice: selected,
          isCorrect: isCorrect,
        );
      }

      await userDatabase.recordExamResult(
        qualificationCode: qualification.code,
        startedAt: _startedAt ?? DateTime.now(),
        completedAt: DateTime.now(),
        totalQuestions: questions.length,
        correctQuestions: correct,
        passingScorePercent: 70,
      );
      ref.invalidate(learningResultsProvider);

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _MockExamResultScreen(
            questions: questions,
            answers: Map<int, int>.unmodifiable(_answers),
            correct: correct,
          ),
        ),
      );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('採点結果を保存できませんでした: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模擬試験'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _formatDuration(_remaining),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/qualifications'),
                child: const Text('資格を選択する'),
              ),
            ],
          ),
        ),
      );
    }

    final questions = _questions ?? const <Question>[];
    if (questions.isEmpty) {
      return const Center(child: Text('模擬試験に使用できる問題がありません。'));
    }

    final question = questions[_currentIndex];
    final selected = _answers[_currentIndex];

    return Column(
      children: [
        LinearProgressIndicator(value: (_currentIndex + 1) / questions.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Row(
                children: [
                  Text(
                    '問題 ${_currentIndex + 1} / ${questions.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text('回答済み ${_answers.length}問'),
                ],
              ),
              if (question.metadataText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  question.metadataText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    question.questionText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          height: 1.5,
                        ),
                  ),
                ),
              ),
              if (question.imagePath != null &&
                  question.imagePath!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Image.asset(
                  question.imagePath!,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: 16),
              for (var i = 0; i < question.choices.length; i++)
                _MockExamChoiceCard(
                  number: i + 1,
                  text: question.choices[i],
                  isSelected: selected == i + 1,
                  enabled: !_submitting,
                  onTap: () {
                    if (_submitting) return;
                    setState(() => _answers[_currentIndex] = i + 1);
                  },
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex == 0 || _submitting
                        ? null
                        : () => setState(() => _currentIndex--),
                    child: const Text('前へ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _currentIndex == questions.length - 1
                      ? FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting ? '採点中…' : '採点する'),
                        )
                      : FilledButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _currentIndex++),
                          child: const Text('次へ'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MockExamChoiceCard extends StatelessWidget {
  const _MockExamChoiceCard({
    required this.number,
    required this.text,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? colorScheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? colorScheme.secondary
              : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                child: Text('$number'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, color: colorScheme.secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MockExamResultScreen extends StatelessWidget {
  const _MockExamResultScreen({
    required this.questions,
    required this.answers,
    required this.correct,
  });

  final List<Question> questions;
  final Map<int, int> answers;
  final int correct;

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    final score = total == 0 ? 0.0 : correct / total * 100;
    final passed = score >= 70;
    final wrongIndexes = <int>[
      for (var i = 0; i < questions.length; i++)
        if (answers[i] == null || !questions[i].isCorrectChoice(answers[i]!)) i,
    ];
    final subjectResults = _buildSubjectResults(questions, answers);

    return Scaffold(
      appBar: AppBar(title: const Text('模擬試験結果')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    passed ? Icons.verified_outlined : Icons.refresh_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? '合格基準達成' : '復習が必要です',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text('$total問中 $correct問正解'),
                ],
              ),
            ),
          ),
          if (wrongIndexes.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _WrongAnswerReviewScreen(
                      questions: [for (final i in wrongIndexes) questions[i]],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.replay),
              label: Text('間違えた問題だけ復習（${wrongIndexes.length}問）'),
            ),
          ],
          const SizedBox(height: 24),
          Text('科目別成績', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < subjectResults.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(subjectResults[i].name),
                    subtitle: Text(
                      '${subjectResults[i].total}問中 ${subjectResults[i].correct}問正解',
                    ),
                    trailing: Text(
                      '${subjectResults[i].percentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('回答一覧', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '問題をタップすると、問題文・解説を確認できます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < questions.length; i++)
            _ResultQuestionTile(
              index: i,
              question: questions[i],
              selectedChoice: answers[i],
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _MockExamQuestionDetailScreen(
                      question: questions[i],
                      questionNumber: i + 1,
                      selectedChoice: answers[i],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('学習メニューへ戻る'),
          ),
        ],
      ),
    );
  }
}

class _ResultQuestionTile extends StatelessWidget {
  const _ResultQuestionTile({
    required this.index,
    required this.question,
    required this.selectedChoice,
    required this.onTap,
  });

  final int index;
  final Question question;
  final int? selectedChoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCorrect = selectedChoice != null &&
        question.isCorrectChoice(selectedChoice!);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isCorrect ? Icons.check_circle : Icons.cancel,
          color: isCorrect ? colorScheme.primary : colorScheme.error,
        ),
        title: Text('問題 ${index + 1}　${isCorrect ? '正解' : '不正解'}'),
        subtitle: Text(
          'あなたの回答：${_answerLabel(question, selectedChoice)}\n'
          '正解：${_correctAnswerLabel(question)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _MockExamQuestionDetailScreen extends StatelessWidget {
  const _MockExamQuestionDetailScreen({
    required this.question,
    required this.questionNumber,
    required this.selectedChoice,
  });

  final Question question;
  final int questionNumber;
  final int? selectedChoice;

  @override
  Widget build(BuildContext context) {
    final isCorrect = selectedChoice != null &&
        question.isCorrectChoice(selectedChoice!);

    return Scaffold(
      appBar: AppBar(title: Text('問題 $questionNumber')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (question.metadataText.isNotEmpty) ...[
            Text(
              question.metadataText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                question.questionText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.5,
                    ),
              ),
            ),
          ),
          if (question.imagePath != null && question.imagePath!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Image.asset(
              question.imagePath!,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < question.choices.length; i++)
            _ReviewChoiceCard(
              number: i + 1,
              text: question.choices[i],
              isSelected: selectedChoice == i + 1,
              isCorrect: question.isCorrectChoice(i + 1),
            ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(isCorrect ? Icons.check_circle : Icons.cancel),
                      const SizedBox(width: 8),
                      Text(
                        isCorrect ? '正解です' : '不正解です',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('あなたの回答：${_answerLabel(question, selectedChoice)}'),
                  const SizedBox(height: 4),
                  Text('正解：${_correctAnswerLabel(question)}'),
                  if (question.explanation.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('解説', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      question.explanation,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                  if (question.reference != null &&
                      question.reference!.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('参考', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(question.reference!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewChoiceCard extends StatelessWidget {
  const _ReviewChoiceCard({
    required this.number,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
  });

  final int number;
  final String text;
  final bool isSelected;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? backgroundColor;
    Color borderColor = colorScheme.outlineVariant;
    IconData? icon;

    if (isCorrect) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      icon = Icons.check_circle;
    } else if (isSelected) {
      backgroundColor = colorScheme.errorContainer;
      borderColor = colorScheme.error;
      icon = Icons.cancel;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: isCorrect || isSelected ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 18, child: Text('$number')),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon),
            ],
          ],
        ),
      ),
    );
  }
}

class _WrongAnswerReviewScreen extends StatefulWidget {
  const _WrongAnswerReviewScreen({required this.questions});

  final List<Question> questions;

  @override
  State<_WrongAnswerReviewScreen> createState() =>
      _WrongAnswerReviewScreenState();
}

class _WrongAnswerReviewScreenState extends State<_WrongAnswerReviewScreen> {
  int _index = 0;
  int? _selectedChoice;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    final isCorrect = _selectedChoice != null &&
        question.isCorrectChoice(_selectedChoice!);

    return Scaffold(
      appBar: AppBar(title: const Text('間違えた問題の復習')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_index + 1) / widget.questions.length),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '問題 ${_index + 1} / ${widget.questions.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      question.questionText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                            height: 1.5,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < question.choices.length; i++)
                  _ReviewPracticeChoiceCard(
                    number: i + 1,
                    text: question.choices[i],
                    isSelected: _selectedChoice == i + 1,
                    isAnswered: _answered,
                    isCorrect: question.isCorrectChoice(i + 1),
                    onTap: () {
                      if (_answered) return;
                      setState(() {
                        _selectedChoice = i + 1;
                        _answered = true;
                      });
                    },
                  ),
                if (_answered) ...[
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isCorrect ? '正解です' : '不正解です',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('正解：${_correctAnswerLabel(question)}'),
                          if (question.explanation.isNotEmpty) ...[
                            const Divider(height: 22),
                            Text(
                              '解説',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              question.explanation,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: !_answered
                      ? null
                      : () {
                          if (_index == widget.questions.length - 1) {
                            Navigator.pop(context);
                            return;
                          }
                          setState(() {
                            _index++;
                            _selectedChoice = null;
                            _answered = false;
                          });
                        },
                  child: Text(
                    _index == widget.questions.length - 1 ? '復習を終了' : '次の問題',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPracticeChoiceCard extends StatelessWidget {
  const _ReviewPracticeChoiceCard({
    required this.number,
    required this.text,
    required this.isSelected,
    required this.isAnswered,
    required this.isCorrect,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool isSelected;
  final bool isAnswered;
  final bool isCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? backgroundColor;
    Color borderColor = colorScheme.outlineVariant;
    IconData? icon;

    if (isAnswered && isCorrect) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      icon = Icons.check_circle;
    } else if (isAnswered && isSelected) {
      backgroundColor = colorScheme.errorContainer;
      borderColor = colorScheme.error;
      icon = Icons.cancel;
    } else if (isSelected) {
      backgroundColor = colorScheme.secondaryContainer;
      borderColor = colorScheme.secondary;
      icon = Icons.check;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: isSelected || isCorrect ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAnswered ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(radius: 18, child: Text('$number')),
              const SizedBox(width: 14),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectResult {
  const _SubjectResult({
    required this.name,
    required this.total,
    required this.correct,
  });

  final String name;
  final int total;
  final int correct;

  double get percentage => total == 0 ? 0 : correct / total * 100;
}

List<_SubjectResult> _buildSubjectResults(
  List<Question> questions,
  Map<int, int> answers,
) {
  final totals = <String, int>{};
  final corrects = <String, int>{};

  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final name = (question.subjectName == null || question.subjectName!.isEmpty)
        ? '科目未設定'
        : question.subjectName!;
    totals[name] = (totals[name] ?? 0) + 1;
    final selected = answers[i];
    if (selected != null && question.isCorrectChoice(selected)) {
      corrects[name] = (corrects[name] ?? 0) + 1;
    }
  }

  return [
    for (final entry in totals.entries)
      _SubjectResult(
        name: entry.key,
        total: entry.value,
        correct: corrects[entry.key] ?? 0,
      ),
  ];
}

String _answerLabel(Question question, int? choice) {
  if (choice == null) return '未回答';
  if (choice < 1 || choice > question.choices.length) return '$choice';
  return '$choice. ${question.choices[choice - 1]}';
}

String _correctAnswerLabel(Question question) {
  if (question.isAllCorrect) return 'すべての選択肢';
  final choice = question.correctChoice;
  if (choice == null) return '未設定';
  return _answerLabel(question, choice);
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
