# GitHub Actions Setup Guide

このガイドでは、thesis-management-toolsのGitHub Actionsワークフローを正しく動作させるための設定方法を説明します。

## 問題と解決策

### 問題
デフォルトの`GITHUB_TOKEN`では、GitHub Actions環境から他のリポジトリ（学生のthesisリポジトリ）にアクセスできません。

### 解決策
Organization管理者権限を持つPersonal Access Token (PAT)を作成し、リポジトリのSecretsに追加します。

## 設定手順

### 1. Personal Access Token (PAT) の作成

1. GitHubの[Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)にアクセス
2. "Generate new token (classic)" をクリック
3. 以下の設定を行う：
   - **Note**: `thesis-management-tools-admin`
   - **Expiration**: 適切な期限を設定（推奨：1年）
   - **Scopes**:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `admin:org` (Full control of orgs and teams)
     - ✅ `workflow` (Update GitHub Action workflows)
4. "Generate token"をクリックし、トークンをコピー

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

## セキュリティ上の注意

- PATは強力な権限を持つため、厳重に管理してください
- 定期的にトークンを更新してください
- 不要になったトークンは速やかに削除してください

## トラブルシューティング

### "Repository not found"エラーが発生する場合
- `ORG_ADMIN_TOKEN`が正しく設定されているか確認
- トークンの権限が適切か確認
- トークンの有効期限が切れていないか確認

### ワークフローが失敗する場合
- Actions > 該当のワークフロー > ログを確認
- `gh auth status`の出力を確認
- トークンがOrganizationへのアクセス権限を持っているか確認