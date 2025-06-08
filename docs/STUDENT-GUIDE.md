# 学生向け論文執筆ガイド

## はじめに

このガイドは、GitHub Desktop を使って論文執筆を進める学生向けの操作手順です。
Git の詳しい知識は必要ありません。GitHub Desktop の操作だけで論文執筆を完了できます。

## 前提条件

教員により以下が事前に準備されています：
- 個人用リポジトリの作成
- **LaTeX devcontainer 追加済み**
- 0th-draft ブランチの作成
- レビュー用PRの設定

## 基本的な流れ

1. **リポジトリをPCにクローン**
2. **0th-draft ブランチで目次案を作成・提出**
3. **自動作成された 1st-draft ブランチで第1稿を執筆・提出**
4. **教員の添削を確認し、必要に応じてSuggestionを適用**
5. **自動作成された 2nd-draft ブランチで第2稿を執筆**
6. **3稿目以降も同様に繰り返し（次稿ブランチは自動作成）**
7. **教員の指示で概要執筆開始**（論文本体がある程度完成した段階）

## 詳細な操作手順

### 1. リポジトリのクローン

1. 教員から通知されたリポジトリのURLにアクセス
2. `Code` ボタンをクリック
3. `Open with GitHub Desktop` をクリック
4. 保存場所を確認して `Clone` ボタンをクリック

### 2. 目次案の作成（0th-draft）

1. GitHub Desktop で `Current Branch` が `0th-draft` になっていることを確認
   - もし `main` になっている場合は `0th-draft` に切り替え
2. VSCode で [sotsuron.tex](sotsuron.tex) を編集し、`chapter`, `section`, `subsection` などを記述
3. **PDF の生成・プレビュー**
   - VSCode で ▷ ボタン（Build LaTeX project）をクリックして PDF を生成
   - 🔍 ボタン（View LaTeX PDF）をクリックして VSCode 内でプレビュー
4. GitHub Desktop で commit & push
5. GitHub Desktop で `Create Pull Request` をクリック
   - `Title` に **0th-draft** を記述
   - 説明や質問があれば記述
   - `Create pull request` をクリック

### 3. 第1稿の執筆（1st-draft）

#### 3.1 ブランチの切り替え

0th-draft のPRを作成すると、1st-draft ブランチが自動作成されます：

1. **自動作成されたブランチに切り替え**
   - GitHub Desktop で `Fetch origin` をクリック
   - `Current Branch` をクリックして一覧を表示
   - **`origin/1st-draft`** を選択
   - 「Create a new branch」が表示されるので、`Create branch` をクリック

#### 3.2 論文執筆

1. 現在のブランチが `1st-draft` であることを確認
2. `Open in Visual Studio Code` で編集開始
3. **LaTeX Workshop 拡張機能**を使って論文を執筆
   - `.tex` ファイルを開くと LaTeX Workshop が自動起動
   - ファイル保存時に `textlint` による自動チェックが起動
   - **問題** タブで textlint の指摘を確認し適宜対応
4. **PDF の生成・プレビュー**
   - VSCode で ▷ ボタン（Build LaTeX project）をクリックして PDF 生成
   - 🔍 ボタン（View LaTeX PDF）をクリックして VSCode 内でプレビュー
   - または F1 → `LaTeX Workshop: View PDF` でプレビュー
5. GitHub Desktop で commit & push
6. 執筆完了まで 1〜5 を繰り返し

#### 3.3 添削依頼

1. 印刷して推敲を実施
2. GitHub Desktop で `Create Pull Request` をクリック
3. `Title` に **1st-draft** を記述
4. 変更点などを説明欄に記述
5. `Create pull request` をクリック

### 4. 添削結果の確認

#### 4.1 コメントの確認

添削コメントは **2つのPR** で確認してください：

1. **あなたが作成したPR（1st-draft等）**
   - 直前版からの変更点に対するコメント
   - 新規追加部分への指摘

2. **レビュー用PR**
   - 論文全体に対するコメント
   - 以前の部分への追加指摘
   - 全体構成への意見

#### 4.2 Suggestionへの対応

教員からSuggestionがある場合：

1. **Suggestionの適用**
   ```
   GitHub Web画面で：
   1. suggestion右上の「Apply suggestion」ボタンをクリック
   2. 複数ある場合は「Add suggestion to batch」で一括適用
   3. 「Commit suggestions」でcommit実行
   ```

2. **適用完了の通知**
   ```
   PR画面で：
   1. 右側の「Reviewers」セクションを確認
   2. 教員名の横の🔄アイコンをクリック
   3. 「Re-request review」を選択
   ```

### 5. 次稿の準備（2nd-draft以降）

#### 5.1 自動ブランチ作成

**重要**: 0th-draft、1st-draft、2nd-draft のPRを作成すると、**次稿用ブランチが自動的に作成されます**。

1. **PRを作成すると自動実行**
   - 例：1st-draft のPR作成 → 2nd-draft ブランチが自動作成
   - PRのコメントに「🌿 次稿用ブランチを自動作成しました」と通知

2. **自動作成されたブランチに切り替え**
   - GitHub Desktop で `Fetch origin` をクリック
   - `Current Branch` をクリックして一覧を表示
   - **`origin/2nd-draft`** のように表示されているブランチを選択
   - 「Create a new branch」が表示されるので、`Create branch` をクリック

