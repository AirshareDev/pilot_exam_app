import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../shared/app_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '設定',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'アカウント',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.tune_rounded,
                title: '学習設定',
                subtitle: '出題・表示・回答後の動作',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.event_note_outlined,
                title: 'データ管理',
                subtitle: '学習履歴のバックアップ・復元',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.contrast_rounded,
                title: 'テーマ設定',
                subtitle: 'ライト / ダーク',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'お知らせ',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'アプリについて',
                subtitle: 'バージョン 0.24.0',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('この設定項目は今後実装予定です。')));
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, indent: 62),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Icon(icon, color: AppColors.navy, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
