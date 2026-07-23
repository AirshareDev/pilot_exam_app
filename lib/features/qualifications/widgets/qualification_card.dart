import 'package:flutter/material.dart';

import '../../../design/app_colors.dart';
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

  bool get _isAvailable => actionState != QualificationActionState.purchasable;

  @override
  Widget build(BuildContext context) {
    final isSelected = actionState == QualificationActionState.selected;
    final accent = isSelected
        ? AppColors.green
        : _isAvailable
            ? AppColors.blue
            : AppColors.textSecondary;

    return Card(
      margin: EdgeInsets.zero,
      color: isSelected ? AppColors.green.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected ? AppColors.green : AppColors.border,
          width: isSelected ? 1.7 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isAvailable ? Icons.flight_outlined : Icons.lock_outline_rounded,
                  size: 25,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qualification.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (qualification.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        qualification.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _StatusTag(
                      qualification: qualification,
                      state: actionState,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: isSelected ? AppColors.green : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.qualification, required this.state});

  final Qualification qualification;
  final QualificationActionState state;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    final IconData icon;
    switch (state) {
      case QualificationActionState.selected:
        text = '選択中';
        color = AppColors.green;
        icon = Icons.check_rounded;
      case QualificationActionState.selectable:
        text = qualification.isFree ? '利用可能' : '購入済み';
        color = AppColors.blue;
        icon = Icons.lock_open_rounded;
      case QualificationActionState.purchasable:
        text = '未購入  ¥${_formatPrice(qualification.priceYen)}';
        color = AppColors.orange;
        icon = Icons.shopping_bag_outlined;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
