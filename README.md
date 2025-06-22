# Thesis Management Tools

論文執筆ワークフローの管理ツールとガイドドキュメント集です。
GitHub を使った効率的な論文指導をサポートします。

## 対象ユーザー

- **学生**: 論文執筆・提出
- **教員**: 論文添削・指導
- **管理者**: レビューワークフロー管理
- **TA・先輩**: 副指導・レビュー支援

## 🎓 学生の方へ

**論文執筆用リポジトリの作成方法**

### 📋 セットアップスクリプトを使用

**前提条件:**
- Windows: WSL + Docker Desktop
- macOS: Docker Desktop
- GitHub CLI（推奨、認証を大幅に簡素化）

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

**実行手順:**
1. GitHub CLI がある場合：
   - `gh auth login` でGitHubにログイン
   - 上記コマンドを実行（自動認証）
2. GitHub CLI がない場合：
   - 上記コマンドを実行
   - GitHub認証：ワンタイムコードをブラウザで入力
3. 学籍番号を入力
4. 自動でリポジトリ作成・セットアップ完了

**複数GitHubアカウントがある場合:**
```bash
# アカウント切り替え
gh auth switch --user your-username

# または個人アカウントに作成
TARGET_ORG=your-username /bin/bash -c "$(curl -fsSL ...)"
```

