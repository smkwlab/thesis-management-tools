# GitHub Actions 管理者セットアップガイド

## 📋 概要

thesis-management-tools の GitHub Actions ワークフロー（`student-repo-management.yml`）が
学生リポジトリにアクセスできるようにするための管理者向けセットアップガイドです。

認証には **GitHub App の installation token** を使用します。従来の個人 PAT
（`ORG_ADMIN_TOKEN`）は、無通知で失効して自動化が静かに止まる運用リスクがあったため
廃止しました（背景: Issue #472）。App トークンはワークフロー実行のたびに自動発行され、
約 1 時間で失効するため、失効管理や定期更新が不要です。

## ⚡ 概要フロー

1. [GitHub App を作成](#1-github-app-の作成)（org オーナー権限が必要）
2. [App を org にインストール](#2-app-の-org-へのインストール)
3. [App ID と秘密鍵を Secrets に登録](#3-app-id-と秘密鍵の登録)
4. [動作確認](#4-動作確認)

初回のみ管理者が実施します。以降はトークンの更新作業は不要です。

---

## 🔧 詳細設定手順

### 1. GitHub App の作成

1. [Organization settings > Developer settings > GitHub Apps](https://github.com/organizations/smkwlab/settings/apps)
   にアクセスし、**New GitHub App** をクリック
2. 基本設定：
   - **GitHub App name**: 例 `smkwlab-thesis-automation`（org 内で一意）
   - **Homepage URL**: 任意（例: リポジトリの URL）
   - **Webhook**: **Active のチェックを外す**（本用途では不要）
3. **Repository permissions**（必要最小セット。2026-07 の障害復旧で実証済み）：
   - **Contents**: Read and write（レジストリ更新・チェックアウト）
   - **Issues**: Read and write（登録依頼 Issue のクローズ）
   - **Administration**: Read and write（ブランチ保護設定）
   - **Metadata**: Read-only（自動で必須）
4. **Where can this GitHub App be installed?**: Only on this account
5. **Create GitHub App** をクリック

> ⚠️ **重要**: 上記以外の権限は付与しないでください。最小権限の原則に従います。

### 2. App の org へのインストール

1. 作成した App の設定画面 左メニュー **Install App** をクリック
2. smkwlab org に **Install**
3. **Repository access**: **All repositories** を選択

> 学生リポジトリは登録のたびに動的に作成され、それぞれにブランチ保護
> （Administration 権限）が必要なため、All repositories が適切です。

### 3. App ID と秘密鍵の登録

1. App 設定画面で **App ID**（数値）を控える
2. **Generate a private key** で `.pem` ファイルをダウンロード
3. [thesis-management-tools リポジトリ](https://github.com/smkwlab/thesis-management-tools)の
   Settings > Secrets and variables > Actions で、以下の 2 つの **Repository secret** を追加：
   - **`APP_ID`**: 控えた App ID（数値）
   - **`APP_PRIVATE_KEY`**: `.pem` ファイルの全文
     （`-----BEGIN...` から `-----END...` まで、改行を含めそのまま貼り付け）

### 4. 動作確認

設定後、学生が新しいリポジトリを作成すると：

1. 自動的に Issue が作成される
2. GitHub Actions が起動し、`create-github-app-token` で installation token を発行
3. ブランチ保護設定・レジストリ更新・Issue クローズが実行される

手動で確認する場合は、Actions タブから `Student Repository Management` ワークフローを
`workflow_dispatch`（一括処理モード）で実行し、成功することを確認してください。

## 🔒 セキュリティ考慮事項

### GitHub App を採用する理由

- **無通知失効の排除**: installation token は実行のたびに自動発行・約 1 時間で失効。
  個人 PAT のように「気付かないうちに失効して自動化が止まる」ことがない
- **最小権限**: リポジトリ単位の細粒度権限（Contents / Issues / Administration / Metadata）
  のみを付与。組織全体の広い `repo` スコープを持つ classic PAT より安全
- **監査性**: App の操作は Bot として記録され、Audit log で追跡しやすい
- **個人非依存**: 特定個人のアカウントに紐づかないため、担当者の異動・退職の影響を受けない

### 秘密鍵の管理

- `APP_PRIVATE_KEY` は GitHub Actions Secrets にのみ保存し、リポジトリにコミットしない
- 鍵の漏洩が疑われる場合は App 設定画面で該当鍵を revoke し、新しい鍵を発行して
  `APP_PRIVATE_KEY` を差し替える

## トラブルシューティング

### ワークフローが `create-github-app-token` ステップで失敗する場合

- `APP_ID` / `APP_PRIVATE_KEY` の secret が正しく設定されているか確認
- `APP_PRIVATE_KEY` に `.pem` の全文（BEGIN/END 行を含む）が貼られているか確認
- App が smkwlab org に **All repositories** でインストールされているか確認

### `Resource not accessible by integration`（403）が発生する場合

- App の Repository permissions に不足がないか確認
  （Contents / Issues / Administration の write、Metadata の read）
- 権限を追加した場合、org の Install 画面で新しい権限の承認が必要なことがある

### 対象リポジトリにアクセスできない場合

- App の installation の Repository access が **All repositories** になっているか確認
- 個別選択にしている場合、対象の学生リポジトリ・`thesis-student-registry` が
  含まれているか確認
