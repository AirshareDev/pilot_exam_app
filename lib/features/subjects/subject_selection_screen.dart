import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_app_bar.dart';
import '../../models/qualification.dart';
import '../../models/subject.dart';
import '../qualifications/selected_qualification_provider.dart';
import '../learning_progress/resume_guard.dart';
import 'subject_provider.dart';

class SubjectSelectionScreen extends ConsumerWidget {
  const SubjectSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedQualification = ref.watch(selectedQualificationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppHomeButton(),
        automaticallyImplyLeading: false,
        title: const Text('科目別'),
        actions: const [AppHomeActionButton()],
        flexibleSpace: const AppBarBackground(),
      ),
      body: selectedQualification.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(selectedQualificationProvider),
        ),
        data: (qualification) {
          if (qualification == null) return const _EmptyQualificationView();
          return _SubjectBody(qualification: qualification);
        },
      ),
    );
  }
}

class _SubjectBody extends ConsumerWidget {
  const _SubjectBody({required this.qualification});

  final Qualification qualification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider(qualification));

    return subjects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(subjectsProvider(qualification)),
      ),
      data: (items) {
        if (items.isEmpty) return const _EmptyView();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(subjectsProvider(qualification));
            await ref.read(subjectsProvider(qualification).future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, index) =>
                index == 0 ? const SizedBox(height: 12) : const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _QualificationHeader(qualification: qualification);
              }

              final subject = items[index - 1];
              return _SubjectTile(
                subject: subject,
                onTap: subject.questionCount <= 0
                    ? null
                    : () async {
                        if (!await confirmDiscardInterruptedMockExam(context, ref)) {
                  return;
                }
                        if (!context.mounted) return;
                        context.push(
                          '/quick-practice/${qualification.id}/${subject.id}',
                          extra: SubjectRouteArguments(
                            qualification: qualification,
                            subjectName: subject.name,
                          ),
                        );
                      },
              );
            },
          ),
        );
      },
    );
  }
}

class _QualificationHeader extends StatelessWidget {
  const _QualificationHeader({required this.qualification});

  final Qualification qualification;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.menu_book_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            qualification.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, required this.onTap});

  final Subject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      enabled: enabled,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        child: Text(subject.name.isEmpty ? '科' : subject.name.substring(0, 1)),
      ),
      title: Text(subject.name),
      subtitle: Text('${subject.questionCount}問'),
      trailing: enabled
          ? const Icon(Icons.chevron_right)
          : const Text('問題なし'),
    );
  }
}

class SubjectRouteArguments {
  const SubjectRouteArguments({
    required this.qualification,
    required this.subjectName,
  });

  final Qualification qualification;
  final String subjectName;
}

class _EmptyQualificationView extends StatelessWidget {
  const _EmptyQualificationView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('資格が選択されていません。'),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('この資格には科目が登録されていません。'),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text('科目を読み込めませんでした。', textAlign: TextAlign.center),
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