3. **手動作成が必要な場合のみ**（自動作成が失敗した場合）
   - 教員に相談してください

#### 5.2 効率的な執筆方法

**待機時間を短縮**: 前稿のPR提出後、教員のmerge完了を待たずに次稿の執筆を開始できます。

```
基本的な流れ：
1st-draft PR提出 → すぐに2nd-draft執筆開始
         ↓（並行して）
    教員レビュー・merge完了
         ↓
    2nd-draftを最新版に調整
```

#### 5.3 教員merge完了後の調整

教員から「mergeしました」の連絡があったら：

1. **最新版の取得**
   ```
   Current Branch → main に切り替え
   ↓
   [Fetch origin] ボタンをクリック
   ```

2. **執筆中ブランチの更新**
   ```
   Current Branch → 執筆中草稿ブランチ（例：2nd-draft）に切り替え
   ↓
   Branch → Update from main をクリック
   ```

3. **競合（Conflict）が発生した場合**
   - GitHub Desktop が自動的に競合解決画面を表示
   - 画面の指示に従って競合を手動で解決
   - 解決後、`Continue merge` をクリック

### 6. 概要の執筆（gaiyou.tex）

**重要**: 概要の執筆は、**教員から指示があったタイミング**で開始します。通常、論文本体がある程度完成した段階です。

#### 6.1 概要用ブランチの作成

1. **教員からの指示を待つ**
   - 教員が「概要執筆を開始してください」と指示

2. **最初のブランチは手動作成**
   - GitHub Desktop で `New Branch`
   - 名前: `abstract-1st`
   - ベース: **その時点で最新の稿ブランチ**（例：`5th-draft`）
   - `Create branch` → `Publish branch`

3. **PRを作成すると次のブランチが自動作成**
   - abstract-1st → abstract-2nd（自動、前版の概要を引き継ぎ）
   - abstract-2nd → abstract-3rd（自動、前版の概要を引き継ぎ）
   - 以降も同様
   
   **論文本体への反映**: 概要執筆後の論文本体（6th-draft以降）には、最新の概要が自動的に含まれます
   
   **ブランチの切り替え方法**:
   - GitHub Desktop で `Fetch origin` → `Current Branch` をクリック
   - **`origin/abstract-2nd`** のように表示されているブランチを選択
   - 「Create a new branch」で `Create branch` をクリック

#### 6.2 概要の執筆手順

1. `gaiyou.tex` を編集
2. 論文本体と同様にcommit & push
3. PR作成時のタイトル: `abstract-1st` など
4. 次稿は自動作成されたブランチで継続

### 7. 最終提出

教員からOKの返事が来たら：

1. **提出版にタグを付与**
   - GitHub Desktop の `History` で最新の履歴を右クリック
   - `Create Tag...` をクリック
   - `Name` に **submit** と入力
   - `Create Tag` → `Push origin` でタグをプッシュ

2. **印刷物の提出** も忘れずに実施

## よくある質問

### Q: ブランチを間違って作成した場合は？
A: 基本的にブランチは自動作成されるため、手動作成は不要です。問題がある場合は教員に相談してください。

### Q: commitを間違えた場合は？
A: 新しいcommitで修正するか、教員に相談してください。

### Q: 競合解決がうまくいかない場合は？
A: 教員に相談してください。一緒に解決方法を確認します。

### Q: Re-request reviewボタンが見つからない場合は？
A: PRがOpenの状態で、かつ教員が一度reviewしている必要があります。

### Q: PDFが生成されない場合は？
A: LaTeX コンパイルエラーが発生している可能性があります。以下を確認してください：
- VSCode の **問題** タブでエラー内容を確認
- LaTeX Workshop の **出力** タブでコンパイルログを確認
- 日本語の文字化けや未定義コマンドがないかチェック

### Q: LaTeX Workshop拡張機能が動作しない場合は？
A: 以下を確認してください：
- devcontainer環境で作業していることを確認
- VSCode左下に「Dev Container」の表示があることを確認
- 拡張機能タブで LaTeX Workshop が有効になっていることを確認

### Q: 自動作成されたブランチが見つからない場合は？
A: 以下の手順で確認してください：
1. GitHub Desktop で `Fetch origin` を実行
2. `Current Branch` をクリック
3. **`origin/`** で始まるブランチ名を探す（例：`origin/2nd-draft`）
4. 見つからない場合は、PRの自動作成が失敗している可能性があります

### Q: いつ概要の執筆を始めれば良いですか？
A: 教員からの指示を待ってください。通常、論文本体の構成が固まった段階（3rd-draft以降）で指示があります。その時点で最新の稿ブランチをベースにabstract-1stを作成します。


## 注意点

- **ブランチ名の命名**: 0th-draft → 1st-draft → 2nd-draft の順序を守る
- **自動作成ブランチ**: PRを作成すると次稿ブランチが自動作成される
- **commit頻度**: こまめにcommitして変更履歴を残す
- **PR作成**: 各稿の完成時に必ずPRを作成する
- **印刷推敲**: 画面だけでなく必ず印刷して確認する

## トラブル時の連絡先

質問があれば、遠慮なく smkwlabML ML へ連絡してください。
他の学生も同じ疑問を持っている可能性があります。
