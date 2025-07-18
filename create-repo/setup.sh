#!/bin/bash
# 統合リポジトリ作成スクリプト (Universal Setup Script)
# 使用例: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-universal.sh)"

set -e

# デバッグモード（環境変数 DEBUG=1 で有効化）
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "🔍 デバッグモード有効"
fi

# ================================
# 文書タイプ設定
# ================================

# 文書タイプの明示的指定（必須）
DOC_TYPE="${DOC_TYPE}"

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

# 文書タイプの検証
if [ -z "$DOC_TYPE" ]; then
    echo "❌ DOC_TYPE環境変数が指定されていません"
    echo ""
    echo "使用例："
    echo "  DOC_TYPE=thesis $0"
    echo "  DOC_TYPE=wr $0"
    echo "  DOC_TYPE=latex $0"
    echo "  DOC_TYPE=ise $0"
    echo ""
    exit 1
fi

# 文書タイプの設定
DETECTED_DOC_TYPE="$DOC_TYPE"

# 設定マッピング
configure_document_type() {
    local doc_type="$1"
    
    case "$doc_type" in
        thesis)
            DOC_DESCRIPTION="📚 論文リポジトリ"
            DOCKERFILE_NAME="Dockerfile-thesis"
            DOCKER_IMAGE_NAME="thesis-setup-alpine"
            MAIN_SCRIPT="main-thesis.sh"
            ;;
        wr)
            DOC_DESCRIPTION="📝 週間報告リポジトリ"
            DOCKERFILE_NAME="Dockerfile-wr"
            DOCKER_IMAGE_NAME="wr-setup-alpine"
            MAIN_SCRIPT="main-wr.sh"
            ;;
        latex)
            DOC_DESCRIPTION="📝 汎用LaTeXリポジトリ"
            DOCKERFILE_NAME="Dockerfile-latex"
            DOCKER_IMAGE_NAME="latex-setup-alpine"
            MAIN_SCRIPT="main-latex.sh"
            ;;
        ise)
            DOC_DESCRIPTION="💻 情報科学演習リポジトリ"
            DOCKERFILE_NAME="Dockerfile-ise"
            DOCKER_IMAGE_NAME="ise-setup-alpine"
            MAIN_SCRIPT="main-ise.sh"
            ;;
        *)
            echo "❌ サポートされていない文書タイプ: $doc_type"
            echo "対応タイプ: thesis, wr, latex, ise"
            exit 1
            ;;
    esac
}

# 設定の適用
configure_document_type "$DETECTED_DOC_TYPE"

# ================================
# 共通変数・関数定義
# ================================

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
    if docker images -q "$DOCKER_IMAGE_NAME" >/dev/null 2>&1; then
        echo "🗑️  Dockerイメージをクリーンアップ中..."
        docker rmi "$DOCKER_IMAGE_NAME" >/dev/null 2>&1 || true
    fi
}

# 終了時・中断時のクリーンアップ
trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

# ================================
# メイン処理開始
# ================================

echo "==============================================="
echo "$DOC_DESCRIPTION 作成ツール (Universal)"
echo "🐳 Dockerベース"
echo "==============================================="
echo "📋 検出された文書タイプ: $DETECTED_DOC_TYPE"

# 指定された文書タイプの表示
echo "🎯 文書タイプ: $DOC_TYPE"

echo ""

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

# ユーザータイプ判定関数
detect_user_type() {
    local current_user="$1"
    
    if [ "${DEBUG:-0}" = "1" ]; then
        echo "🔍 ユーザータイプを判定中: $current_user"
    fi
    
    # INDIVIDUAL_MODE環境変数による明示的指定
    if [ "${INDIVIDUAL_MODE:-false}" = "true" ]; then
        echo "individual_user"
        return 0
    fi
    
    # smkwlab組織メンバーシップを確認
    if gh api "orgs/smkwlab/members/$current_user" >/dev/null 2>&1; then
        echo "organization_member"
    else
        echo "individual_user"
    fi
}

# ユーザータイプの判定
USER_TYPE=$(detect_user_type "$CURRENT_USER")

if [ "${DEBUG:-0}" = "1" ]; then
    echo "🔍 判定結果: $USER_TYPE"
fi

# TARGET_ORG（対象組織）の設定
if [ "$USER_TYPE" = "individual_user" ]; then
    # 個人ユーザーの場合、デフォルトを個人アカウントに設定
    TARGET_ORG="${TARGET_ORG:-$CURRENT_USER}"
    echo "👤 個人ユーザーモードで実行中"
    echo "   作成先: $TARGET_ORG (個人アカウント)"
