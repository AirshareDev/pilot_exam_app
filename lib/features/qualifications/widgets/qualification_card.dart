import 'package:flutter/material.dart';

import '../../../models/qualification.dart';

enum QualificationActionState {
  selected,
  selectable,
  purchasable,
}

class QualificationCard extends StatelessWidget {
  const QualificationCard({
    required this.qualification,
    required this.actionState,
    required this.onPressed,
    super.key,
  });

  final Qualification qualification;
  final QualificationActionState actionState;
  final VoidCallback? onPressed;

  bool get _isAvailable =>
      actionState != QualificationActionState.purchasable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = actionState == QualificationActionState.selected;

    return Card(
      margin: EdgeInsets.zero,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                _isAvailable ? Icons.menu_book_outlined : Icons.lock_outline,
                size: 24,
                color: _isAvailable
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  qualification.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 10),
              _ActionLabel(
                qualification: qualification,
                state: actionState,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.qualification,
    required this.state,
  });

  final Qualification qualification;
  final QualificationActionState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final String text;
    switch (state) {
      case QualificationActionState.selected:
        text = '選択中';
      case QualificationActionState.selectable:
        text = '選択する';
      case QualificationActionState.purchasable:
        text = '¥${_formatPrice(qualification.priceYen)}';
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: state == QualificationActionState.selected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: state == QualificationActionState.selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
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
