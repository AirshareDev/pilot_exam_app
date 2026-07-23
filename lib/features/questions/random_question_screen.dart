import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_colors.dart';
import '../../models/learning_session_progress.dart';
import '../../models/question.dart';
import '../../models/question_learning_status.dart';
import '../../models/qualification.dart';
import '../../shared/app_page.dart';
import '../learning_progress/learning_session_progress_provider.dart';
import '../settings/app_settings_provider.dart';
import 'question_provider.dart';
import 'widgets/choice_card.dart';

class RandomQuestionScreen extends ConsumerStatefulWidget {
  const RandomQuestionScreen({
    required this.qualification,
    this.subjectId,
    this.subjectName,
    this.examSessionId,
    this.examSessionName,
    this.bookmarkedOnly = false,
    this.resumeProgress,
    super.key,
  });

  final Qualification qualification;
  final int? subjectId;
  final String? subjectName;
  final int? examSessionId;
  final String? examSessionName;
  final bool bookmarkedOnly;
  final LearningSessionProgress? resumeProgress;

  @override
  ConsumerState<RandomQuestionScreen> createState() =>
      _RandomQuestionScreenState();
}

class _RandomQuestionScreenState extends ConsumerState<RandomQuestionScreen> {
  late Future<List<Question>> _questionsFuture;
  List<Question> _questions = const <Question>[];
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<_AnswerViewState?> _answerState =
      ValueNotifier<_AnswerViewState?>(null);

  int _currentIndex = 0;
  Future<void> _answerWriteQueue = Future<void>.value();
  int _correctCount = 0;
  bool _isSavingBookmark = false;
  Map<String, QuestionLearningStatus> _statuses =
      const <String, QuestionLearningStatus>{};

  @override
  void initState() {
    super.initState();
    final resumeIndex = widget.resumeProgress?.nextIndex ?? 0;
    _currentIndex = resumeIndex < 0 ? 0 : resumeIndex;
    _correctCount = widget.resumeProgress?.correctCount ?? 0;
    _questionsFuture = _loadQuestions();
  }

