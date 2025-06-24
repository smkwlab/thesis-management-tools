#!/bin/bash
# 週間報告リポジトリ作成スクリプト
# 使用例: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-wr.sh)"

set -e

# デバッグモード（環境変数 DEBUG=1 で有効化）
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "🔍 デバッグモード有効"
fi

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

# 一時ディレクトリ・ファイル変数（グローバルスコープ）
TEMP_DIR=""
TOKEN_FILE=""

# クリーンアップ関数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "🧹 クリーンアップ中..."
        rm -rf "$TEMP_DIR"
    fi
    # セキュアなトークンファイルの削除
    if [ -n "$TOKEN_FILE" ] && [ -f "$TOKEN_FILE" ]; then
        rm -f "$TOKEN_FILE"
    fi
    # Dockerイメージも削除
    if docker images -q wr-setup-alpine >/dev/null 2>&1; then
        echo "🗑️  Dockerイメージをクリーンアップ中..."
        docker rmi wr-setup-alpine >/dev/null 2>&1 || true
    fi
}

# 終了時・中断時のクリーンアップ
trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

echo "==============================================="
echo "📝 週間報告リポジトリ作成ツール"
echo "🐳 Dockerベース"
echo "==============================================="

# Docker の確認
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Dockerがインストールされていません"
    echo "   https://docs.docker.com/get-docker/ からインストールしてください"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "❌ Dockerデーモンが起動していません"
    echo "   Dockerを起動してから再実行してください"
    exit 1
fi

# GitHub CLI の確認（ホスト側）
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) がインストールされていません"
    echo "   https://cli.github.com/ からインストールしてください"
    exit 1
fi

# GitHub 認証状況を確認
echo "🔐 GitHub 認証状況を確認中..."

if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI にログインしていません"
    echo ""
    echo "以下のコマンドでログインしてください："
    echo "  gh auth login"
    echo ""
    echo "💡 認証方法："
    echo "  - ブラウザ認証（推奨）: Enter → ワンタイムコードを入力"
    echo "  - Personal Access Token: トークンを直接入力"
    echo ""
    echo "🔧 トラブルシューティング："
    echo "  - エラー時: gh auth refresh"
    echo "  - 複数アカウント: gh auth switch --user USERNAME"
    echo ""
    exit 1
fi

# 現在のユーザーアカウントを取得
if ! CURRENT_USER=$(gh api user --jq .login 2>/dev/null); then
    echo "❌ GitHub APIアクセスに失敗しました"
    echo "認証トークンを更新してください："
    echo "  gh auth refresh"
    exit 1
fi

echo "✅ GitHub認証済み (ユーザー: $CURRENT_USER)"

# TARGET_ORG（対象組織）の設定
TARGET_ORG="${TARGET_ORG:-smkwlab}"

# TARGET_ORG が指定されている場合、アカウントの整合性をチェック
if [ -n "$TARGET_ORG" ] && [ "$TARGET_ORG" != "smkwlab" ]; then
    if [ "$CURRENT_USER" != "$TARGET_ORG" ]; then
        echo "⚠️ アカウント不整合が検出されました"
        echo "  指定組織: $TARGET_ORG"
        echo "  現在のアカウント: $CURRENT_USER"
        echo ""
        echo "以下のコマンドでアカウントを切り替えてください："
        echo "  gh auth switch --user $TARGET_ORG"
        echo ""
        echo "または、現在のアカウントで個人リポジトリとして作成："
        echo "  TARGET_ORG=$CURRENT_USER $0"
        exit 1
    fi
fi

# 複数アカウントが存在する場合の情報表示
AUTH_STATUS=$(gh auth status 2>&1)
ACCOUNT_COUNT=$(echo "$AUTH_STATUS" | grep -c "Logged in to" || echo "1")

if [ "$ACCOUNT_COUNT" -gt 1 ]; then
    echo "ℹ️ 複数のGitHubアカウントが検出されました (${ACCOUNT_COUNT}個)"
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "認証状況:"
        echo "$AUTH_STATUS" | grep -E "(Logged in to|Active account)"
    fi
    echo "現在のアクティブアカウント ($CURRENT_USER) を使用します"
fi

# GitHub トークンをセキュアな一時ファイルに保存
echo "🎫 GitHub 認証トークンを準備中..."
TOKEN_FILE=$(mktemp)
chmod 600 "$TOKEN_FILE"  # 所有者のみ読み書き可能

if gh auth token > "$TOKEN_FILE" 2>/dev/null; then
    echo "✅ GitHub 認証トークンを安全に準備しました"
else
    echo "❌ トークン取得に失敗しました"
    echo "以下のコマンドでGitHub CLIを再認証してください："
    echo "  gh auth refresh"
    exit 1
fi

# GitHub から直接ビルド & 実行
echo "🔧 セットアップ開始..."

# 一時ディレクトリでリポジトリをクローン
TEMP_DIR=$(mktemp -d)
ORIGINAL_DIR=$(pwd)
echo "📥 リポジトリを取得中..."

if ! git clone https://github.com/smkwlab/thesis-management-tools.git "$TEMP_DIR" 2>/dev/null; then
    echo "❌ リポジトリのクローンに失敗しました"
    exit 1
fi

cd "$TEMP_DIR"

# ブランチ指定がある場合は切り替え
BRANCH="${WR_BRANCH:-main}"
if ! git checkout "$BRANCH" 2>/dev/null; then
    echo "⚠️ ブランチ $BRANCH が見つかりません。mainブランチを使用します。"
    git checkout main 2>/dev/null || true
fi

cd create-repo

echo "🐳 Dockerイメージをビルド中..."
if [ "${DEBUG:-0}" = "1" ]; then
    # デバッグモードでは詳細出力を表示
    docker build --progress=plain -f Dockerfile-wr -t wr-setup-alpine .
else
    # 通常モードでも進行状況を表示
    if ! docker build --progress=auto -f Dockerfile-wr -t wr-setup-alpine .; then
        echo "❌ Dockerイメージのビルドに失敗しました"
        exit 1
    fi
fi

echo "🚀 セットアップ実行中..."

# 元のディレクトリに戻って実行
cd "$ORIGINAL_DIR"

# Docker実行（TTY対応、GitHub認証トークンをセキュアファイル経由で渡す）- 週報用のスクリプトを実行
if [ -n "$STUDENT_ID" ]; then
    if ! docker run --rm -it -v "$TOKEN_FILE:/tmp/gh_token:ro" wr-setup-alpine "$STUDENT_ID"; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        echo "学籍番号: $STUDENT_ID"
        exit 1
    fi
else
    if ! docker run --rm -it -v "$TOKEN_FILE:/tmp/gh_token:ro" wr-setup-alpine; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        exit 1
    fi
fi

# 成功メッセージ（クリーンアップは trap で自動実行）
echo ""
echo "✅ セットアップが完了しました！"
