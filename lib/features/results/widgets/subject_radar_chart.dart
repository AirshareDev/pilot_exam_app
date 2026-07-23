import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/app_colors.dart';
import '../../../models/learning_results.dart';

class SubjectRadarChart extends StatelessWidget {
  const SubjectRadarChart({
    super.key,
    required this.subjects,
  });

  final List<SubjectLearningResult> subjects;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: subjects
          .map((subject) =>
              '${subject.subjectName} ${(subject.accuracy * 100).round()}パーセント')
          .join('、'),
      child: SizedBox(
        height: 300,
        child: CustomPaint(
          painter: _SubjectRadarPainter(
            subjects: subjects,
            colorScheme: Theme.of(context).colorScheme,
            textStyle: Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
          ),
        ),
      ),
    );
  }
}

class _SubjectRadarPainter extends CustomPainter {
  _SubjectRadarPainter({
    required this.subjects,
    required this.colorScheme,
    required this.textStyle,
  });

  final List<SubjectLearningResult> subjects;
  final ColorScheme colorScheme;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final axisCount = math.max(3, subjects.length);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.31;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.outlineVariant;
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.outlineVariant;
    final valuePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.blue.withValues(alpha: 0.18);
    final valueBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.blue;

    for (var level = 1; level <= 5; level++) {
      final path = Path();
      final levelRadius = radius * level / 5;
      for (var i = 0; i < axisCount; i++) {
        final point = _point(center, levelRadius, i, axisCount);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < axisCount; i++) {
      canvas.drawLine(center, _point(center, radius, i, axisCount), axisPaint);
    }

    final valuePath = Path();
    for (var i = 0; i < axisCount; i++) {
      final accuracy = i < subjects.length ? subjects[i].accuracy : 0.0;
      final point = _point(center, radius * accuracy.clamp(0, 1), i, axisCount);
      if (i == 0) {
        valuePath.moveTo(point.dx, point.dy);
      } else {
        valuePath.lineTo(point.dx, point.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, valuePaint);
    canvas.drawPath(valuePath, valueBorderPaint);

    for (var i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final labelPoint = _point(center, radius + 34, i, axisCount);
      final painter = TextPainter(
        text: TextSpan(
          text: '${subject.subjectName}\n${(subject.accuracy * 100).round()}%',
          style: textStyle.copyWith(color: colorScheme.onSurface),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 96);
      painter.paint(
        canvas,
        Offset(
          labelPoint.dx - painter.width / 2,
          labelPoint.dy - painter.height / 2,
        ),
      );
    }
  }

  Offset _point(Offset center, double radius, int index, int count) {
    final angle = -math.pi / 2 + 2 * math.pi * index / count;
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  @override
  bool shouldRepaint(covariant _SubjectRadarPainter oldDelegate) {
    return oldDelegate.subjects != subjects ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.textStyle != textStyle;
  }
}
