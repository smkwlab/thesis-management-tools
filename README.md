# Thesis Management Tools

論文執筆ワークフローの管理ツールとガイドドキュメント集です。
GitHub を使った効率的な論文指導をサポートします。

## 対象ユーザー

- **学生**: 論文執筆・提出
- **教員**: 論文添削・指導
- **管理者**: 学生リポジトリの一括作成・管理
- **TA・先輩**: 副指導・レビュー支援

## 🎓 学生の方へ

**論文執筆用リポジトリの作成方法**

### 📋 セットアップスクリプト使用（推奨）

**前提条件:**
- Windows: WSL + Docker Desktop
- macOS: Docker Desktop
- GitHub CLI は不要（Docker内で自動インストール）

#### 超簡単ワンライナー実行（推奨）

```bash
curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh | bash
```

学籍番号指定：

```bash
curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh | bash -s k21rs001
```

**実行手順:**
1. 上記コマンドを実行
2. GitHub認証：ワンタイムコードをブラウザで入力
3. 学籍番号を入力（未指定の場合）
4. 自動でリポジトリ作成・セットアップ完了

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

- **[create-student-repos.sh](scripts/create-student-repos.sh)**: 学生リポジトリ一括作成
  - テンプレートからの自動生成
  - 初期ブランチ設定
  - LaTeX devcontainer 自動追加

- **[update-review-branch.sh](scripts/update-review-branch.sh)**: レビューブランチ手動更新（非推奨）
  - GitHub Actions 障害時の緊急用
  - トラブルシューティング用

## 🚀 クイックスタート

### 1. 教員・管理者の初期設定

```bash
# このリポジトリをクローン
git clone https://github.com/smkwlab/thesis-management-tools.git
cd thesis-management-tools

# GitHub CLI の認証確認
gh auth status

# 学生リポジトリを一括作成
./scripts/create-student-repos.sh k21rs001 k21rs002 k21gjk01
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

- **[sotsuron-template](https://github.com/smkwlab/sotsuron-template)**: 卒業論文用
- **[master-template](https://github.com/smkwlab/master-template)**: 修士論文用

## 🔧 主要機能

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

### 学生向け

**論文執筆ガイドは各テンプレートリポジトリにあります**:
- [sotsuron-template](https://github.com/smkwlab/sotsuron-template) - 卒業論文用
- [master-template](https://github.com/smkwlab/master-template) - 修士論文用

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
- [sotsuron-template](https://github.com/smkwlab/sotsuron-template) - 卒業論文テンプレート
- [master-template](https://github.com/smkwlab/master-template) - 修士論文テンプレート
- [latex-environment](https://github.com/smkwlab/latex-environment) - LaTeX開発環境