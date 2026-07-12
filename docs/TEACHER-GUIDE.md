# 教員向け添削ワークフローガイド

> **本書の位置づけ**: 初期設定・スクリプト・提出プロセス管理・セキュリティは本書が正典です。
> 日常のレビュー操作（コメント・Suggestion・複数教員レビュー）は [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md)、初回の全体像は [TEACHER-ONBOARDING.md](TEACHER-ONBOARDING.md) を参照してください。

## 概要

このガイドは、GitHub を使った論文添削ワークフローの教員向け運用・管理ガイドです。
ハイブリッドワークフローにより、差分レビューと全体レビューの両方を効率的に実施できます。

## ワークフロー概要

### ブランチ構成

```
initial (初期状態) ← レビュー用PRのベース
 ├─ 0th-draft (目次案)
 ├─ 1st-draft (0th-draftベース) ← 差分明確
 ├─ 2nd-draft (1st-draftベース) ← 差分明確
 ├─ 3rd-draft (2nd-draftベース) ← 差分明確
 └─ review-branch (定期的に最新版をマージ)
```

### レビュー用PRの特徴

- **ベース**: `initial` (初期状態)
- **ヘッド**: `review-branch` (GitHub Actionsで自動更新)
- **目的**: 論文全体への添削（merge済み箇所含む）
- **運用**: 絶対にマージしない、最終提出まで維持

### レビューの使い分け

| コメントの種類 | 使用するPR |
| ------------ | ----------- |
| 目次案への指摘 | 0th-draft PR |
| 直前版からの変更点 | 各版のPR (1st-draft等) |
| 論文全体の構成 | レビュー用PR |
| merge済み箇所への追加指摘 | レビュー用PR |
| 章を跨ぐ整合性の確認 | レビュー用PR |
| 最終提出前の全体確認 | レビュー用PR |

## 初期設定

### リポジトリ作成（学生自身で実行）

学生は以下のDockerベースのワンライナーでリポジトリを作成します：

```bash
# 学生が実行するコマンド（Homebrewスタイル・論文リポジトリの例）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/main/create-repo/setup.sh)" bash thesis
```

**自動実行される内容**：
1. GitHub認証（ブラウザ経由）
2. リポジトリ作成（テンプレートから）
3. LaTeX devcontainer追加 (aldc)
4. initial ブランチ作成（リポジトリ作成直後の状態）
5. 0th-draft ブランチ作成（initialベース）
6. review-branch ブランチ作成（initialベース）
7. レビュー用PR作成（initial → review-branch, do-not-mergeラベル付き）

### 教員側の設定作業

学生のリポジトリ作成後、必要に応じて以下を設定：

1. **mainブランチ保護設定**（推奨）
   ```bash
   # 教員用ブランチ保護ツール
   ./scripts/setup-branch-protection.sh k21rs001-sotsuron k21rs002-sotsuron
   
   # 個別設定
   ./scripts/setup-branch-protection.sh k21rs001-sotsuron
   ```

2. **Collaboratorの追加**（必要時）
   ```bash
   gh api repos/smkwlab/{repo-name}/collaborators/{username} \
     --method PUT \
     --field permission=write
   ```

## 日常的な添削作業

日々のレビュー操作の詳細な手順（差分の見方・コメント・Suggestion・レビュー送信）は
[PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) が正典です。ここでは運用上の要点のみまとめます。

### 1. 学生からPRが来たとき

- **差分レビュー（各版のPR）**: 直前版からの変更点をレビューします。
  操作手順は [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) の「基本的な添削手順」を参照。
- **全体レビュー（レビュー用PR）**: review-branch は GitHub Actions
  （`.github/workflows/update-review-branch.yml`、PR の opened / synchronize / reopened で発火）が
  自動更新するため、教員側の操作は不要です。レビュー用PRで全体構成・章を跨ぐ整合性・merge済み箇所への
  追加指摘を行います。使い分けは [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) の「レビュー用PRの活用」を参照。
  トラブル時のみ `update-review-branch.sh`（非推奨、後述の「スクリプト活用」）が利用可能です。

### 2. Suggestion対応フロー

Suggestion 提示後は学生の適用と Re-request review を待ち、確認後に承認コメントします。
**教員はPRをマージしません。学生が自分でクローズします。**
詳細フローは [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) の「Suggestion対応フロー」を参照。

