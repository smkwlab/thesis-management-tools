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
3. 以下を設定：
   - **Note**: `thesis-management-tools-admin`
   - **Expiration**: 1年（推奨）
   - **Select scopes**: `repo` にチェック（これだけで十分）
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

### 権限の最小化
- **Fine-grained token推奨**: より細かい権限制御が可能
- **Repository scope**: 必要なリポジトリのみに限定
- **権限監査**: 定期的に使用されている権限を確認

### 運用管理
- **定期更新**: トークンを3-6ヶ月毎に更新
- **アクセス監査**: GitHub の Audit log で使用状況を監視
- **即座削除**: 不要時やセキュリティ侵害時の迅速な削除
- **複数人確認**: 設定変更時の相互確認

### リスク軽減
- **`repo`権限のリスク**: Organization内全プライベートリポジトリにアクセス可能
- **実際の使用**: ブランチ保護設定とIssue操作のみに限定
- **軽減策**: 
  - 定期的なアクセスログ監視
  - トークンの定期更新 (3-6ヶ月)
  - 不要時の即座削除
  - GitHub Audit logでの利用状況確認

### 注意事項
- Fine-grained tokenは新しいリポジトリ作成時に手動更新が必要なため使用しません
- Classic tokenの`repo`スコープは必要最小限の権限です

## トラブルシューティング

### "Repository not found"エラーが発生する場合
- `ORG_ADMIN_TOKEN`が正しく設定されているか確認
- トークンの権限が適切か確認
- トークンの有効期限が切れていないか確認

### ワークフローが失敗する場合
- Actions > 該当のワークフロー > ログを確認
- `gh auth status`の出力を確認
- トークンがOrganizationへのアクセス権限を持っているか確認