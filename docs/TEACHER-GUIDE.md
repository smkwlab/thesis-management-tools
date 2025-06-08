# 教員向け添削ワークフローガイド

## 概要

このガイドは、GitHub を使った論文添削の教員向け操作手順です。
ハイブリッドワークフローにより、差分レビューと全体レビューの両方を効率的に実施できます。

## ワークフロー概要

### ブランチ構成

```
initial-empty (空の初期状態) ← レビュー用PRのベース
 ├─ 0th-draft (目次案)
 ├─ 1st-draft (0th-draftベース) ← 差分明確
 ├─ 2nd-draft (1st-draftベース) ← 差分明確
 ├─ 3rd-draft (2nd-draftベース) ← 差分明確
 └─ review-branch (定期的に最新版をマージ)
```

### レビュー用PRの特徴

- **ベース**: `initial-empty` (空の初期状態)
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

### リポジトリ作成（自動化済み）

```bash
# 複数学生のリポジトリを一括作成
./create-student-repos.sh k21rs001 k21rs002 k21gjk01

# 自動的に以下が実行される：
# 1. リポジトリ作成（テンプレートから）
# 2. LaTeX devcontainer追加 (aldc)
# 3. initial-empty ブランチ作成（空の初期状態）
# 4. 0th-draft ブランチ作成（initial-emptyベース）
# 5. review-branch ブランチ作成（initial-emptyベース）
# 6. レビュー用PR作成（initial-empty → review-branch, do-not-mergeラベル付き）
```

### 手動設定が必要な項目

作成後、必要に応じて以下を設定：

1. **Collaboratorの追加**
   ```bash
   gh api repos/smkwlab/{repo-name}/collaborators/{username} \
     --method PUT \
     --field permission=write
   ```

2. **Branch protection rules**（推奨）
   - main ブランチの保護
   - PR required for merging

## 日常的な添削作業

### 1. 学生からPRが来たとき

#### A. 差分レビュー（各版のPR）

1. **PR内容の確認**
   ```bash
   # PRの詳細を確認
   gh pr view {pr-number}
   
   # 変更差分を確認
   gh pr diff {pr-number}
   ```

2. **レビュー実施**
   - GitHub Web UI でレビューを実施
   - 直前版からの変更部分にコメント
   - 必要に応じてSuggestionを使用

3. **Suggestionを使用する場合の注意**
   ```
   ✅ Do: Suggestionでコメント後、mergeせずに待機
   ❌ Don't: Suggestionがあるのに即座にmerge
   ```

#### B. 全体レビュー（必須）

**重要**: review-branchは GitHub Actions により自動更新されます。

1. **review-branchの自動更新**
   
   🔄 **完全自動化**: 学生がPRを作成すると、GitHub Actions が自動的にreview-branchを最新内容で更新します。
   
   ```yaml
   # .github/workflows/update-review-branch.yml で自動実行
   トリガー: 
   - PR作成時（opened）
   - PR更新時（synchronize） 
   - PR再開時（reopened）
   
   動作:
   1. 学生のPRブランチ内容を取得
   2. review-branchに自動マージ
   3. レビュー用PRを自動更新
   4. PRにコメントで通知
   ```
   
   📝 **教員の作業**: 特別な操作は不要です。学生がPRを作成すると自動的に以下が実行されます：
   - review-branchの更新
   - レビュー用PRへの反映
   - 通知コメントの投稿
   
   ⚠️ **トラブル時のみ**: 緊急時は `update-review-branch.sh` （非推奨）が利用可能です。

2. **レビュー用PRで全体レビュー実施**
   - 論文全体の構成確認
   - 以前の部分への追加指摘
   - 章を跨ぐ整合性の確認

#### レビューの使い分け例

