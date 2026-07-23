import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/user_database.dart';
import '../../design/app_colors.dart';
import '../../shared/app_page.dart';
import '../qualifications/selected_qualification_provider.dart';
import '../results/results_provider.dart';
import 'app_settings_provider.dart';
import 'app_usage_screen.dart';

const _sourceUrl =
    'https://www.mlit.go.jp/koku/koku_fr10_000025.html';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return AppPage(
      title: '設定',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const _SectionLabel('購入'),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: '購入記録と復元',
                subtitle: '購入済み資格の確認・復元',
                onTap: () => _showInfo(
                  context,
                  title: '購入記録と復元',
                  message: 'ストア課金の接続後に、購入記録の表示と復元処理を実装します。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('学習設定'),
          _SettingsSection(
            children: [
              _SwitchTile(
                icon: Icons.check_circle_outline_rounded,
                title: '正解後に次の問題へ進む',
                subtitle: '通常学習で正解した場合に自動で移動',
                value: settings.advanceAfterCorrect,
                onChanged: (value) => controller.update(
                  settings.copyWith(advanceAfterCorrect: value),
                ),
              ),
              _SwitchTile(
                icon: Icons.timer_outlined,
                title: '模擬試験で回答後に次へ進む',
                subtitle: '選択肢をタップした後に自動で移動',
                value: settings.advanceAfterMockAnswer,
                onChanged: (value) => controller.update(
                  settings.copyWith(advanceAfterMockAnswer: value),
                ),
              ),
              _SettingsTile(
                icon: Icons.tune_rounded,
                title: '模擬試験のデフォルト設定',
                subtitle:
                    '${settings.defaultMockQuestionCount}問・${settings.defaultMockDurationMinutes}分・${settings.defaultMockRandom ? 'ランダム出題' : '年度期別過去問'}',
                onTap: () => _showMockDefaults(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('表示設定'),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.text_fields_rounded,
                title: '文字サイズ',
                subtitle: _textScaleLabel(settings.textScale),
                onTap: () => _showTextScale(context, ref, settings),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('データの初期化'),
          _SettingsSection(
            children: [
              _DangerTile(
                icon: Icons.assessment_outlined,
                title: '模擬試験結果のリセット',
                onTap: () => _confirmReset(
                  context,
                  ref,
                  title: '模擬試験結果をリセットしますか？',
                  message: '保存されている模擬試験の結果と科目別集計を削除します。',
                  action: (db, code) =>
                      db.resetExamResults(qualificationCode: code),
                ),
              ),
              _DangerTile(
                icon: Icons.history_rounded,
                title: '回答履歴のリセット',
                onTap: () => _confirmReset(
                  context,
                  ref,
                  title: '回答履歴をリセットしますか？',
                  message: '通常学習の回答履歴を削除します。問題ごとの正答回数は残ります。',
                  action: (db, code) =>
                      db.resetAnswerHistory(qualificationCode: code),
                ),
              ),
              _DangerTile(
                icon: Icons.delete_forever_outlined,
                title: 'すべての回答をリセット',
                onTap: () => _confirmReset(
                  context,
                  ref,
                  title: 'すべての回答をリセットしますか？',
                  message: '模擬試験結果、回答履歴、問題ごとの正答・不正答記録を削除します。ブックマークは残ります。',
                  action: (db, code) =>
                      db.resetAllAnswers(qualificationCode: code),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('出典'),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.account_balance_outlined,
                title: '国土交通省',
                subtitle: '航空従事者等学科試験解答及び過去問',
                onTap: () => _showSource(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('アプリ情報'),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.menu_book_outlined,
                title: 'このアプリの使い方',
                subtitle: '学習方法とデータの保存について',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppUsageScreen(),
                  ),
                ),
              ),
              const _StaticTile(
                icon: Icons.info_outline_rounded,
                title: 'バージョン',
                trailing: '0.24.0',
              ),
              _SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'お問い合わせ',
                subtitle: '不具合・ご要望について',
                onTap: () => _showInfo(
                  context,
                  title: 'お問い合わせ',
                  message: 'お問い合わせ先は公開時のサポート窓口に差し替えてください。',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _textScaleLabel(double value) {
    if (value <= 0.8) return '小';
    if (value >= 1.0) return '大';
    return '標準';
  }


  static Future<void> _showMockDefaults(
    BuildContext context,
    WidgetRef ref,
    AppSettings current,
  ) async {
    var questionCount = current.defaultMockQuestionCount;
    var duration = current.defaultMockDurationMinutes;
    var random = current.defaultMockRandom;
    final result = await showModalBottomSheet<AppSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('模擬試験のデフォルト設定',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                const Text('問題数'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 20, label: Text('20問')),
                    ButtonSegment(value: 50, label: Text('50問')),
                    ButtonSegment(value: 100, label: Text('100問')),
                  ],
                  selected: {questionCount},
                  onSelectionChanged: (values) =>
                      setSheetState(() => questionCount = values.first),
                ),
                const SizedBox(height: 18),
                const Text('制限時間'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 15, label: Text('15分')),
                    ButtonSegment(value: 30, label: Text('30分')),
                    ButtonSegment(value: 45, label: Text('45分')),
                    ButtonSegment(value: 60, label: Text('60分')),
                  ],
                  selected: {duration},
                  onSelectionChanged: (values) =>
                      setSheetState(() => duration = values.first),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ランダム出題'),
                  value: random,
                  onChanged: (value) => setSheetState(() => random = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(
                    current.copyWith(
                      defaultMockQuestionCount: questionCount,
                      defaultMockDurationMinutes: duration,
                      defaultMockRandom: random,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      await ref.read(appSettingsProvider.notifier).update(result);
    }
  }

  static Future<void> _showTextScale(
    BuildContext context,
    WidgetRef ref,
    AppSettings current,
  ) async {
    final value = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<double>(
          groupValue: current.textScale,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<double>(
                value: 0.8,
                title: Text('小'),
              ),
              RadioListTile<double>(
                value: 0.9,
                title: Text('標準'),
              ),
              RadioListTile<double>(
                value: 1.0,
                title: Text('大'),
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (value != null) {
      await ref.read(appSettingsProvider.notifier)
          .update(current.copyWith(textScale: value));
    }
  }


  static Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<void> Function(UserDatabase db, String qualificationCode)
        action,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('リセット'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final qualification = await ref.read(selectedQualificationProvider.future);
    if (qualification == null) {
      if (context.mounted) {
        _showSnack(context, '対象の資格が選択されていません。');
      }
      return;
    }
    await action(ref.read(userDatabaseProvider), qualification.code);
    ref.invalidate(learningResultsProvider);
    if (context.mounted) _showSnack(context, 'データをリセットしました。');
  }

  static Future<void> _showSource(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('出典'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('国土交通省：航空従事者等学科試験解答及び過去問'),
            SizedBox(height: 12),
            SelectableText(_sourceUrl),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _sourceUrl));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) _showSnack(context, 'URLをコピーしました。');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('URLをコピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  static void _showInfo(BuildContext context,
      {required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
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
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Icon(icon, color: AppColors.navy),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        secondary: Icon(icon, color: AppColors.navy),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Icon(icon, color: AppColors.red),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.red, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _StaticTile extends StatelessWidget {
  const _StaticTile({required this.icon, required this.title, required this.trailing});
  final IconData icon;
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Icon(icon, color: AppColors.navy),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Text(trailing),
      );
}
