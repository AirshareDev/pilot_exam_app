# v0.18.0 更新手順

1. ZIPを展開します。
2. 現在の `pilot_exam_app` フォルダへ全ファイルを上書きします。
3. 次を実行します。

```powershell
flutter pub get
flutter analyze
flutter run
```

## 模擬試験の流れ

1. 模擬試験
2. 本試験モードまたは練習モード
3. 試験科目を確認
4. 「始める」
5. 科目名と問題数を確認
6. その科目の問題を順番に回答
7. 次の科目へ移る前に、次の科目名と問題数を表示
8. 全科目終了後に採点

現在は5科目、各10問、原則50問です。
将来20問へ変更する場合は、`MockExamConfig.questionsPerSubject` を20へ変更します。