```
0th-draft (目次案) 提出時:
1. 0th-draft PR: 目次構成のレビュー
2. GitHub Actions: 自動的にreview-branchを更新 ✅
3. レビュー用PR: 全体的な構成コメント

1st-draft 提出時:
1. 1st-draft PR: 0th-draftからの変更点レビュー  
2. GitHub Actions: 自動的にreview-branchを更新 ✅
3. レビュー用PR: 論文全体の内容確認（merge済み0th-draft含む）

2nd-draft 提出時:
1. 2nd-draft PR: 1st-draftからの変更点レビュー
2. GitHub Actions: 自動的にreview-branchを更新 ✅
3. レビュー用PR: 論文全体確認（merge済み1st-draft含む）
```

### 2. Suggestion対応フロー

#### 通常のレビューフロー

```
1. 教員: PRをレビュー、Suggestionでコメント
2. 学生: Apply suggestion → Re-request review 🔄
3. 教員: 確認・承認コメント
4. 学生: 対応完了後、自分でPRをクローズ ✅
5. 学生: 次稿執筆開始（並行作業可能）
```

**重要**: 教員はPRをマージしません。学生が自分でクローズします。

#### Re-request review受信後の対応

1. **通知の確認**
   ```
   📧 "Re-requested review on PR #3: 1st-draft"
   ```

2. **学生の適用内容を確認**
   ```bash
   # Commit historyでSuggestion適用を確認
   gh pr view {pr-number}
   ```

3. **問題なければ承認コメント**
   ```bash
   # Web UIまたはコマンドでコメント
   gh pr comment {pr-number} --body "修正内容を確認しました。対応完了後、PRをクローズしてください。"
   ```

4. **学生のPRクローズを待つ**
   
   ✅ **学生が自分でクローズ**: 対応完了後、学生が自分でPRをクローズします

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

### create-student-repos.sh

```bash
# 卒業論文リポジトリ作成
./create-student-repos.sh k21rs001 k21rs002 k21rs003

# 修士論文リポジトリ作成
./create-student-repos.sh k21gjk01 k21gjk02

# 混在も可能
./create-student-repos.sh k21rs001 k21gjk01 k21rs002
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

### パターン1: 役割分担型（推奨）

#### レビュアーの役割分担

```
主指導教員（Primary Reviewer）:
- 全体構成・内容の妥当性
- 研究手法・結果の評価
- 最終的な合否判断

副指導教員/先輩（Secondary Reviewer）:
- 文章表現・日本語
- LaTeX記法・体裁
- 参考文献の形式

第三者（External Reviewer）※任意:
- 客観的視点での確認
- 専門外の人への分かりやすさ
```

#### 作業手順

1. **学生がPR提出**
   ```bash
   # 通常通りPR作成
   gh pr create --title "1st-draft" --body "第1稿の提出"
   ```

2. **主指導教員が最初にレビュー**
   ```bash
   # Reviewersに副指導教員を追加
   gh pr edit {pr-number} --add-reviewer {sub-teacher-username}
   
   # 内容・構成をレビュー
   # 「Changes requested」または「Comment」でレビュー実施
   ```

3. **副指導教員が文章・体裁をレビュー**
   ```bash
   # 主指導教員のレビュー後に実施
   # textlint以外の日本語表現チェック
   # LaTeX記法の改善提案
   ```

4. **Suggestionの調整**
   ```
   ルール例:
   - 文章修正のSuggestion: 副指導教員が担当
   - 内容修正の指示: 主指導教員がコメントのみ
   - 学生は全Suggestion適用後にRe-request review
   ```

### パターン2: 段階的レビュー型

#### フェーズ分けでの対応

```
Phase 1 (構成確認): 主指導教員のみ
└─ 構成OKなら Phase 2 へ

Phase 2 (詳細確認): 主指導教員 + 副指導教員
└─ 文章・体裁を並行してレビュー

Phase 3 (最終確認): 全員
└─ 最終チェック・承認
```

#### GitHub上での運用

```bash
# Phase 1: 主指導教員のみをアサイン
gh pr create --title "1st-draft (Phase1: 構成確認)" 

# Phase 2: 副指導教員を追加
gh pr edit {pr-number} --add-reviewer {sub-teacher-username}
gh pr edit {pr-number} --title "1st-draft (Phase2: 詳細確認)"

