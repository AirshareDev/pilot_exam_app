import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/catalog_database.dart';
import '../database/questions_database.dart';
import '../database/user_database.dart';
import '../models/exam_session.dart';
import '../models/qualification.dart';
import '../models/question.dart';
import '../models/question_learning_status.dart';
import '../models/subject.dart';

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository(
    catalogDatabase: ref.watch(catalogDatabaseProvider),
    questionsDatabase: ref.watch(questionsDatabaseProvider),
    userDatabase: ref.watch(userDatabaseProvider),
  );
});

class QuestionRepository {
  const QuestionRepository({
    required CatalogDatabase catalogDatabase,
    required QuestionsDatabase questionsDatabase,
    required UserDatabase userDatabase,
  })  : _catalogDatabase = catalogDatabase,
        _questionsDatabase = questionsDatabase,
        _userDatabase = userDatabase;

  final CatalogDatabase _catalogDatabase;
  final QuestionsDatabase _questionsDatabase;
  final UserDatabase _userDatabase;

  Future<List<Qualification>> loadQualifications() {
    return _catalogDatabase.loadQualifications();
  }

  Future<List<Subject>> loadSubjects(Qualification qualification) {
    return _questionsDatabase.loadSubjects(
      databaseFileName: qualification.databaseFileName,
    );
  }

  Future<List<ExamSession>> loadExamSessions(Qualification qualification) {
    return _questionsDatabase.loadExamSessions(
      databaseFileName: qualification.databaseFileName,
    );
  }

  Future<List<Question>> loadRandomQuestions({
    required Qualification qualification,
    int? subjectId,
    int? examSessionId,
    int limit = 20,
  }) async {
    final questions = await _questionsDatabase.loadRandomQuestions(
      databaseFileName: qualification.databaseFileName,
      subjectId: subjectId,
      examSessionId: examSessionId,
      limit: limit,
    );
    return _applyBookmarks(qualification.code, questions);
  }

  Future<List<Question>> loadQuestionsBySubject({
    required Qualification qualification,
    required int subjectId,
  }) async {
    final questions = await _questionsDatabase.loadQuestionsBySubject(
      databaseFileName: qualification.databaseFileName,
      subjectId: subjectId,
    );
    return _applyBookmarks(qualification.code, questions);
  }

  Future<List<Question>> loadQuestionsByExamSession({
    required Qualification qualification,
    required int examSessionId,
    int? subjectId,
  }) async {
    final questions = await _questionsDatabase.loadQuestionsByExamSession(
      databaseFileName: qualification.databaseFileName,
      examSessionId: examSessionId,
      subjectId: subjectId,
    );
    return _applyBookmarks(qualification.code, questions);
  }

  Future<List<Question>> loadQuestionsByCodes({
    required Qualification qualification,
    required List<String> questionCodes,
  }) async {
    if (questionCodes.isEmpty) return const [];
    final questions = await _questionsDatabase.loadQuestionsByCodes(
      databaseFileName: qualification.databaseFileName,
      questionCodes: questionCodes,
    );
    final byCode = <String, Question>{
      for (final question in questions) question.questionCode: question,
    };
    final ordered = questionCodes
        .map((code) => byCode[code])
        .whereType<Question>()
        .toList(growable: false);
    return _applyBookmarks(qualification.code, ordered);
  }

  Future<List<Question>> loadBookmarkedQuestions({
    required Qualification qualification,
  }) async {
    final codes = await _userDatabase.loadBookmarkedQuestionCodes(
      qualificationCode: qualification.code,
    );
    if (codes.isEmpty) return const [];
    final questions = await _questionsDatabase.loadQuestionsByCodes(
      databaseFileName: qualification.databaseFileName,
      questionCodes: codes.toList(growable: false),
    );
    return questions
        .map((question) => question.copyWith(isBookmarked: true))
        .toList(growable: false);
  }


  Future<Map<String, QuestionLearningStatus>> loadQuestionStatuses({
    required Qualification qualification,
    required List<Question> questions,
  }) {
    return _userDatabase.loadQuestionStatuses(
      qualificationCode: qualification.code,
      questionCodes: questions
          .map((question) => question.questionCode)
          .toList(growable: false),
    );
  }

  Future<void> setBookmark({
    required Qualification qualification,
    required Question question,
    required bool isBookmarked,
  }) {
    return _userDatabase.setBookmark(
      qualificationCode: qualification.code,
      questionCode: question.questionCode,
      isBookmarked: isBookmarked,
    );
  }

  Future<void> recordAnswer({
    required Qualification qualification,
    required Question question,
    required int selectedChoice,
  }) {
    return _userDatabase.recordAnswer(
      qualificationCode: qualification.code,
      questionCode: question.questionCode,
      selectedChoice: selectedChoice,
      isCorrect: question.isCorrectChoice(selectedChoice),
    );
  }

  Future<List<Question>> _applyBookmarks(
    String qualificationCode,
    List<Question> questions,
  ) async {
    if (questions.isEmpty) return questions;
    final bookmarkedCodes = await _userDatabase.loadBookmarkedQuestionCodes(
      qualificationCode: qualificationCode,
    );
    return questions
        .map(
          (question) => question.copyWith(
            isBookmarked: bookmarkedCodes.contains(question.questionCode),
          ),
        )
        .toList(growable: false);
  }
}