### 3. 並行作業時のサポート

学生が並行作業をしている場合のサポート手順：

#### 学生向け指示

```
学生への標準的な指示：
「1st-draft PR提出後、すぐに次稿執筆を開始できます。
2nd-draftブランチは自動作成されているので、以下の手順で進めてください：
1. GitHub Desktop で Fetch origin をクリック
2. Current Branch → origin/2nd-draft を選択してブランチ作成
3. 次稿執筆開始
4. 前稿の添削対応完了後、自分でPRをクローズしてください」
```

#### 注意事項

```
PRをマージしない運用のメリット：
- 競合解決不要：PRをマージしないため競合は発生しません
- 並行作業自由：いつでも次稿執筆開始可能
- シンプル操作：学生の複雑なGit操作は不要
- 完全履歴：全PRが保持され、完全な変遷記録となります
```

## スクリプト活用

### setup-branch-protection.sh（教員用）

```bash
# 複数リポジトリのブランチ保護設定
./scripts/setup-branch-protection.sh k21rs001-sotsuron k21rs002-sotsuron k21gjk01-thesis

# 個別リポジトリの設定
./scripts/setup-branch-protection.sh k21rs001-sotsuron

# 機能:
# - mainブランチ保護（PR必須、1承認必要）
# - GitHub Actions自動マージ許可
# - final-*タグ時の自動マージ対応
```

### update-review-branch.sh（非推奨）

⚠️ **GitHub Actions による自動更新を推奨**

緊急時やトラブルシューティング用として残されています：

```bash
# 緊急時のみ使用
./update-review-branch.sh k21rs001-sotsuron 1st-draft

# 学生リポジトリディレクトリ内で実行
cd k21rs001-sotsuron
../update-review-branch.sh 1st-draft
```

## 複数人レビューの運用方法

役割分担（主指導・副指導・外部）、順次/並行/段階的レビューの各パターン、CODEOWNERS や必要承認数の
GitHub 設定、通知管理、レビュー遅延時の対応は、[PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) の
「複数教員での添削」を参照してください。教員間で意見が相違した場合は PR 上で協議し、学生には統一見解を提示します。

## 効率的な添削のコツ

差分レビューと全体レビューの使い分け、Suggestion の効果的な使用、優先順位付け、週次の推奨スケジュールは、
[PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) の「レビュー用PRの活用」「効率的な添削のコツ」を参照してください。

## トラブルシューティング

### よくある問題と対処法

#### 1. レビュー用PRでコンフリクト

```bash
# review-branchをリセット
git checkout review-branch
git reset --hard 0th-draft
git merge origin/{latest-student-branch}
git push --force-with-lease
```

#### 2. 学生のブランチ作成ミス

```bash
# 正しいベースブランチを指定してブランチ作成支援
git checkout {correct-base-branch}
git checkout -b {new-branch-name}
git push -u origin {new-branch-name}
```

#### 3. aldc実行ファイルの残留

```bash
# 一時ファイルの削除
find . -name "*-aldc" -type f -delete
```

## セキュリティとベストプラクティス

### 1. リポジトリアクセス管理

- プライベートリポジトリの確認
- 必要最小限のCollaborator設定
- 定期的なアクセス権限見直し

### 2. ブランチ保護

```bash
# main ブランチ保護設定例
gh api repos/smkwlab/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'
```

### 3. バックアップ

```bash
# 重要な節目でのバックアップ
git tag v1.0-{student-id}-submit
git push origin v1.0-{student-id}-submit
```

## 提出プロセス管理

論文提出は **2段階のプロセス** で管理します：

### 第1段階: 論文提出許可

#### 1. 論文本体の完成度判定

```bash
# 学生の論文内容を確認
# レビュー用PRで全体チェック
# 各版PRで変更内容チェック
```

#### 2. 提出許可の指示

論文本体が提出レベルに達したと判断した場合：

```
学生への指示例：
「論文本体の内容が提出レベルに達しました。
現在のドラフトに submit タグを作成し、概要の執筆を開始してください。」
```

#### 3. submit タグの確認

```bash
# 学生が作成したsubmitタグを確認
git tag -l "*submit*"
git show submit

# この段階ではmainブランチにマージされません
```

### 第2段階: 概要執筆・添削

#### 1. 概要執筆の指導