# Phase 3: 外部レビュアーも追加（必要時）
gh pr edit {pr-number} --add-reviewer {external-reviewer}
gh pr edit {pr-number} --title "1st-draft (Phase3: 最終確認)"
```

### パターン3: 完全並行レビュー型

#### 同時レビューでの効率化

```bash
# 最初から全レビュアーをアサイン
gh pr create --title "1st-draft" \
  --reviewer {primary-teacher},{sub-teacher},{external-reviewer}
```

#### 競合回避のルール

```
コメント重複の防止:
- Primary: 章・節レベルの大きな指摘
- Secondary: 段落・文レベルの細かい指摘  
- External: 全体的な分かりやすさ

Suggestionの調整:
- 内容に関わるもの: Primary のみ
- 表現・体裁: Secondary のみ
- 学生への説明: 誰でも可
```

### 複数人レビュー時の設定

#### 1. GitHub設定の調整

```bash
# PR作成時のデフォルトレビュアー設定
# .github/CODEOWNERS に記載
* @primary-teacher @sub-teacher

# 必要な承認数の設定（2人以上など）
gh api repos/smkwlab/{repo}/branches/main/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":2}'
```

#### 2. GitHub Actions での複数人レビュー

```yaml
# .github/workflows/update-review-branch.yml
# 複数人レビュー時も自動更新で対応
# 特別な設定は不要
```

#### 3. 通知の管理

```
効率的な通知管理:
- GitHub通知設定でPR関連のみ有効化
- Slack/Teams連携でリアルタイム共有
- 週次進捗会議での一括確認
```

### 複数人レビューのベストプラクティス

#### レビュー品質の向上

```
1. 観点の明確化:
   各レビュアーが何を見るかを事前に決定

2. 重複排除:
   同じ指摘が複数人から出ないよう調整

3. 優先順位付け:
   Critical/Major/Minor での分類

4. 建設的フィードバック:
   改善案も合わせて提示
```

#### 学生への配慮

```
1. 混乱防止:
   相反する指摘がある場合は教員間で調整

2. 段階的修正:
   一度に大量の修正を求めない

3. 成長支援:
   なぜその修正が必要かの説明を重視

4. モチベーション維持:
   良い点も積極的に評価
```

### トラブル時の対処法

#### 教員間での意見相違

```bash
# PR上でのディスカッション
gh pr comment {pr-number} --body "@sub-teacher この部分についてどう思われますか？"

# 必要に応じてオフラインで議論
# 学生には統一見解を提示
```

#### レビュー遅延の対応

```
対策例:
- レビュー期限の明確化（48時間以内など）
- 代理レビュー体制の構築
- 緊急時の連絡方法確立
```

## 効率的な添削のコツ

### 1. レビューの使い分けパターン

```
目次案 (0th-draft):
→ 0th-draft PR で構成の相談・確認

第1稿 (1st-draft):
→ 1st-draft PR で新規執筆部分をレビュー
→ レビュー用PR で全体構成確認

第2稿以降:
→ 各版PR で変更点をレビュー（効率重視）
→ レビュー用PR で必要に応じて全体確認
```

### 2. Suggestionの効果的な使用

```
効果的なケース:
- 軽微な修正（誤字、表現改善）
- 具体的な修正提案がある場合

避けるべきケース:
- 大幅な構成変更
- 学生の理解が必要な概念的修正
```

### 3. 推奨スケジュール

```
月曜: 学生がPR提出
火曜: 教員がreview実施
水曜: 学生がsuggestion適用 + re-request（該当時）
木曜: 教員がmerge実行 + review-branch更新
金曜: 学生が次版執筆開始
```

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

## 最終提出時の処理

### 1. 提出版の確認

```bash
# submitタグの確認
git tag -l "*submit*"
git show submit

# 最終PDF生成確認
# GitHub Actions の実行状況確認
```

### 2. リポジトリのアーカイブ

```bash
# 提出完了後のアーカイブ（任意）
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