  @override
  void dispose() {
    _answerState.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<Question>> _loadQuestions() async {
    final repository = ref.read(questionRepositoryProvider);

    final List<Question> questions;
    final resumeProgress = widget.resumeProgress;
    if (resumeProgress != null && resumeProgress.questionCodes.isNotEmpty) {
      questions = await repository.loadQuestionsByCodes(
        qualification: widget.qualification,
        questionCodes: resumeProgress.questionCodes,
      );
    } else if (widget.bookmarkedOnly) {
      questions = await repository.loadBookmarkedQuestions(
        qualification: widget.qualification,
      );
    } else if (widget.subjectId != null) {
      questions = await repository.loadQuestionsBySubject(
        qualification: widget.qualification,
        subjectId: widget.subjectId!,
      );
    } else if (widget.examSessionId != null) {
      questions = await repository.loadQuestionsByExamSession(
        qualification: widget.qualification,
        examSessionId: widget.examSessionId!,
      );
    } else {
      questions = await repository.loadRandomQuestions(
        qualification: widget.qualification,
        limit: 20,
      );
    }

    _statuses = await repository.loadQuestionStatuses(
      qualification: widget.qualification,
      questions: questions,
    );

    _questions = questions;

    if (questions.isNotEmpty) {
      if (_currentIndex >= questions.length) _currentIndex = 0;
      _answerState.value = _AnswerViewState.initial(
        correctCount: _correctCount,
        status: _statusFor(questions[_currentIndex]),
      );
      await _saveProgress(questions, nextIndex: _currentIndex);
    } else {
      await _clearProgress();
    }

    if (questions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheUpcomingImages(questions, _currentIndex);
      });
    }
    return questions;
  }

  String get _pageTitle {
    if (widget.bookmarkedOnly) {
      return '${widget.qualification.name}・ブックマーク';
    }

    final subjectName = widget.subjectName;
    if (subjectName != null && subjectName.isNotEmpty) {
      return '$subjectName・一問一答';
    }

    final examSessionName = widget.examSessionName;
    if (examSessionName != null && examSessionName.isNotEmpty) {
      return '$examSessionName・過去問';
    }

    return '${widget.qualification.name}・ランダム問題';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        final questions = snapshot.data ?? const <Question>[];
        final hasCurrentQuestion = snapshot.connectionState ==
                ConnectionState.done &&
            !snapshot.hasError &&
            questions.isNotEmpty;
        if (hasCurrentQuestion && _currentIndex >= questions.length) {
          _currentIndex = 0;
        }

        final currentQuestion = hasCurrentQuestion
            ? questions[_currentIndex]
            : null;
        final currentStatus = currentQuestion == null
            ? null
            : _statusFor(currentQuestion);

        return AppPage(
          title: _pageTitle,
          actions: currentQuestion == null
              ? const <Widget>[]
              : <Widget>[
                  IconButton(
                    tooltip: currentStatus?.isBookmarked == true
                        ? 'ブックマークを解除'
                        : 'ブックマークに追加',
                    onPressed: _isSavingBookmark
                        ? null
                        : () => _toggleBookmark(currentQuestion),
                    icon: Icon(
                      currentStatus?.isBookmarked == true
                          ? Icons.bookmark
                          : Icons.bookmark_outline,
                    ),
                  ),
                ],
          body: _buildFutureBody(snapshot, questions),
        );
      },
    );
  }

  Widget _buildFutureBody(
    AsyncSnapshot<List<Question>> snapshot,
    List<Question> questions,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return _ErrorView(
        message: snapshot.error.toString(),
        onRetry: _retry,
      );
    }
    if (questions.isEmpty) {
      return _EmptyView(
        message: widget.bookmarkedOnly
            ? 'ブックマークした問題はありません。'
            : 'この条件に該当する問題は登録されていません。',
      );
    }
    return _buildQuestionView(questions);
  }

  Widget _buildQuestionView(List<Question> questions) {
    final question = questions[_currentIndex];
    final imagePath = question.imagePath?.trim();
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / questions.length,
          minHeight: 4,
          backgroundColor: AppColors.blue.withValues(alpha: 0.10),
          color: AppColors.blue,
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                ValueListenableBuilder<_AnswerViewState?>(
                  valueListenable: _answerState,
                  builder: (context, state, child) {
                    final currentState = state ??
                        _AnswerViewState.initial(
                          correctCount: _correctCount,
                          status: _statusFor(question),
                        );
                    return _QuestionHeader(
                      currentIndex: _currentIndex,
                      totalCount: questions.length,
                      correctCount: currentState.correctCount,
                    );
                  },
                ),
                if (question.metadataText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    question.metadataText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                ValueListenableBuilder<_AnswerViewState?>(
                  valueListenable: _answerState,
                  builder: (context, state, child) =>
                      _LearningHistorySummary(
                    status: state?.status ?? _statusFor(question),
                  ),
                ),
                const SizedBox(height: 14),
                RepaintBoundary(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                    child: Text(
                      question.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            height: 1.75,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    child: _QuestionImage(
                      imagePath: imagePath,
                      onTap: () => _showImageViewer(imagePath),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ValueListenableBuilder<_AnswerViewState?>(
                  valueListenable: _answerState,
                  builder: (context, state, child) {
                    final currentState = state ??
                        _AnswerViewState.initial(
                          correctCount: _correctCount,
                          status: _statusFor(question),
                        );
                    return _AnswerArea(
                      question: question,
                      state: currentState,
                      onAnswer: (selectedChoice) => _answerQuestion(
                        question: question,
                        selectedChoice: selectedChoice,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<_AnswerViewState?>(
          valueListenable: _answerState,
          builder: (context, state, child) {
            if (state?.isAnswered != true) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _goToNextQuestion(questions),
                      icon: Icon(
                        _currentIndex == questions.length - 1
                            ? Icons.analytics_outlined
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _currentIndex == questions.length - 1
                            ? '結果を見る'
                            : '次の問題',
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  QuestionLearningStatus _statusFor(Question question) {
    return _statuses[question.questionCode] ??
        QuestionLearningStatus(
          questionCode: question.questionCode,
          isBookmarked: question.isBookmarked,
        );
  }

  Future<void> _toggleBookmark(Question question) async {
    if (_isSavingBookmark) return;

    final previous = _statusFor(question);
    final nextValue = !previous.isBookmarked;
    setState(() {
      _isSavingBookmark = true;
      _statuses = <String, QuestionLearningStatus>{
        ..._statuses,
        question.questionCode: previous.copyWith(
          isBookmarked: nextValue,
        ),
      };
    });

    try {
      await ref.read(questionRepositoryProvider).setBookmark(
            qualification: widget.qualification,
            question: question,
            isBookmarked: nextValue,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? 'ブックマークに追加しました。'
                : 'ブックマークを解除しました。',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statuses = <String, QuestionLearningStatus>{
          ..._statuses,
          question.questionCode: previous,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ブックマークを保存できませんでした: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingBookmark = false);
      }
    }
  }

  Future<void> _showImageViewer(String imagePath) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ZoomableImageViewer(imagePath: imagePath),
    );
  }

  void _answerQuestion({
    required Question question,
    required int selectedChoice,
  }) {
    if (_answerState.value?.isAnswered == true) return;

    final isCorrect = question.isCorrectChoice(selectedChoice);
    final previous = _statusFor(question);
    final answeredAt = DateTime.now();

    final nextStatus = previous.copyWith(
      correctCount: previous.correctCount + (isCorrect ? 1 : 0),
      wrongCount: previous.wrongCount + (isCorrect ? 0 : 1),
      lastResult: isCorrect,
      lastSelectedChoice: selectedChoice,
      lastAnswered: answeredAt,
    );
    if (isCorrect) _correctCount++;
    _statuses = <String, QuestionLearningStatus>{
      ..._statuses,
      question.questionCode: nextStatus,
    };
    _answerState.value = _AnswerViewState(
      selectedChoice: selectedChoice,
      isAnswered: true,
      correctCount: _correctCount,
      status: nextStatus,
    );

    _answerWriteQueue = _answerWriteQueue.then((_) => _persistAnswer(
          question: question,
          selectedChoice: selectedChoice,
        ));
    unawaited(_answerWriteQueue);

    final settings = ref.read(appSettingsProvider);
    if (isCorrect && settings.advanceAfterCorrect) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _answerState.value?.selectedChoice != selectedChoice) {
          return;
        }
        _goToNextQuestion(_questions);
      });
    }
  }

  Future<void> _persistAnswer({
    required Question question,
    required int selectedChoice,
  }) async {
    try {
      await ref.read(questionRepositoryProvider).recordAnswer(
            qualification: widget.qualification,
            question: question,
            selectedChoice: selectedChoice,
          );

      final answeredIndex = _questions.indexWhere(
        (item) => item.questionCode == question.questionCode,
      );
      if (answeredIndex < 0 || answeredIndex >= _questions.length - 1) {
        await _clearProgress();
      } else {
        await _saveProgress(_questions, nextIndex: answeredIndex + 1);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('回答結果を保存できませんでした: $error')),
      );
    }
  }

  void _goToNextQuestion(List<Question> questions) {
    if (_currentIndex == questions.length - 1) {
      _showResult(questions.length);
      return;
    }
    setState(() {
      _currentIndex++;
      _answerState.value = _AnswerViewState.initial(
        correctCount: _correctCount,
        status: _statusFor(questions[_currentIndex]),
      );
    });
    _scrollToTop();
    _precacheUpcomingImages(questions, _currentIndex);
  }

  void _precacheUpcomingImages(List<Question> questions, int fromIndex) {
    final lastIndex = (fromIndex + 2).clamp(0, questions.length - 1);
    for (var index = fromIndex + 1; index <= lastIndex; index++) {
      final imagePath = questions[index].imagePath?.trim();
      if (imagePath == null || imagePath.isEmpty) continue;
      unawaited(precacheImage(AssetImage(imagePath), context));
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  Future<void> _showResult(int total) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final rate = total == 0 ? 0 : ((_correctCount / total) * 100).round();
        return AlertDialog(
          title: const Text('学習結果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_correctCount / $total 問正解',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('正答率 $rate%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('メニューへ戻る'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _restart();
              },
              child: const Text('もう一度'),
            ),
          ],
        );
      },
    );
  }

  void _restart() async {
    await _clearProgress();
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _correctCount = 0;
      _statuses = const <String, QuestionLearningStatus>{};
      _answerState.value = null;
      _questionsFuture = _loadQuestions();
    });
    _scrollToTop();
  }

  Future<void> _saveProgress(
    List<Question> questions, {
    required int nextIndex,
  }) async {
    if (questions.isEmpty || nextIndex < 0 || nextIndex >= questions.length) {
      await _clearProgress();
      return;
    }

    final progress = LearningSessionProgress(
      qualificationId: widget.qualification.id,
      qualificationCode: widget.qualification.code,
      qualificationName: widget.qualification.name,
      mode: _sessionMode,
      resumeType: widget.subjectId != null
          ? ResumeType.subjectLearning
          : ResumeType.randomLearning,
      questionCodes: questions
          .map((question) => question.questionCode)
          .toList(growable: false),
      nextIndex: nextIndex,
      correctCount: _correctCount,
      updatedAt: DateTime.now(),
      subjectId: widget.subjectId,
      subjectName: widget.subjectName,
      examSessionId: widget.examSessionId,
      examSessionName: widget.examSessionName,
      bookmarkedOnly: widget.bookmarkedOnly,
    );
    await ref.read(learningSessionProgressStoreProvider).save(progress);
    ref.invalidate(learningSessionProgressProvider);
  }

  Future<void> _clearProgress() async {
    await ref.read(learningSessionProgressStoreProvider).clear();
    ref.invalidate(learningSessionProgressProvider);
  }

  String get _sessionMode {
    if (widget.bookmarkedOnly) return 'bookmarks';
    if (widget.subjectId != null) return 'subject';
    if (widget.examSessionId != null) return 'pastExam';
    return 'random';
  }

  void _retry() => _restart();
}


