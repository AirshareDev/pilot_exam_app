import 'package:flutter/material.dart';

import '../../../design/app_colors.dart';

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    required this.number,
    required this.text,
    required this.isSelected,
    required this.isAnswered,
    required this.isCorrect,
    required this.onTap,
    super.key,
  });

  final int number;
  final String text;
  final bool isSelected;
  final bool isAnswered;
  final bool isCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Colors.white;
    Color borderColor = AppColors.border;
    Color numberBackgroundColor = AppColors.blue.withValues(alpha: 0.10);
    Color numberForegroundColor = AppColors.navy;
    Color textColor = AppColors.textPrimary;
    IconData? trailingIcon;
    Color? trailingColor;

    if (isAnswered && isCorrect) {
      backgroundColor = AppColors.green.withValues(alpha: 0.075);
      borderColor = AppColors.green.withValues(alpha: 0.55);
      numberBackgroundColor = AppColors.green.withValues(alpha: 0.14);
      numberForegroundColor = const Color(0xFF15803D);
      textColor = const Color(0xFF166534);
      trailingIcon = Icons.check_circle_rounded;
      trailingColor = const Color(0xFF16A34A);
    } else if (isAnswered && isSelected && !isCorrect) {
      backgroundColor = AppColors.red.withValues(alpha: 0.065);
      borderColor = AppColors.red.withValues(alpha: 0.48);
      numberBackgroundColor = AppColors.red.withValues(alpha: 0.12);
      numberForegroundColor = const Color(0xFFDC2626);
      textColor = const Color(0xFF991B1B);
      trailingIcon = Icons.cancel_rounded;
      trailingColor = const Color(0xFFDC2626);
    } else if (isSelected) {
      backgroundColor = AppColors.navy.withValues(alpha: 0.055);
      borderColor = AppColors.navy.withValues(alpha: 0.65);
      numberBackgroundColor = AppColors.navy;
      numberForegroundColor = Colors.white;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: borderColor,
          width: isSelected || (isAnswered && isCorrect) ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAnswered ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: numberBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: numberForegroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: textColor, height: 1.5),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, color: trailingColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
