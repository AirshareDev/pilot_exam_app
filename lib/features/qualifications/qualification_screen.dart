import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/qualification.dart';
import '../../shared/app_page.dart';
import 'purchase_provider.dart';
import 'qualification_provider.dart';
import 'selected_qualification_provider.dart';
import 'widgets/qualification_card.dart';

class QualificationScreen extends ConsumerWidget {
  const QualificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualifications = ref.watch(qualificationsProvider);
    final selectedId = ref.watch(selectedQualificationIdProvider);
    final purchasedCodes = ref.watch(purchasedQualificationCodesProvider);

    return AppPage(
      title: '資格を選択',
      body: qualifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(qualificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyView();

          return purchasedCodes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(
                purchasedQualificationCodesProvider,
              ),
            ),
            data: (purchased) {
              final currentId = selectedId.valueOrNull;

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(qualificationsProvider);
                  ref.invalidate(purchasedQualificationCodesProvider);
                  await Future.wait([
                    ref.read(qualificationsProvider.future),
                    ref.read(purchasedQualificationCodesProvider.future),
                  ]);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final qualification = items[index];
                    final isAvailable = qualification.isFree ||
                        purchased.contains(qualification.code);
                    final isSelected = currentId == qualification.id;
                    final actionState = isSelected
                        ? QualificationActionState.selected
                        : isAvailable
                            ? QualificationActionState.selectable
                            : QualificationActionState.purchasable;

                    return QualificationCard(
                      qualification: qualification,
                      actionState: actionState,
                      onPressed: isSelected
                          ? null
                          : () => _handleQualificationTap(
                                context: context,
                                ref: ref,
                                qualification: qualification,
                                isAvailable: isAvailable,
                              ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleQualificationTap({
    required BuildContext context,
    required WidgetRef ref,
    required Qualification qualification,
    required bool isAvailable,
  }) async {
    if (!isAvailable) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(qualification.name),
          content: Text(
            'この資格は¥${_formatPrice(qualification.priceYen)}の買い切りです。\n'
            '購入処理はストア課金実装時に接続します。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    await ref
        .read(selectedQualificationIdProvider.notifier)
        .selectQualification(qualification.id);

    if (!context.mounted) return;
    context.go('/');
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('利用できる資格が登録されていません。'),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

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
            const Text(
              '資格情報を読み込めませんでした。',
              textAlign: TextAlign.center,
            ),
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

String _formatPrice(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
