# GitHub Actions 管理者セットアップガイド

## 📋 概要

thesis-management-toolsのGitHub Actionsワークフローが学生リポジトリにアクセスできるようにするための管理者向けセットアップガイドです。

## ⚡ クイックセットアップ

### 必要な権限
- **`repo`スコープのみ** - 最小限の必要権限

### 設定手順（2分で完了）
1. [Personal Access Token作成](#1-personal-access-token-pat-の作成)
2. [Repository Secretsに追加](#2-repository-secretsへの追加)
3. [動作確認](#3-動作確認)

---

## 🔧 詳細設定手順

### 1. Personal Access Token (PAT) の作成

1. GitHubの[Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)にアクセス
2. "Generate new token (classic)" をクリック
3. **最小権限設定**：
   - **Note**: `thesis-management-tools-admin`
   - **Expiration**: 1年（推奨）
   - **Select scopes**: **`repo`のみにチェック**
4. "Generate token"をクリックし、トークンをコピー

> ⚠️ **重要**: `repo`以外の権限は不要です。他の権限を追加すると不要なセキュリティリスクが発生します。

### 2. Repository Secretsへの追加

1. [thesis-management-tools リポジトリ](https://github.com/smkwlab/thesis-management-tools)にアクセス
2. Settings > Secrets and variables > Actions に移動
3. "New repository secret"をクリック
4. 以下を入力：
   - **Name**: `ORG_ADMIN_TOKEN`
   - **Secret**: コピーしたPATを貼り付け
5. "Add secret"をクリック

### 3. 動作確認

設定後、学生が新しいリポジトリを作成すると：
1. 自動的にIssueが作成される
2. GitHub Actionsが起動し、ブランチ保護設定を実行
3. 設定完了後、Issueが自動クローズされる

## 🔒 セキュリティ考慮事項

### 権限の最小化原則
- **使用権限**: `repo`スコープのみ（最小限）
- **アクセス範囲**: Organization内のプライベートリポジトリ
- **実際の操作**: ブランチ保護設定とIssue管理のみ

### 運用管理ベストプラクティス
- **定期更新**: 3-6ヶ月毎のトークン更新
- **監査**: GitHub Audit logでの使用状況確認
- **即座対応**: 不要時・侵害時の迅速な削除
- **権限確認**: 定期的な権限使用状況の監査

### リスク評価と軽減策

#### リスクレベル: 低〜中
- **潜在リスク**: Organization内全プライベートリポジトリへのアクセス
- **実際の影響**: 学生thesis関連リポジトリのブランチ保護設定のみ
- **軽減策**:
  - コードベースでの操作制限（ブランチ保護のみ）
  - 定期的なアクセスログ確認
  - トークンの短期更新サイクル

#### Fine-grained Token vs Classic Token
- **Fine-grained**: より細かい制御可能だが、新リポジトリ作成時に手動更新必要
- **Classic (`repo`)**: 管理オーバーヘッドが少なく、運用に適している
- **選択理由**: 運用効率とセキュリティのバランスでClassic tokenを採用

## トラブルシューティング

### "Repository not found"エラーが発生する場合
- `ORG_ADMIN_TOKEN`が正しく設定されているか確認
- トークンの権限が適切か確認
- トークンの有効期限が切れていないか確認

### ワークフローが失敗する場合
- Actions > 該当のワークフロー > ログを確認
- `gh auth status`の出力を確認
- トークンがOrganizationへのアクセス権限を持っているか確認