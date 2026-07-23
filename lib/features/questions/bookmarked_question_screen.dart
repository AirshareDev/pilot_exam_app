import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_app_bar.dart';
import '../../models/qualification.dart';
import '../qualifications/qualification_provider.dart';
import '../qualifications/selected_qualification_provider.dart';
import 'random_question_screen.dart';

class BookmarkedQuestionScreen extends ConsumerWidget {
  const BookmarkedQuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualifications = ref.watch(qualificationsProvider);
    final selectedId = ref.watch(selectedQualificationIdProvider);

    return qualifications.when(
      loading: () => const _LoadingScreen(),
      error: (error, stackTrace) => _SelectionErrorScreen(
        message: error.toString(),
      ),
      data: (items) => selectedId.when(
        loading: () => const _LoadingScreen(),
        error: (error, stackTrace) => _SelectionErrorScreen(
          message: error.toString(),
        ),
        data: (id) {
          final qualification = _findQualification(items, id);
          if (qualification == null) {
            return const _SelectionErrorScreen(
              message: '選択中の資格を取得できませんでした。',
            );
          }
          return RandomQuestionScreen(
            qualification: qualification,
            bookmarkedOnly: true,
          );
        },
      ),
    );
  }
}

Qualification? _findQualification(
  List<Qualification> qualifications,
  int qualificationId,
) {
  for (final qualification in qualifications) {
    if (qualification.id == qualificationId) return qualification;
  }
  return null;
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SelectionErrorScreen extends StatelessWidget {
  const _SelectionErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppHomeButton(),
        automaticallyImplyLeading: false,
        title: const Text('ブックマーク'),
        flexibleSpace: const AppBarBackground(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                '資格を選択してから開いてください。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/qualifications'),
                child: const Text('資格を選択'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
