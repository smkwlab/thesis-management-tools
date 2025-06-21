#!/bin/bash
# 論文リポジトリ作成スクリプト
# 使用例: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

set -e

# デバッグモード（環境変数 DEBUG=1 で有効化）
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "🔍 デバッグモード有効"
fi

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

# 一時ディレクトリ変数（グローバルスコープ）
TEMP_DIR=""

# クリーンアップ関数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "🧹 クリーンアップ中..."
        rm -rf "$TEMP_DIR"
    fi
    # Dockerイメージも削除
    docker rmi thesis-setup-temp 2>/dev/null || true
}

# 終了時・エラー時・割り込み時にクリーンアップ
trap cleanup EXIT ERR INT TERM

echo "🎓 論文リポジトリ セットアップ"
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

# GitHub 認証状態の確認
echo "🔑 GitHub 認証状態を確認中..."
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub 認証が必要です"
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

# 現在のアクティブアカウントを取得
CURRENT_USER=$(gh api user --jq .login 2>/dev/null)
if [ -z "$CURRENT_USER" ]; then
    echo "❌ アクティブなGitHubアカウントの情報取得に失敗しました"
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

# GitHub トークンの取得
echo "🎫 GitHub 認証トークンを取得中..."
GITHUB_TOKEN=""
if GITHUB_TOKEN=$(gh auth token 2>/dev/null); then
    echo "✅ GitHub 認証トークンを取得しました"
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
BRANCH="${THESIS_BRANCH:-main}"
if ! git checkout "$BRANCH" 2>/dev/null; then
    echo "⚠️ ブランチ $BRANCH が見つかりません。mainブランチを使用します。"
    git checkout main 2>/dev/null || true
fi

cd create-repo

echo "🔨 Dockerイメージをビルド中..."
if [ "${DEBUG:-0}" = "1" ]; then
    # デバッグモードでは詳細出力を表示
    docker build --progress=plain -t thesis-setup-temp .
else
    # 通常モードでも進行状況を表示
    if ! docker build --progress=auto -t thesis-setup-temp .; then
        echo "❌ Dockerイメージのビルドに失敗しました"
        exit 1
    fi
fi

echo "🚀 セットアップ実行中..."

# 元のディレクトリに戻って実行
cd "$ORIGINAL_DIR"

# Docker実行（TTY対応、GitHub認証トークンを環境変数で渡す）
if [ -n "$STUDENT_ID" ]; then
    docker run --rm -it -e GH_TOKEN="$GITHUB_TOKEN" thesis-setup-temp "$STUDENT_ID"
else
    docker run --rm -it -e GH_TOKEN="$GITHUB_TOKEN" thesis-setup-temp
fi

# 成功メッセージ（クリーンアップは trap で自動実行）
echo "🎉 セットアップ完了！"