class _AnswerViewState {
  const _AnswerViewState({
    required this.selectedChoice,
    required this.isAnswered,
    required this.correctCount,
    required this.status,
  });

  factory _AnswerViewState.initial({
    required int correctCount,
    required QuestionLearningStatus status,
  }) {
    return _AnswerViewState(
      selectedChoice: null,
      isAnswered: false,
      correctCount: correctCount,
      status: status,
    );
  }

  final int? selectedChoice;
  final bool isAnswered;
  final int correctCount;
  final QuestionLearningStatus status;
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({
    required this.currentIndex,
    required this.totalCount,
    required this.correctCount,
  });

  final int currentIndex;
  final int totalCount;
  final int correctCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '問題 ${currentIndex + 1} / $totalCount',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const Spacer(),
        Text(
          '正解数 $correctCount',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _AnswerArea extends StatelessWidget {
  const _AnswerArea({
    required this.question,
    required this.state,
    required this.onAnswer,
  });

  final Question question;
  final _AnswerViewState state;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final selectedChoice = state.selectedChoice;
    final isCorrect = selectedChoice != null &&
        question.isCorrectChoice(selectedChoice);

    return Column(
      children: [
        for (var index = 0; index < question.choices.length; index++)
          RepaintBoundary(
            key: ValueKey('${question.questionCode}-${index + 1}'),
            child: ChoiceCard(
              number: index + 1,
              text: question.choices[index],
              isSelected: selectedChoice == index + 1,
              isAnswered: state.isAnswered,
              isCorrect: question.isCorrectChoice(index + 1),
              onTap: () => onAnswer(index + 1),
            ),
          ),
        if (state.isAnswered) ...[
          const SizedBox(height: 8),
          _AnswerResultCard(
            question: question,
            isCorrect: isCorrect,
          ),
        ],
      ],
    );
  }
}

class _AnswerResultCard extends StatelessWidget {
  const _AnswerResultCard({
    required this.question,
    required this.isCorrect,
  });