else
    # 組織ユーザーの場合、従来通り
    TARGET_ORG="${TARGET_ORG:-smkwlab}"
    echo "🏢 組織ユーザーモードで実行中"
    echo "   作成先: $TARGET_ORG (組織)"
fi

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
BRANCH="${UNIVERSAL_BRANCH:-main}"
if ! git checkout "$BRANCH" 2>/dev/null; then
    echo "⚠️ ブランチ $BRANCH が見つかりません。mainブランチを使用します。"
    git checkout main 2>/dev/null || true
fi

cd create-repo

echo "🐳 Dockerイメージをビルド中..."
if [ "${DEBUG:-0}" = "1" ]; then
    # デバッグモードでは詳細出力を表示
    if ! docker build --progress=plain -f "$DOCKERFILE_NAME" -t "$DOCKER_IMAGE_NAME" .; then
        echo "❌ Dockerイメージのビルドに失敗しました"
        exit 1
    fi
else
    # 通常モードでも進行状況を表示
    if ! docker build --progress=auto -f "$DOCKERFILE_NAME" -t "$DOCKER_IMAGE_NAME" .; then
        echo "❌ Dockerイメージのビルドに失敗しました"
        exit 1
    fi
fi

echo "🚀 セットアップ実行中..."

# 元のディレクトリに戻って実行
cd "$ORIGINAL_DIR"

# Docker実行（TTY対応、GitHub認証トークンをセキュアファイル経由で渡す）
# 動作モード情報と環境変数を渡す
DOCKER_ENV_VARS="-e USER_TYPE=$USER_TYPE -e TARGET_ORG=$TARGET_ORG"

# 文書タイプ固有の環境変数を渡す
case "$DETECTED_DOC_TYPE" in
    latex)
        # ドキュメント名が環境変数で指定されている場合は渡す
        if [ -n "$DOCUMENT_NAME" ]; then
            DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e DOCUMENT_NAME=$DOCUMENT_NAME"
        fi
        # 作者名が環境変数で指定されている場合は渡す
        if [ -n "$AUTHOR_NAME" ]; then
            DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e AUTHOR_NAME=$AUTHOR_NAME"
        fi
        # ブランチ保護設定が環境変数で指定されている場合は渡す
        if [ -n "$ENABLE_PROTECTION" ]; then
            DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e ENABLE_PROTECTION=$ENABLE_PROTECTION"
        fi
        ;;
    ise)
        # ISE固有の環境変数処理
        if [ -n "$ASSIGNMENT_TYPE" ]; then
            DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e ASSIGNMENT_TYPE=$ASSIGNMENT_TYPE"
        fi
        if [ -n "$ISE_REPORT_NUM" ]; then
            DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e ISE_REPORT_NUM=$ISE_REPORT_NUM"
        fi
        ;;
esac

# Git Bash環境下でのみGH_TOKENを環境変数として渡す
if [[ -n "$MSYSTEM" ]] || [[ "$OSTYPE" == "msys" ]] || [[ -n "$MINGW_PREFIX" ]] || ([[ -n "$WINDIR" ]] && [[ "$SHELL" == *"bash"* ]]); then
    # Git Bash環境下ではGH_TOKENを取得・設定
    if [ -z "$GH_TOKEN" ]; then
        if GH_TOKEN=$(gh auth token 2>/dev/null); then
            DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e GH_TOKEN=$GH_TOKEN"
        else
            echo "⚠️ GitHub認証トークンの取得に失敗しました。gh auth login を実行してください。"
        fi
    fi
fi

# 統一されたDocker実行（全タイプ共通）
if [ -n "$STUDENT_ID" ]; then
    if ! docker run --rm -it $DOCKER_ENV_VARS -v "$TOKEN_FILE:/tmp/gh_token:ro" "$DOCKER_IMAGE_NAME" "$STUDENT_ID"; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        echo "学籍番号: $STUDENT_ID"
        exit 1
    fi
else
    if ! docker run --rm -it $DOCKER_ENV_VARS -v "$TOKEN_FILE:/tmp/gh_token:ro" "$DOCKER_IMAGE_NAME"; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        exit 1
    fi
fi

# 成功メッセージ（クリーンアップは trap で自動実行）
echo ""
echo "✅ $DOC_DESCRIPTION のセットアップが完了しました！"