```bash
# 概要用ブランチの確認
git branch -r | grep abstract

# 概要PRのレビュー
gh pr list --label abstract
```

#### 2. 概要完成の判定

概要の内容が適切になったタイミングで、口頭で最終段階に進むことを伝えます。

### 第3段階: 最終版完成・自動マージ（口頭指示）

#### 1. 最終版判定後の指示

概要完成後、論文の最終改善を経て最終版と判定した場合：

```
学生への指示例（口頭）：
「最終版として問題ありません。
review-branch → main のPRを作成し、承認後にfinal-2ndタグを作成してください。」
```

#### 2. 最終提出PRの処理

```bash
# 学生が作成するPR
Base: main
Head: review-branch
Title: "Final Submission Request"

# PR内容の確認・承認（まだマージはしない）
gh pr review {pr-number} --approve --body "最終版として承認します。final tagを作成してください。"
```

#### 3. final tag による自動マージ

学生が `final-*` タグを作成すると、以下が自動実行されます：

```yaml
自動実行内容:
1. 承認済みPRの検出
2. 自動マージ実行（main ブランチへ）
3. GitHub Release 自動作成
4. 提出完了通知
```

#### 4. 提出完了の確認

```bash
# final tagの確認
git tag -l "final-*"
git show final-2nd

# GitHub Release の確認
gh release list

# main ブランチにマージされたことを確認
gh pr list --state merged --base main
```

### 段階別タグの意味

- **submit タグ**: 論文本体の提出許可版（mainにマージされない）
- **final タグ**: 最終完成版（mainに自動マージ、GitHub Release作成）

### トラブル時の対応

```bash
# ワークフロー実行状況の確認
gh run list --workflow="Auto Final Merge"

# ワークフロー失敗時の手動マージ
gh pr merge {pr-number} --merge
gh release create final-2nd --title "Final Submission: final-2nd"

# リポジトリアーカイブ（任意）
gh repo archive smkwlab/{student-repo}
```

## その他

### GitHub Actions設定

- PDF自動生成の確認
- Reviewer自動アサインの確認
- **次稿ブランチ自動作成の確認**（create-next-draft.yml）
- 必要に応じてworkflow調整

### 学生指導のポイント

- GitHub Desktopの基本操作支援
- ブランチ概念の簡単な説明
- commit頻度の指導
- 印刷推敲の重要性
- **概要執筆の指示タイミング**: 
  - 論文本体の骨格が固まった段階（推奨：3rd-draft以降）
  - 大きな構成変更の可能性が低くなった時点
  - 学生に指示：「概要執筆を開始してください」
- **abstract-1stブランチ**: 学生が手動作成（**その時点の最新稿ベース**）
- **abstract-2nd以降**: 自動作成時に最新稿ブランチから作成
  - 例：7th-draftが最新なら、abstract-2ndは7th-draftベース
  - 利点：常に最新の論文本体を含むため、整合性が保たれる
- **自動作成ブランチの切り替え**: 
  - GitHub Desktopでは `origin/xxx-draft` として表示
  - 学生には「originが付いているブランチを選択」と指導

### 概要執筆指示の例

#### 指示のタイミング例
```
5th-draftをレビューした結果、論文の基本構成が固まったと判断した場合：

学生への指示例：
「論文本体の構成が固まりましたので、概要の執筆を開始してください。
現在の最新稿をベースにabstract-1stブランチを作成し、gaiyou.texの執筆を進めてください。
概要では、研究の背景・目的・手法・結果・結論を400字程度でまとめてください。」
```

#### 判断基準
- ✅ 章立てが確定している
- ✅ 主要な実験・検証が完了している  
- ✅ 結論の方向性が固まっている
- ❌ まだ大きな構成変更の可能性がある

質問がある場合は smkwlabML で共有し、ノウハウを蓄積していきましょう。

## 関連ドキュメント

- [TEACHER-ONBOARDING.md](TEACHER-ONBOARDING.md): 初めての教員向けオンボーディング（最初の1時間で読む文書）
- [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md): 日常のレビュー操作の正典（コメント・Suggestion・複数教員レビュー）
- [PR-REVIEW-GUIDELINES](https://github.com/smkwlab/latex-ecosystem/blob/main/docs/PR-REVIEW-GUIDELINES.md): エコシステム全体の添削ルールの正典