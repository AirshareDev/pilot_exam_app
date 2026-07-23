import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_app_bar.dart';
import '../../database/questions_database.dart';
import '../../design/app_colors.dart';
import '../../database/user_database.dart';
import '../../models/exam_session.dart';
import '../../models/learning_results.dart';
import '../../models/learning_session_progress.dart';
import '../../models/qualification.dart';
import '../../models/question.dart';
import '../../models/subject.dart';
import '../../repositories/question_repository.dart';
import '../learning_progress/learning_session_progress_provider.dart';
import '../learning_progress/resume_guard.dart';
import '../qualifications/selected_qualification_provider.dart';
import '../questions/widgets/choice_card.dart';
import '../results/results_provider.dart';
import '../settings/app_settings_provider.dart';

enum _MockExamMode { exam, practice }
enum _MockExamQuestionSource { random, examSession }
enum _MockExamStage { modeSelection, subjectOverview, subjectIntro, answering }

class MockExamConfig {
  const MockExamConfig._();

  static const int subjectCount = 5;
  static const List<int> questionCountOptions = <int>[20, 50, 100];
  static const List<int> durationMinutesOptions = <int>[15, 30, 45, 60];
  static const Duration examDuration = Duration(minutes: 60);
}

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({
    this.qualification,
    this.resumeProgress,
    super.key,
  });

  final Qualification? qualification;
  final LearningSessionProgress? resumeProgress;

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  Timer? _timer;
  Timer? _autoAdvanceTimer;
  Duration _remaining = MockExamConfig.examDuration;
  DateTime? _startedAt;
  List<Subject> _subjects = const <Subject>[];
  List<ExamSession> _examSessions = const <ExamSession>[];
  List<Question>? _questions;
  final Map<int, int> _answers = <int, int>{};
  final Map<int, int> _subjectQuestionCounts = <int, int>{};
  final ScrollController _questionScrollController = ScrollController();
  int _currentIndex = 0;
  _MockExamMode? _mode;
  _MockExamQuestionSource _questionSource = _MockExamQuestionSource.random;
  int _selectedQuestionCount = 50;
  int _selectedDurationMinutes = 60;
  int? _selectedExamSessionId;
  _MockExamStage _stage = _MockExamStage.modeSelection;
  bool _loading = false;
  bool _submitting = false;
  bool _savingProgress = false;
  bool _ownsSavedProgress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _selectedQuestionCount = settings.defaultMockQuestionCount;
    _selectedDurationMinutes = settings.defaultMockDurationMinutes;
    _questionSource = settings.defaultMockRandom
        ? _MockExamQuestionSource.random
        : _MockExamQuestionSource.examSession;
    _remaining = Duration(minutes: _selectedDurationMinutes);
    final progress = widget.resumeProgress;
    if (progress != null && progress.mode == 'mockPractice') {
      _resumePractice(progress);
    } else {
      _loadSelectionData();
    }
  }

  Future<Qualification?> _resolveQualification() async {
    final supplied = widget.qualification;
    if (supplied != null) return supplied;
    return ref.read(selectedQualificationProvider.future);
  }

  Future<void> _resumePractice(LearningSessionProgress progress) async {
    setState(() {
      _mode = _MockExamMode.practice;
      _stage = _MockExamStage.answering;
      _loading = true;
      _error = null;
      _startedAt = progress.updatedAt;
      _currentIndex = progress.nextIndex;
      _answers
        ..clear()
        ..addAll(progress.answers);
      _ownsSavedProgress = true;
    });

    try {
      final qualification = await _resolveQualification();
      if (qualification == null) {
        throw StateError('資格が選択されていません。');
      }
      final database = ref.read(questionsDatabaseProvider);
      final subjects = await database.loadSubjects(
        databaseFileName: qualification.databaseFileName,
      );
      final repository = ref.read(questionRepositoryProvider);
      final questions = await repository.loadQuestionsByCodes(
        qualification: qualification,
        questionCodes: progress.questionCodes,
      );
      if (questions.isEmpty) {
        throw StateError('中断した模擬試験の問題を読み込めませんでした。');
      }

      final activeSubjectIds = questions
          .map((question) => question.subjectId)
          .whereType<int>()
          .toSet();
      final activeSubjects = subjects
          .where((subject) => activeSubjectIds.contains(subject.id))
          .toList(growable: false);
      final counts = <int, int>{};
      for (final question in questions) {
        final subjectId = question.subjectId;
        if (subjectId != null) {
          counts[subjectId] = (counts[subjectId] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _subjects = activeSubjects;
        _questions = questions;
        _subjectQuestionCounts
          ..clear()
          ..addAll(counts);
        if (_currentIndex < 0 || _currentIndex >= questions.length) {
          _currentIndex = 0;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadSelectionData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qualification = await _resolveQualification();
      if (qualification == null) {
        throw StateError('資格が選択されていません。');
      }
      final database = ref.read(questionsDatabaseProvider);
      final sessions = await database.loadExamSessions(
        databaseFileName: qualification.databaseFileName,
      );
      if (!mounted) return;
      setState(() {
        _examSessions = sessions.where((session) => session.questionCount > 0).toList(growable: false);
        _selectedExamSessionId = _examSessions.isEmpty ? null : _examSessions.first.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectMode(_MockExamMode mode) async {
    if (!await confirmDiscardInterruptedMockExam(context, ref)) return;
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _mode = mode;
      _stage = _MockExamStage.subjectOverview;
      _remaining = Duration(minutes: _selectedDurationMinutes);
      _startedAt = null;
      _subjects = const <Subject>[];
      _questions = null;
      _answers.clear();
      _subjectQuestionCounts.clear();
      _currentIndex = 0;
      _loading = true;
      _submitting = false;
      _error = null;
    });
    await _loadSubjects();
    if (!mounted || _error != null || _subjects.isEmpty) return;
    await _startExam();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoAdvanceTimer?.cancel();
    _questionScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final qualification = await _resolveQualification();
      if (qualification == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '資格が選択されていません。';
        });
        return;
      }

      final database = ref.read(questionsDatabaseProvider);
      final subjects = await database.loadSubjects(
        databaseFileName: qualification.databaseFileName,
      );
      final activeSubjects = subjects
          .where((subject) => subject.questionCount > 0)
          .take(MockExamConfig.subjectCount)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _subjects = activeSubjects;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<List<Question>> _loadConfiguredQuestions({
    required String databaseFileName,
  }) async {
    final database = ref.read(questionsDatabaseProvider);
    final selected = <Question>[];

    if (_questionSource == _MockExamQuestionSource.examSession) {
      final sessionId = _selectedExamSessionId;
      if (sessionId == null) return const <Question>[];
      final sessionQuestions = await database.loadQuestionsByExamSession(
        databaseFileName: databaseFileName,
        examSessionId: sessionId,
      );
      sessionQuestions.shuffle();
      selected.addAll(sessionQuestions.take(_selectedQuestionCount));
    } else {
      // Keep the legacy mock-exam behavior: distribute questions evenly
      // across the active subjects, then fill any shortage from the full pool.
      final subjectCount = _subjects.length;
      if (subjectCount == 0) return const <Question>[];

      final baseCount = _selectedQuestionCount ~/ subjectCount;
      final remainder = _selectedQuestionCount % subjectCount;
      final selectedCodes = <String>{};

      for (var i = 0; i < subjectCount; i++) {
        final requestedCount = baseCount + (i < remainder ? 1 : 0);
        final subjectQuestions = await database.loadRandomQuestions(
          databaseFileName: databaseFileName,
          subjectId: _subjects[i].id,
          limit: requestedCount,
        );
        for (final question in subjectQuestions) {
          if (selectedCodes.add(question.questionCode)) {
            selected.add(question);
          }
        }
      }

      final shortage = _selectedQuestionCount - selected.length;
      if (shortage > 0) {
        final fallbackQuestions = await database.loadRandomQuestions(
          databaseFileName: databaseFileName,
          limit: _selectedQuestionCount * 2,
        );
        for (final question in fallbackQuestions) {
          if (selectedCodes.add(question.questionCode)) {
            selected.add(question);
            if (selected.length >= _selectedQuestionCount) break;
          }
        }
      }
    }

    final subjectOrder = <int, int>{
      for (var i = 0; i < _subjects.length; i++) _subjects[i].id: i,
    };
    selected.sort((a, b) {
      final aOrder = subjectOrder[a.subjectId] ?? subjectOrder.length;
      final bOrder = subjectOrder[b.subjectId] ?? subjectOrder.length;
      return aOrder.compareTo(bOrder);
    });
    final activeSubjectIds = selected
        .map((question) => question.subjectId)
        .whereType<int>()
        .toSet();
    _subjects = _subjects
        .where((subject) => activeSubjectIds.contains(subject.id))
        .toList(growable: false);
    _subjectQuestionCounts.clear();
    for (final question in selected) {
      final subjectId = question.subjectId;
      if (subjectId != null) {
        _subjectQuestionCounts[subjectId] = (_subjectQuestionCounts[subjectId] ?? 0) + 1;
      }
    }
    return selected;
  }

  Future<void> _startExam() async {
    if (_subjects.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _answers.clear();
      _currentIndex = 0;
    });

    try {
      final qualification = await _resolveQualification();
      if (qualification == null) {
        throw StateError('資格が選択されていません。');
      }

      final questions = await _loadConfiguredQuestions(
        databaseFileName: qualification.databaseFileName,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
        _startedAt = DateTime.now();
        _stage = _MockExamStage.subjectIntro;
      });
      if (questions.isNotEmpty && _mode == _MockExamMode.exam) {
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

  Subject? _subjectForQuestion(Question question) {
    final subjectId = question.subjectId;
    if (subjectId == null) return null;
    for (final subject in _subjects) {
      if (subject.id == subjectId) return subject;
    }
    return null;
  }

  int _subjectLocalIndex(int globalIndex) {
    final questions = _questions ?? const <Question>[];
    if (globalIndex < 0 || globalIndex >= questions.length) return 0;
    final subjectId = questions[globalIndex].subjectId;
    var count = 0;
    for (var i = 0; i <= globalIndex; i++) {
      if (questions[i].subjectId == subjectId) count++;
    }
    return count;
  }

  bool _isNextQuestionNewSubject() {
    final questions = _questions ?? const <Question>[];
    if (_currentIndex >= questions.length - 1) return false;
    return questions[_currentIndex].subjectId !=
        questions[_currentIndex + 1].subjectId;
  }

  Future<void> _showQuestionList() async {
    _autoAdvanceTimer?.cancel();
    final questions = _questions ?? const <Question>[];
    if (questions.isEmpty) return;

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        Widget buildNumberButton(int index) {
          final isCurrent = index == _currentIndex;
          final isAnswered = _answers.containsKey(index);

          final backgroundColor = isCurrent
              ? const Color(0xFFFFF7E8)
              : isAnswered
                  ? const Color(0xFFEAF2FF)
                  : colorScheme.surface;
          final foregroundColor = isCurrent
              ? const Color(0xFFB45309)
              : isAnswered
                  ? colorScheme.primary
                  : colorScheme.onSurface;
          final borderColor = isCurrent
              ? const Color(0xFFF59E0B)
              : isAnswered
                  ? const Color(0xFF8CB8F5)
                  : colorScheme.outlineVariant;

          return InkWell(
            onTap: () => Navigator.of(context).pop(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(
                  color: borderColor,
                  width: isCurrent ? 2.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
          );
        }

        final subjectGroups = <Widget>[];
        for (final subject in _subjects) {
          final indexes = <int>[];
          for (var i = 0; i < questions.length; i++) {
            if (questions[i].subjectId == subject.id) indexes.add(i);
          }
          if (indexes.isEmpty) continue;

          subjectGroups.addAll([
            Text(
              subject.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final index in indexes) buildNumberButton(index)],
            ),
            const SizedBox(height: 22),
          ]);
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Text(
                      '問題一覧',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _QuestionListLegend(
                      color: colorScheme.surface,
                      borderColor: colorScheme.outlineVariant,
                      label: '未回答',
                    ),
                    const SizedBox(width: 16),
                    _QuestionListLegend(
                      color: const Color(0xFFEAF2FF),
                      borderColor: const Color(0xFF8CB8F5),
                      label: '回答済み',
                    ),
                    const SizedBox(width: 16),
                    _QuestionListLegend(
                      color: const Color(0xFFFFF7E8),
                      borderColor: const Color(0xFFF59E0B),
                      label: '現在',
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: subjectGroups,
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('回答済み ${_answers.length}/${questions.length}'),
                            Text(
                              '未回答 ${questions.length - _answers.length}問',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(-1),
                        child: const Text('採点する'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedIndex == null || !mounted) return;
    if (selectedIndex == -1) {
      await _submit();
      return;
    }
    setState(() {
      _currentIndex = selectedIndex;
      _stage = _MockExamStage.answering;
    });
    _scrollMockQuestionToTop();
  }

  Future<void> _interruptPractice() async {
    if (_mode != _MockExamMode.practice || _savingProgress) return;
    final questions = _questions ?? const <Question>[];
    if (questions.isEmpty) return;

    final shouldInterrupt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('練習を中断しますか？'),
        content: const Text(
          '現在の問題、回答内容、出題順を保存します。ホームの「続きから学習」から再開できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('中断する'),
          ),
        ],
      ),
    );
    if (shouldInterrupt != true || !mounted) return;

    setState(() => _savingProgress = true);
    try {
      final qualification = await _resolveQualification();
      if (qualification == null) {
        throw StateError('資格が選択されていません。');
      }
      final progress = LearningSessionProgress(
        qualificationId: qualification.id,
        qualificationCode: qualification.code,
        qualificationName: qualification.name,
        mode: 'mockPractice',
        resumeType: ResumeType.mockExam,
        questionCodes: questions
            .map((question) => question.questionCode)
            .toList(growable: false),
        nextIndex: _currentIndex,
        correctCount: 0,
        updatedAt: DateTime.now(),
        answers: Map<int, int>.unmodifiable(_answers),
      );
      await ref.read(learningSessionProgressStoreProvider).save(progress);
      _ownsSavedProgress = true;
      ref.invalidate(learningSessionProgressProvider);
      if (!mounted) return;
      context.go('/');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('中断データを保存できませんでした: $error')),
      );
    }
  }

  Future<bool> _savePracticeProgressOnly() async {
    if (_mode != _MockExamMode.practice || _savingProgress) return false;
    final questions = _questions ?? const <Question>[];
    if (questions.isEmpty) return false;

    setState(() => _savingProgress = true);
    try {
      final qualification = await _resolveQualification();
      if (qualification == null) {
        throw StateError('資格が選択されていません。');
      }
      final progress = LearningSessionProgress(
        qualificationId: qualification.id,
        qualificationCode: qualification.code,
        qualificationName: qualification.name,
        mode: 'mockPractice',
        resumeType: ResumeType.mockExam,
        questionCodes: questions
            .map((question) => question.questionCode)
            .toList(growable: false),
        nextIndex: _currentIndex,
        correctCount: 0,
        updatedAt: DateTime.now(),
        answers: Map<int, int>.unmodifiable(_answers),
      );
      await ref.read(learningSessionProgressStoreProvider).save(progress);
      _ownsSavedProgress = true;
      ref.invalidate(learningSessionProgressProvider);
      if (mounted) setState(() => _savingProgress = false);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _savingProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('中断データを保存できませんでした: $error')),
      );
      return false;
    }
  }

  Future<void> _clearOwnedProgress() async {
    if (!_ownsSavedProgress) return;
    await ref.read(learningSessionProgressStoreProvider).clear();
    ref.invalidate(learningSessionProgressProvider);
    _ownsSavedProgress = false;
  }

  Future<void> _submit({bool force = false}) async {
    _autoAdvanceTimer?.cancel();
    if (_submitting) return;
    final questions = _questions;
    if (questions == null || questions.isEmpty) return;

    if (!force && _answers.length < questions.length) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('未回答の問題があります'),
          content: Text(
            '未回答が${questions.length - _answers.length}問あります。\n\n'
            '未回答は不正解として採点します。',
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
      final qualification = await _resolveQualification();
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

      final subjectTotals = <String, _ExamSubjectAccumulator>{};
      for (var i = 0; i < questions.length; i++) {
        final question = questions[i];
        final subjectName = question.subjectName?.trim().isNotEmpty == true
            ? question.subjectName!.trim()
            : '科目未設定';
        final subject = subjectTotals.putIfAbsent(
          subjectName,
          _ExamSubjectAccumulator.new,
        );
        subject.totalQuestions++;
        final selected = _answers[i];
        if (selected != null && question.isCorrectChoice(selected)) {
          subject.correctQuestions++;
        }
      }
      final completedAt = DateTime.now();
      await userDatabase.recordExamResult(
        qualificationCode: qualification.code,
        startedAt: _startedAt ?? completedAt,
        completedAt: completedAt,
        totalQuestions: questions.length,
        correctQuestions: correct,
        passingScorePercent: 70,
        subjectResults: subjectTotals.entries
            .map(
              (entry) => ExamSubjectResultInput(
                subjectName: entry.key,
                totalQuestions: entry.value.totalQuestions,
                correctQuestions: entry.value.correctQuestions,
              ),
            )
            .toList(growable: false),
        answers: [
          for (var i = 0; i < questions.length; i++)
            ExamAnswerResultInput(
              questionCode: questions[i].questionCode,
              selectedChoice: _answers[i],
              isCorrect: _answers[i] != null &&
                  questions[i].isCorrectChoice(_answers[i]!),
            ),
        ],
      );
      ref.invalidate(learningResultsProvider);
      await _clearOwnedProgress();

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MockExamResultScreen(
            questions: questions,
            answers: Map<int, int>.unmodifiable(_answers),
            correct: correct,
            startedAt: _startedAt ?? DateTime.now(),
            completedAt: DateTime.now(),
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
    final mode = _mode;
    return Scaffold(
      appBar: AppBar(
        leading: const AppHomeButton(),
        automaticallyImplyLeading: false,
        flexibleSpace: const AppBarBackground(),
        title: Text(
          mode == _MockExamMode.exam
              ? '模擬試験・本試験モード'
              : mode == _MockExamMode.practice
                  ? '模擬試験・練習モード'
                  : '模擬試験',
        ),
        actions: !_loading &&
                (_stage == _MockExamStage.subjectIntro ||
                    _stage == _MockExamStage.answering)
            ? [
                if (mode == _MockExamMode.exam)
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
                  )
                else if (mode == _MockExamMode.practice)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: _savingProgress ? null : _interruptPractice,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                      label: Text(_savingProgress ? '保存中…' : '中断'),
                    ),
                  ),
                _buildMockExamHomeAction(),
              ]
            : [_buildMockExamHomeAction()],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildMockExamHomeAction() {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton.filledTonal(
        tooltip: 'ホームへ戻る',
        onPressed: _confirmAndGoHome,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.home_rounded, size: 21),
      ),
    );
  }

  Future<void> _confirmAndGoHome() async {
    final isRunning = !_loading &&
        (_stage == _MockExamStage.subjectIntro ||
            _stage == _MockExamStage.answering);
    if (!isRunning) {
      if (mounted) context.go('/');
      return;
    }

    final isPractice = _mode == _MockExamMode.practice;
    final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              isPractice
                  ? Icons.pause_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: AppColors.navy,
            ),
            title: Text(isPractice ? '練習を中断しますか？' : '模擬試験を終了しますか？'),
            content: Text(
              isPractice
                  ? 'ホームへ戻る前に、現在の進捗を保存できます。'
                  : '現在の解答内容は保存されません。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isPractice ? '保存して戻る' : '終了する'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldLeave || !mounted) return;

    if (isPractice) {
      final saved = await _savePracticeProgressOnly();
      if (!saved || !mounted) return;
    }
    context.go('/');
  }

  Future<void> _showExamSessionSelector() async {
    if (_examSessions.isEmpty) return;
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '年度・期を選択',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _examSessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
                  itemBuilder: (context, index) {
                    final session = _examSessions[index];
                    final selected = session.id == _selectedExamSessionId;
                    return ListTile(
                      title: Text(
                        session.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${session.questionCount}問'),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.blue)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(session.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedId == null || !mounted) return;
    setState(() {
      _selectedExamSessionId = selectedId;
      _normalizeQuestionCountForSelectedSession();
    });
  }

  ExamSession? get _selectedExamSession {
    final sessionId = _selectedExamSessionId;
    if (sessionId == null) return null;
    for (final session in _examSessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  bool _isQuestionCountAvailable(int count) {
    if (_questionSource == _MockExamQuestionSource.random) return true;
    final session = _selectedExamSession;
    return session != null && count <= session.questionCount;
  }

  void _normalizeQuestionCountForSelectedSession() {
    if (_questionSource != _MockExamQuestionSource.examSession) return;
    final session = _selectedExamSession;
    if (session == null || _isQuestionCountAvailable(_selectedQuestionCount)) {
      return;
    }
    final available = MockExamConfig.questionCountOptions
        .where((count) => count <= session.questionCount)
        .toList(growable: false);
    _selectedQuestionCount = available.isEmpty ? session.questionCount : available.last;
  }

  Widget _buildModeSelection(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text(
          '模擬試験の設定',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '出題条件を選択して、練習または本試験モードを開始します。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        _MockExamSettingCard(
          title: '問題数設定',
          child: SegmentedButton<int>(
            segments: [
              for (final count in MockExamConfig.questionCountOptions)
                ButtonSegment(
                  value: count,
                  label: Text('$count問'),
                  enabled: _isQuestionCountAvailable(count),
                ),
            ],
            selected: <int>{_selectedQuestionCount},
            onSelectionChanged: (values) => setState(() => _selectedQuestionCount = values.first),
          ),
        ),
        const SizedBox(height: 12),
        _MockExamSettingCard(
          title: '制限時間',
          child: SegmentedButton<int>(
            segments: [
              for (final minutes in MockExamConfig.durationMinutesOptions)
                ButtonSegment(value: minutes, label: Text('$minutes分')),
            ],
            selected: <int>{_selectedDurationMinutes},
            onSelectionChanged: (values) => setState(() => _selectedDurationMinutes = values.first),
          ),
        ),
        const SizedBox(height: 12),
        _MockExamSettingCard(
          title: '出題形式',
          child: RadioGroup<_MockExamQuestionSource>(
            groupValue: _questionSource,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _questionSource = value;
                  _normalizeQuestionCountForSelectedSession();
                });
              }
            },
            child: Column(
              children: [
                const RadioListTile<_MockExamQuestionSource>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('ランダム出題'),
                  value: _MockExamQuestionSource.random,
                ),
                RadioListTile<_MockExamQuestionSource>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('年度期別過去問'),
                  value: _MockExamQuestionSource.examSession,
                  enabled: _examSessions.isNotEmpty,
                ),
                if (_questionSource == _MockExamQuestionSource.examSession) ...[
                  const SizedBox(height: 4),
                  _ExamSessionSelector(
                    session: _selectedExamSession,
                    onTap: _showExamSessionSelector,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _MockExamModeButton(
          title: '練習モード',
          description: '時間制限なし。途中で中断・再開できます。',
          icon: Icons.school_rounded,
          color: AppColors.green,
          filled: false,
          onPressed: _canStartConfiguredExam
              ? () => _selectMode(_MockExamMode.practice)
              : null,
        ),
        const SizedBox(height: 12),
        _MockExamModeButton(
          title: '本試験モード',
          description: '制限時間内に解答し、最後にまとめて採点します。',
          icon: Icons.timer_rounded,
          color: AppColors.navy,
          filled: true,
          onPressed: _canStartConfiguredExam
              ? () => _selectMode(_MockExamMode.exam)
              : null,
        ),
      ],
    );
  }

  void _scrollMockQuestionToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_questionScrollController.hasClients) {
        _questionScrollController.jumpTo(0);
      }
    });
  }

  bool get _canStartConfiguredExam =>
      _questionSource == _MockExamQuestionSource.random || _selectedExamSessionId != null;

  Widget _buildSubjectOverview(BuildContext context) {
    final expectedTotal = _selectedQuestionCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text('試験科目', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '選択した設定で問題を出題します。',
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _subjects.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(_subjects[i].name),
              trailing: Text('${_subjectQuestionCounts[_subjects[i].id] ?? 0}問'),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('合計'),
                const Spacer(),
                Text(
                  '$expectedTotal問',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _subjects.isEmpty ? null : _startExam,
          icon: const Icon(Icons.play_arrow),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('始める'),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectIntro(BuildContext context) {
    final questions = _questions ?? const <Question>[];
    if (questions.isEmpty) {
      return const Center(child: Text('模擬試験に使用できる問題がありません。'));
    }
    final question = questions[_currentIndex];
    final subject = _subjectForQuestion(question);
    final count = subject == null
        ? 0
        : (_subjectQuestionCounts[subject.id] ?? 0);
    final subjectPosition = subject == null ? 0 : _subjects.indexOf(subject) + 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$subjectPosition科目目',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  subject?.name ?? question.subjectName ?? '試験科目',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text('$count問'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() => _stage = _MockExamStage.answering);
                    _scrollMockQuestionToTop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('この科目を始める'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_stage == _MockExamStage.modeSelection) {
      return _buildModeSelection(context);
    }
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
    if (_stage == _MockExamStage.subjectOverview) {
      return _buildSubjectOverview(context);
    }
    if (_stage == _MockExamStage.subjectIntro) {
      return _buildSubjectIntro(context);
    }

    final questions = _questions ?? const <Question>[];
    if (questions.isEmpty) {
      return const Center(child: Text('模擬試験に使用できる問題がありません。'));
    }

    final question = questions[_currentIndex];
    final selected = _answers[_currentIndex];
    final subject = _subjectForQuestion(question);
    final subjectQuestionCount = subject == null
        ? 0
        : (_subjectQuestionCounts[subject.id] ?? 0);
    final localIndex = _subjectLocalIndex(_currentIndex);

    return Column(
      children: [
        LinearProgressIndicator(value: (_currentIndex + 1) / questions.length),
        Expanded(
          child: ListView(
            controller: _questionScrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              Text(
                subject?.name ?? question.subjectName ?? '試験科目',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '問$localIndex / $subjectQuestionCount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text('全体 ${_currentIndex + 1} / ${questions.length}'),
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
              RepaintBoundary(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  child: Text(
                    question.questionText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.75,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
              ),
              if (question.imagePath != null &&
                  question.imagePath!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MockQuestionImage(imagePath: question.imagePath!),
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
                    _autoAdvanceTimer?.cancel();
                    final answeredIndex = _currentIndex;
                    setState(() => _answers[answeredIndex] = i + 1);
                    final settings = ref.read(appSettingsProvider);
                    if (settings.advanceAfterMockAnswer &&
                        answeredIndex < questions.length - 1) {
                      _autoAdvanceTimer = Timer(
                        const Duration(milliseconds: 600),
                        () {
                          if (!mounted ||
                              _submitting ||
                              _currentIndex != answeredIndex ||
                              _currentIndex >= questions.length - 1) {
                            return;
                          }
                          setState(() => _currentIndex++);
                          _scrollMockQuestionToTop();
                        },
                      );
                    }
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
                        : () {
                            _autoAdvanceTimer?.cancel();
                            if (_currentIndex <= 0) return;
                            setState(() => _currentIndex--);
                            _scrollMockQuestionToTop();
                          },
                    child: const Text('前へ'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 88,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _showQuestionList,
                    child: const Text('一覧'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _currentIndex == questions.length - 1
                      ? FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting ? '採点中…' : '採点する'),
                        )
                      : FilledButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  _autoAdvanceTimer?.cancel();
                                  if (_currentIndex >= questions.length - 1) {
                                    return;
                                  }
                                  final showNextSubject =
                                      _isNextQuestionNewSubject();
                                  setState(() {
                                    _currentIndex++;
                                    if (showNextSubject) {
                                      _stage = _MockExamStage.subjectIntro;
                                    }
                                  });
                                  _scrollMockQuestionToTop();
                                },
                          child: Text(
                            _isNextQuestionNewSubject() ? '次の科目へ' : '次へ',
                          ),
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

class _QuestionListLegend extends StatelessWidget {
  const _QuestionListLegend({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ExamSessionSelector extends StatelessWidget {
  const _ExamSessionSelector({required this.session, required this.onTap});

  final ExamSession? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.navy),
              const SizedBox(width: 12),
              Expanded(
                child: session == null
                    ? Text(
                        '年度・期を選択',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session!.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${session!.questionCount}問',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockExamModeButton extends StatelessWidget {
  const _MockExamModeButton({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : AppColors.navy;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: filled
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: filled
                                ? Colors.white.withValues(alpha: 0.82)
                                : AppColors.textPrimary.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockExamSettingCard extends StatelessWidget {
  const _MockExamSettingCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppColors.navy.withValues(alpha: 0.055) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? AppColors.navy.withValues(alpha: 0.65)
              : AppColors.border,
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
                const Icon(Icons.check_circle_rounded, color: AppColors.navy),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MockExamResultScreen extends StatelessWidget {
  const MockExamResultScreen({
    super.key,
    required this.questions,
    required this.answers,
    required this.correct,
    required this.startedAt,
    required this.completedAt,
  });

  final List<Question> questions;
  final Map<int, int> answers;
  final int correct;
  final DateTime startedAt;
  final DateTime completedAt;

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    final score = total == 0 ? 0.0 : correct / total * 100;
    final passed = score >= 70;
    final elapsed = completedAt.difference(startedAt);
    final wrongIndexes = <int>[
      for (var i = 0; i < questions.length; i++)
        if (answers[i] == null || !questions[i].isCorrectChoice(answers[i]!)) i,
    ];
    final subjectResults = _buildSubjectResults(questions, answers);

    return Scaffold(
      appBar: AppBar(
        leading: const AppHomeButton(),
        automaticallyImplyLeading: false,
        title: const Text('模擬試験結果'),
        actions: const [AppHomeActionButton()],
        flexibleSpace: const AppBarBackground(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 116,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 11,
                            backgroundColor: AppColors.border,
                            color: passed ? AppColors.blue : AppColors.orange,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${score.toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.navy,
                                  ),
                            ),
                            Text('正答率', style: Theme.of(context).textTheme.labelMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passed ? '合格基準達成' : '復習が必要です',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: passed ? AppColors.green : AppColors.orange,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text('$total問中 $correct問正解'),
                        const SizedBox(height: 5),
                        Text('不正解 ${total - correct}問'),
                        const SizedBox(height: 5),
                        Text('所要時間 ${_formatDuration(elapsed)}'),
                      ],
                    ),
                  ),
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
      appBar: AppBar(
        leading: const AppHomeButton(),
        automaticallyImplyLeading: false,
        title: Text('問題 $questionNumber'),
        actions: const [AppHomeActionButton()],
        flexibleSpace: const AppBarBackground(),
      ),
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
            _MockQuestionImage(imagePath: question.imagePath!),
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
      backgroundColor = AppColors.green.withValues(alpha: 0.075);
      borderColor = AppColors.green.withValues(alpha: 0.55);
      icon = Icons.check_circle;
    } else if (isSelected) {
      backgroundColor = AppColors.red.withValues(alpha: 0.065);
      borderColor = AppColors.red.withValues(alpha: 0.48);
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
      appBar: AppBar(
        leading: const AppHomeButton(),
        automaticallyImplyLeading: false,
        title: const Text('間違えた問題の復習'),
        actions: const [AppHomeActionButton()],
        flexibleSpace: const AppBarBackground(),
      ),
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
                  ChoiceCard(
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


class _ExamSubjectAccumulator {
  int totalQuestions = 0;
  int correctQuestions = 0;
}


class _MockQuestionImage extends StatelessWidget {
  const _MockQuestionImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _MockZoomableImageViewer(imagePath: imagePath),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120, maxHeight: 360),
                child: Image.asset(
                  imagePath,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.zoom_in_rounded,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'タップして拡大・ピンチズーム',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockZoomableImageViewer extends StatefulWidget {
  const _MockZoomableImageViewer({required this.imagePath});
  final String imagePath;

  @override
  State<_MockZoomableImageViewer> createState() =>
      _MockZoomableImageViewerState();
}

class _MockZoomableImageViewerState extends State<_MockZoomableImageViewer> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('問題画像'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          actions: [
            IconButton(
              tooltip: '拡大を元に戻す',
              onPressed: () => _controller.value = Matrix4.identity(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 6,
          panEnabled: true,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(80),
          clipBehavior: Clip.none,
          child: SizedBox.expand(
            child: Image.asset(
              widget.imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('画像を読み込めませんでした。'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