### 📚 手動テンプレート使用
1. [sotsuron-template](https://github.com/smkwlab/sotsuron-template) にアクセス
2. 「Use this template」をクリック
3. リポジトリ名を `学籍番号-sotsuron` 形式で入力
4. 手動でLaTeX環境をセットアップ

## 📁 構成

### `docs/` - ガイドドキュメント


- **[TEACHER-GUIDE.md](docs/TEACHER-GUIDE.md)**: 教員向け添削・管理ガイド
  - レビューワークフローの詳細
  - 複数教員での協力添削
  - GitHub Actions 自動化の活用

- **[PR-REVIEW-GUIDE.md](docs/PR-REVIEW-GUIDE.md)**: GitHub PR 初心者向け添削ガイド
  - PR の基本概念
  - コメント・Suggestion の使い方
  - 複数教員での効率的な連携

### `scripts/` - 運用ツール

- **[setup-branch-protection.sh](scripts/setup-branch-protection.sh)**: mainブランチ保護設定（教員用）
  - main ブランチの誤操作防止
  - GitHub Actions自動マージ許可
  - final-*タグ時の自動マージ対応

- **[update-review-branch.sh](scripts/update-review-branch.sh)**: レビューブランチ手動更新（緊急用）
  - GitHub Actions 障害時の緊急用
  - トラブルシューティング用

### `create-repo/` - リポジトリ作成ツール

- **[setup.sh](create-repo/setup.sh)**: リポジトリ作成スクリプト
  - Docker-based zero-dependency setup
  - クロスプラットフォーム対応
  - ブラウザ認証統合

- **[main.sh](create-repo/main.sh)**: Docker内実行メインスクリプト
  - GitHub認証・リポジトリ作成
  - LaTeX環境自動セットアップ
  - ブランチ構造初期化

## 🚀 クイックスタート

### 1. 学生のリポジトリ作成

学生自身がスクリプトを使って論文リポジトリを作成：

```bash
# リポジトリ作成スクリプト実行
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

### 2. 添削ワークフローの開始

1. **学生がPR作成** → 自動的に以下が実行:
   - 次稿ブランチ自動作成
   - レビューブランチ自動更新
   - レビュー用PR自動更新

2. **教員が添削実施**:
   - 個別PR: 差分レビュー
   - レビュー用PR: 全体レビュー

3. **学生がPRをクローズ**:
   - 添削対応完了後、自分でPRをクローズ
   - 並行して次稿執筆継続可能

4. **PRはマージしません**: 添削専用として活用、学生が自分でクローズ

## 📚 対応テンプレート

このツールセットは以下のテンプレートで使用できます:

- **[sotsuron-template](https://github.com/smkwlab/sotsuron-template)**: 卒業論文・修士論文用

## 🔧 主要機能

### 論文リポジトリ作成・管理

- ✅ **自動リポジトリ作成**: Docker経由での依存関係なしセットアップ
- ✅ **ブランチ保護設定**: 教員レビュー必須の安全なワークフロー
- ✅ **Issue自動管理**: ブランチ保護設定依頼の自動化
- ✅ **一括管理機能**: 複数学生のリポジトリを効率的に管理

#### 管理システムアーキテクチャ（2025-06-22統一）
- **データ統一管理**: `data/` ディレクトリで一元管理
- **学生レジストリ**: `data/students/` で年度別・タイプ別管理
- **保護状況追跡**: `data/protection-status/` で設定状況を追跡
- **GitHub Actions連携**: Issue駆動の自動処理

### 完全自動化ワークフロー

- ✅ **次稿ブランチ自動作成**: 1st-draft → 2nd-draft → ... → 20th-draft
- ✅ **概要ブランチ自動作成**: abstract-1st → abstract-2nd → ...
- ✅ **レビューブランチ自動更新**: PR作成時に自動同期
- ✅ **並行執筆サポート**: 添削完了を待たずに次稿執筆開始

### 効率的な添削システム

- ✅ **差分レビュー**: 変更点のみを効率的に確認
- ✅ **全体レビュー**: 論文全体の構成・整合性確認
- ✅ **複数教員対応**: 役割分担・並行レビュー
- ✅ **Suggestion機能**: 具体的な修正提案

### 学生体験の向上

- ✅ **GitHub Desktop**: Git知識不要の簡単操作
- ✅ **自動化**: ブランチ作成・管理の自動化
- ✅ **明確な手順**: ステップバイステップガイド
- ✅ **エラー回避**: 自動化によるヒューマンエラー削減

## 📖 詳細ガイド

### 教員向け

1. **初めてGitHub PRを使う場合**
   → [PR-REVIEW-GUIDE.md](docs/PR-REVIEW-GUIDE.md)

2. **技術的な詳細・上級操作**
   → [TEACHER-GUIDE.md](docs/TEACHER-GUIDE.md)

3. **リポジトリ管理・一括操作**
   → [管理ツール使用方法](#管理ツール) 参照

### 学生向け

**論文執筆ガイドは各テンプレートリポジトリにあります**:
- [sotsuron-template](https://github.com/smkwlab/sotsuron-template) - 卒業論文・修士論文用

## 📊 管理ツール

### thesis-repo-manager.sh

学生論文リポジトリの一括管理ツールです。

#### 基本的な使用方法

```bash
# 全学生リポジトリの状況確認
./thesis-repo-manager.sh status

# 一括ブランチ保護設定
./thesis-repo-manager.sh bulk

# ブランチ保護状況の確認
./thesis-repo-manager.sh check

# ヘルプ表示
./thesis-repo-manager.sh help
```

#### 主要機能

- **status**: 全学生リポジトリの状況をGitHub API経由で取得・表示
- **bulk**: pending-protection.txt内の学生に一括でブランチ保護設定
- **check**: 保護設定待ちリポジトリの確認
- **pr-stats**: PRと Issue の統計情報表示
- **activity**: 最近7日間のコミット活動表示

#### ファイル管理

- `student-repos/pending-protection.txt`: ブランチ保護設定待ちの学生リスト
- `student-repos/completed-protection.txt`: 設定完了済みの学生リスト

これらのファイルは bulk 処理により自動的に更新されます。

#### 設定される保護ルール

- 1つ以上の承認レビューが必要
- 新しいコミット時に古いレビューを無効化
- フォースプッシュとブランチ削除を禁止
- 管理者に対する制限は適用なし

### 個別スクリプト

#### scripts/setup-branch-protection.sh

単一学生のブランチ保護設定用：

```bash
cd scripts
./setup-branch-protection.sh k21rs001
```

- Issue の自動クローズ機能付き
- エラー時の詳細診断機能

## 🛠️ システム要件

### 教員・管理者

- **GitHub CLI**: リポジトリ作成・管理用
- **Git**: バージョン管理
- **Bash**: スクリプト実行環境

### 学生

- **GitHub Desktop**: ブランチ操作・コミット
- **VS Code + LaTeX Workshop**: 論文執筆環境
- **Docker**: devcontainer環境（自動設定）

## 🔍 トラブルシューティング

### よくある問題

#### GitHub Actions が動作しない
```bash
# ワークフロー実行状況確認
gh run list --repo smkwlab/{student-repo}

# 緊急時の手動更新
./scripts/update-review-branch.sh {repo-name} {branch-name}
```

#### ブランチ作成が失敗する
```bash
# リポジトリ権限確認
gh repo view smkwlab/{student-repo}

# 手動ブランチ作成
git checkout -b {next-branch} {base-branch}
git push -u origin {next-branch}
```

#### 複数教員での競合
- [TEACHER-GUIDE.md](docs/TEACHER-GUIDE.md) の「複数人レビューの運用方法」を参照

## 🤝 コントリビューション

改善提案・バグ報告は Issues または Pull Request でお知らせください。

### 開発・テスト環境

```bash
# テスト用リポジトリ作成
./scripts/create-student-repos.sh test-student

# 動作確認
cd test-student-sotsuron
# 通常の学生ワークフローをテスト
```

## 📊 使用状況・統計

```bash
# 作成済みリポジトリ一覧
gh repo list smkwlab --topic thesis

# アクティブなPR確認
gh search prs --owner smkwlab --state open
```

## 📞 サポート

質問・問題がある場合:

1. **ドキュメント確認**: 該当するガイドを参照
2. **Issues作成**: このリポジトリでIssue作成
3. **ML連絡**: smkwlabML で質問共有

## 📝 更新履歴

- **v2.0.0** (2024/06): GitHub Actions完全自動化
- **v1.5.0** (2024/05): 概要ワークフロー追加
- **v1.0.0** (2024/04): 基本システム完成

## 📄 ライセンス

MIT License - 教育・研究目的での自由な利用を推奨

---

**関連リポジトリ**:
- [sotsuron-template](https://github.com/smkwlab/sotsuron-template) - 論文テンプレート
- [latex-environment](https://github.com/smkwlab/latex-environment) - LaTeX開発環境
