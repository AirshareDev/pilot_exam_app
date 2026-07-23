import 'package:flutter/material.dart';

import '../../shared/app_page.dart';

class AppUsageScreen extends StatelessWidget {
  const AppUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'このアプリの使い方',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: const [
          _UsageHeading('このアプリについて'),
          _UsageParagraph(
            '本アプリは、国土交通省が公開している操縦士学科試験の過去問題をもとに学習できる試験対策アプリです。\n\n'
            '資格ごとに年度別学習やランダム学習、模擬試験など、お好みの方法で効率よく学習できます。',
          ),
          _UsageHeading('学習方法'),
          _UsageItem(
            title: '年度別学習',
            body: '実際の試験問題を年度ごとに学習できます。\n本番と同じ問題構成で復習したい方におすすめです。',
          ),
          _UsageItem(
            title: '科目別学習',
            body: '苦手な科目だけを集中的に学習できます。',
          ),
          _UsageItem(
            title: 'ランダム学習',
            body: '登録されている問題からランダムに出題します。\n毎日の復習やスキマ時間の学習におすすめです。',
          ),
          _UsageItem(
            title: '模擬試験',
            body: '過去問題からランダムに1回分の試験を出題します。\n試験終了後は採点結果や正答率を確認できます。',
          ),
          _UsageItem(
            title: 'ブックマーク',
            body: '気になった問題や苦手な問題はブックマークできます。\n後からまとめて復習することができます。',
          ),
          _UsageItem(
            title: '学習履歴',
            body: '模擬試験の結果や学習履歴を保存します。\n過去の成績を確認しながら学習を進められます。',
          ),
          _UsageHeading('設定'),
          _UsageParagraph(
            '設定画面では文字サイズなど、学習しやすい表示に変更できます。',
          ),
          _UsageHeading('データについて'),
          _UsageParagraph(
            '問題データはアプリ内に保存されています。\n学習履歴やブックマークは端末内に保存されます。',
          ),
          _UsageHeading('ご利用にあたって'),
          _UsageParagraph(
            '本アプリは試験対策を目的とした学習支援アプリです。\n試験制度や出題内容は変更される場合があります。最新の情報は国土交通省の公式サイトをご確認ください。',
          ),
        ],
      ),
    );
  }
}

class _UsageHeading extends StatelessWidget {
  const _UsageHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _UsageItem extends StatelessWidget {
  const _UsageItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _UsageParagraph extends StatelessWidget {
  const _UsageParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
      ),
    );
  }
}
