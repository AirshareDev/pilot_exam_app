import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    Color? backgroundColor;
    Color borderColor = colorScheme.outlineVariant;
    IconData? trailingIcon;

    if (isAnswered && isCorrect) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      trailingIcon = Icons.check_circle;
    } else if (isAnswered && isSelected && !isCorrect) {
      backgroundColor = colorScheme.errorContainer;
      borderColor = colorScheme.error;
      trailingIcon = Icons.cancel;
    } else if (isSelected) {
      backgroundColor = colorScheme.secondaryContainer;
      borderColor = colorScheme.secondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: borderColor,
          width: isSelected || (isAnswered && isCorrect) ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAnswered ? null : onTap,
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
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
