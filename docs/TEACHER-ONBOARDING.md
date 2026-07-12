# 教員向けオンボーディングガイド

## このガイドについて

本エコシステム（GitHub Pull Request ベースの論文添削ワークフロー）で**初めて論文指導を始める教員**向けの最初の一本道ガイドです。初回セットアップから最初のレビュー完了までを、最短経路で説明します。

日常の添削操作の詳細は [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md)、提出期の管理・スクリプト運用は [TEACHER-GUIDE.md](TEACHER-GUIDE.md) を参照してください。本ガイドは両者への入口です。

### ワークフローの全体像

```
学生: リポジトリ作成（ワンライナー1回）
  ↓
学生: 目次案を書いて 0th-draft PR を作成
  ↓
教員: PR 上でレビュー（コメント・承認）      ← 本ガイドの範囲はここまで
  ↓
学生: 対応後、自分で PR をクローズ → 1st-draft, 2nd-draft, … と繰り返し
  ↓
最終稿: final-* タグで自動マージ・提出確定（提出期の詳細は TEACHER-GUIDE.md）
```

各稿の PR では**直前版からの差分**を、自動更新される**レビュー用 PR** では**論文全体**をレビューします。

## 前提条件

- **GitHub アカウント**があり、**smkwlab organization のメンバー**であること
  - まだメンバーでない場合は、管理者（smkwlabML）に GitHub ユーザ名を伝えて招待を依頼してください
- GitHub CLI (`gh`) は**必須ではありません**。レビュー作業は GitHub の Web UI だけで完結できます
  - スクリプトによる一括管理を行う場合のみ [INSTALL-GH.md](INSTALL-GH.md) を参照

## Step 1: 学生にリポジトリを作らせる

学生自身に以下のワンライナーを実行してもらいます（卒業論文・修士論文の場合）：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/main/create-repo/setup.sh)" bash thesis
```

リポジトリが作成されると、以下が**すべて自動で**実行されます：

- ブランチ構成の初期化（`0th-draft` / `review-branch` など）とブランチ保護の設定
- 学生レジストリ（thesis-student-registry）への登録
- レビュアー（教員）のアサイン

**教員側の作業は何もありません。** 学生からの最初の PR を待つだけです。

## Step 2: 最初の PR（0th-draft）が来る

学生が目次案を書いて PR を作成すると、GitHub からメール通知が届きます：

```
[GitHub] k21rs001 opened PR #1: 0th-draft
```

通知メール内のリンクをクリックすると PR 画面が開きます（初回のみ GitHub へのログインが必要です）。

**通知が届かない場合**:

- GitHub の [Settings] → [Notifications] でメール通知が有効になっているか確認してください
- レビュアーにアサインされた PR は「Pull requests」の [Review requests](https://github.com/pulls/review-requested/@me) 画面からも一覧できます

**0th-draft で見るべき観点は「構成・章立てのみ」です。** 章立て・研究範囲・論理構成が妥当かを確認します。文章表現や詳細には踏み込みません（それは 1st-draft 以降の観点です）。

## Step 3: レビューする

最小手順は次の 4 ステップです：

1. PR 画面で **[Files changed]** タブを開く（緑 `+` が追加行、赤 `-` が削除行）
2. 指摘したい行の行番号をクリックし、コメントを記入して **[Start a review]**（または [Add single comment]）
3. コメントし終えたら画面右上の **[Review changes]** をクリック
4. **Approve**（問題なし）/ Comment / Request changes を選び **[Submit review]**

送信すると学生に自動通知されます。

行単位コメントの詳しい操作、Suggestion（修正提案）機能、複数教員での協力レビューは [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) を参照してください。

## Step 4: 承認後の流れを知っておく

**PR はマージしません。** 承認（またはコメント対応の完了）後は、**学生が自分で PR をクローズ**し、自動作成された次の draft ブランチ（1st-draft → 2nd-draft → …）で執筆を続けます。

- 学生 PR もレビュー用 PR も添削専用で、マージせず履歴として残します
- 次稿ブランチの作成やレビュー用 PR の更新は GitHub Actions が自動で行います

以降は Step 2〜4 の繰り返しです。各版の PR で差分をレビューし、自動更新されるレビュー用 PR で全体を確認します。

## 次に読むもの

- [PR-REVIEW-GUIDE.md](PR-REVIEW-GUIDE.md) — 日常の添削操作の正典（コメント・Suggestion・複数教員レビュー）
- [TEACHER-GUIDE.md](TEACHER-GUIDE.md) — 初期設定・スクリプト・提出プロセス管理の正典
- [PR-REVIEW-GUIDELINES](https://github.com/smkwlab/latex-ecosystem/blob/main/docs/PR-REVIEW-GUIDELINES.md) — エコシステム全体の添削ルールの正典（段階別レビュー観点など）

質問があれば smkwlabML で共有してください。
