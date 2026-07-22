# 更新方法

1. ZIPを展開します。
2. 中の `lib` フォルダを、現在のFlutterプロジェクトへ上書きします。
3. 次を実行してください。

```powershell
flutter analyze
flutter run
```

今回の変更対象は主に次のファイルです。

- `lib/features/mock_exam/mock_exam_screen.dart`

## 確認項目

- 模擬試験の問題画面下部に「一覧」が表示される
- 一覧を押すと科目別の問題番号一覧が開く
- 回答済み、未回答、現在位置の表示が異なる
- 任意の問題番号を押すと該当問題へ移動する
