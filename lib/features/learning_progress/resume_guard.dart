import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/learning_session_progress.dart';
import 'learning_session_progress_provider.dart';

Future<bool> confirmDiscardInterruptedMockExam(
  BuildContext context,
  WidgetRef ref,
) async {
  final progress = await ref.read(learningSessionProgressStoreProvider).load();
  if (progress == null || progress.resumeType != ResumeType.mockExam) {
    return true;
  }
  if (!context.mounted) return false;

  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('中断中の模擬試験があります'),
      content: const Text(
        '新しく学習を開始すると、現在の模擬試験の中断データは破棄されます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('破棄して開始'),
        ),
      ],
    ),
  );

  if (discard != true) return false;
  await ref.read(learningSessionProgressStoreProvider).clear();
  ref.invalidate(learningSessionProgressProvider);
  return true;
}
