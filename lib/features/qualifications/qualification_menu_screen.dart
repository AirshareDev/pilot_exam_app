import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/qualification.dart';
import '../../shared/app_page.dart';

class QualificationMenuScreen extends StatelessWidget {
  const QualificationMenuScreen({
    required this.qualification,
    super.key,
  });

  final Qualification qualification;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: qualification.name,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuCard(
            icon: Icons.shuffle,
            title: 'ランダム問題',
            description: '問題をランダムに20問出題します。',
            onTap: () => context.push(
              '/qualifications/${qualification.id}/random',
              extra: qualification,
            ),
          ),
          if (qualification.features.hasSubjects) ...[
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.category_outlined,
              title: '科目別',
              description: '科目を選んで一問一答で学習します。',
              onTap: () => context.push('/quick-practice'),
            ),
          ],
          if (qualification.features.hasExamSessions) ...[
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.calendar_month_outlined,
              title: '年度別過去問',
              description: '実施期ごとの過去問に取り組みます。',
              onTap: () => context.push('/past-exams'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
