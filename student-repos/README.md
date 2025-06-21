# Student Repository Management

このディレクトリは学生論文リポジトリの管理に使用されます。

## ファイル説明

### pending-protection.txt
ブランチ保護設定待ちの学生リスト。
- setup.sh実行時に自動PR経由で学生IDが追加される
- 教員が一括でブランチ保護設定を実行するために使用

### completed-protection.txt  
ブランチ保護設定完了済みの学生リスト。
- 保護設定完了後に自動的に移動される
- 完了状況の確認に使用

## ファイル形式

```
k21rs001 # Created: 2024-XX-XX Repository: k21rs001-sotsuron
k21gjk01 # Created: 2024-XX-XX Repository: k21gjk01-thesis
```

## 使用方法

### 学生側（自動）
1. setup.sh実行
2. 自動でPRが作成され、pending-protection.txtに追加

### 教員側
1. PRをマージして学生リストを更新
2. 一括ブランチ保護設定を実行
3. 完了分がcompleted-protection.txtに移動

## 関連ツール

- `thesis-repo-manager.sh`: 学生リポジトリ状況の確認
- `scripts/bulk-setup-protection.sh`: 一括ブランチ保護設定