  final Question question;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final accentColor = isCorrect ? AppColors.green : AppColors.red;
    return Card(
      margin: EdgeInsets.zero,
      color: accentColor.withValues(alpha: 0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? '正解です' : '不正解です',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: accentColor, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (question.isAllCorrect)
              const Text(
                'この問題は、すべての選択肢を正解として扱います。',
                style: TextStyle(fontSize: 14, height: 1.45),
              )
            else
              Text(
                _correctAnswerText(question),
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
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
    );
  }

  static String _correctAnswerText(Question question) {
    final correctChoice = question.correctChoice;
    if (correctChoice == null ||
        correctChoice < 1 ||
        correctChoice > question.choices.length) {
      return '正解情報が登録されていません。';
    }
    return '正解：$correctChoice. ${question.choices[correctChoice - 1]}';
  }
}

class _LearningHistorySummary extends StatelessWidget {
  const _LearningHistorySummary({required this.status});

  final QuestionLearningStatus status;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(
          status.answerCount == 0 ? '過去 －' : '過去 ${status.answerCount}回',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          status.answerCount == 0 ? '正解 －' : '正解 ${status.correctCount}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          status.answerCount == 0 ? '不正解 －' : '不正解 ${status.wrongCount}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          status.answerCount == 0 ? '正答率 －' : '正答率 ${status.correctRate}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ZoomableImageViewer extends StatefulWidget {
  const _ZoomableImageViewer({required this.imagePath});

  final String imagePath;

  @override
  State<_ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<_ZoomableImageViewer> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('問題画像'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          actions: [
            IconButton(
              tooltip: '拡大を元に戻す',
              onPressed: _resetZoom,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
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
                    errorBuilder: (context, error, stackTrace) =>
                        _ImageLoadError(imagePath: widget.imagePath),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text('2本指で拡大・縮小できます'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.imagePath, required this.onTap});
  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 120,
                  maxHeight: 360,
                ),
                child: Image.asset(
                  imagePath,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _ImageLoadError(imagePath: imagePath),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.zoom_in,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 42),
          const SizedBox(height: 10),
          const Text('問題画像を読み込めませんでした。'),
          const SizedBox(height: 6),
          SelectableText(
            imagePath,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
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
          const Text('問題を読み込めませんでした。', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('再読み込み')),
        ],
      ),
    );
  }
}
