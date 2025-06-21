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
    docker rmi wr-setup-temp 2>/dev/null || true
}

# 終了時・エラー時・割り込み時にクリーンアップ
trap cleanup EXIT ERR INT TERM

echo "📝 週間報告リポジトリ セットアップ"
echo "=============================================="

# Docker の確認
if ! command -v docker &> /dev/null; then
    echo "❌ Docker が見つかりません"
    echo "Docker Desktop をインストールしてください："
    echo "  Windows: https://docs.docker.com/desktop/windows/"
    echo "  macOS: https://docs.docker.com/desktop/mac/"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker が起動していません"
    echo "Docker Desktop を起動してください"
    exit 1
fi

echo "✅ Docker 確認完了"

# GitHub CLI の確認と認証
echo "🔐 GitHub CLI の確認..."

# GitHub CLI のインストール確認
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI が見つかりません"
    echo "GitHub CLI をインストールしてください："
    echo "  Windows: winget install --id GitHub.cli"
    echo "  macOS: brew install gh"
    echo "  Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    exit 1
fi

echo "✅ GitHub CLI 確認完了"

# GitHub 認証状態の確認（現在アクティブなアカウントの認証確認）
echo "🔑 GitHub 認証状態を確認中..."
if ! gh api user --jq .login &> /dev/null; then
    echo "❌ 現在のアカウントの認証が必要です"
    echo "自動的にGitHub認証を開始します..."
    echo ""
    
    if gh auth login --hostname github.com --git-protocol https --web --scopes "repo,workflow,read:org"; then
        echo "✅ GitHub認証が完了しました"
    else
        echo "❌ GitHub認証に失敗しました"
        echo "手動で 'gh auth login' を実行してから再度お試しください"
        exit 1
    fi
fi

# 複数アカウントの確認と適切なアカウント選択
echo "👤 GitHub アカウント状況を確認中..."

# 現在のアクティブアカウントを取得（認証確認済みなので必ず成功）
CURRENT_USER=$(gh api user --jq .login 2>/dev/null)
if [ -z "$CURRENT_USER" ]; then
    echo "❌ アクティブなGitHubアカウントの情報取得に失敗しました"
    echo "認証に問題がある可能性があります。'gh auth refresh' を試してください"
    exit 1
fi

echo "✅ 現在のアクティブアカウント: $CURRENT_USER"

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

echo "🔨 Dockerイメージをビルド中..."
if [ "${DEBUG:-0}" = "1" ]; then
    # デバッグモードでは詳細出力を表示
    docker build --progress=plain -t wr-setup-temp -f Dockerfile-wr .
else
    # 通常モードでも進行状況を表示
    if ! docker build --progress=auto -t wr-setup-temp -f Dockerfile-wr .; then
        echo "❌ Dockerイメージのビルドに失敗しました"
        exit 1
    fi
fi

echo "🚀 セットアップ実行中..."

# 元のディレクトリに戻って実行
cd "$ORIGINAL_DIR"

# Docker実行（TTY対応、GitHub認証トークンをセキュアファイル経由で渡す）- 週報用のスクリプトを実行
if [ -n "$STUDENT_ID" ]; then
    if ! docker run --rm -it -v "$TOKEN_FILE:/tmp/gh_token:ro" wr-setup-temp "$STUDENT_ID"; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        echo "学籍番号: $STUDENT_ID"
        exit 1
    fi
else
    if ! docker run --rm -it -v "$TOKEN_FILE:/tmp/gh_token:ro" wr-setup-temp; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        exit 1
    fi
fi

# 成功メッセージ（クリーンアップは trap で自動実行）
echo "🎉 セットアップ完了！"