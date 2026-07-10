#!/bin/bash
# 統合リポジトリ作成スクリプト (Universal Setup Script)
# 使用例: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/main/create-repo/setup-universal.sh)"

set -e

# デバッグモード（環境変数 DEBUG=1 で有効化）
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "🔍 デバッグモード有効"
fi

# ================================
# 組織・ツールリポジトリ設定（他 org 展開対応）
# ================================
# デプロイ先の既定組織。smkwlab 以外の org で運用する場合は、この既定値を
# fork 側で書き換えるか、実行時に DEFAULT_ORG 環境変数で指定する。組織メンバー
# 判定・組織ユーザーの既定作成先・案内文の URL がこの値に追従する。
DEFAULT_ORG="${DEFAULT_ORG:-smkwlab}"
# 組織 / アカウント名は gh api のパス（orgs/<org>/members/...）に埋め込むため、
# GitHub のログイン/組織名の文字種（英数字とハイフン）で検証する。
case "$DEFAULT_ORG" in
    ""|*[!A-Za-z0-9-]*)
        echo "❌ DEFAULT_ORG に使用できない文字が含まれています: $DEFAULT_ORG" >&2
        exit 1 ;;
esac
# TARGET_ORG が env で明示指定されている場合も、同じく gh api のパスに使う前に検証する
# （未指定＝空は後段で既定へ解決するのでここでは許容）。
if [ -n "${TARGET_ORG:-}" ]; then
    case "$TARGET_ORG" in
        *[!A-Za-z0-9-]*)
            echo "❌ TARGET_ORG に使用できない文字が含まれています: $TARGET_ORG" >&2
            exit 1 ;;
    esac
fi

# このスクリプトが内部で clone する student-repo-management の取得元。
# 配布元 org（＝ DEFAULT_ORG）が既定。学生リポジトリの作成先である TARGET_ORG は
# 個人アカウントにもなり得るためここでは使わない。owner / repo 名は git clone の
# URL に埋め込むため、安全な文字のみ許可する（文字種のみ検証し、連続ハイフンや
# 長さ制限など GitHub 側の詳細な命名規則は clone 時のエラーに委ねる）。
TOOLS_REPO_OWNER="${TOOLS_REPO_OWNER:-$DEFAULT_ORG}"
# TOOLS_REPO は env 変数 TOOLS_REPO_NAME を解決した内部変数（既定を適用済み）。
# TOOLS_REPO_NAME 自体は「ユーザーが指定した時のみコンテナへ転送する」判定に
# 後段（$TOOLS_REPO_NAME の有無チェック）で使うため、別名のまま残す。
TOOLS_REPO="${TOOLS_REPO_NAME:-student-repo-management}"
case "$TOOLS_REPO_OWNER" in
    ""|*[!A-Za-z0-9-]*)
        echo "❌ TOOLS_REPO_OWNER に使用できない文字が含まれています: $TOOLS_REPO_OWNER" >&2
        exit 1 ;;
esac
case "$TOOLS_REPO" in
    ""|*[!A-Za-z0-9._-]*)
        echo "❌ TOOLS_REPO_NAME に使用できない文字が含まれています: $TOOLS_REPO" >&2
        exit 1 ;;
esac
TOOLS_CLONE_URL="${TOOLS_CLONE_URL:-https://github.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}.git}"
# TOOLS_CLONE_URL は完全上書きを許すため、git clone へ渡す前にスキームを検証する。
# https:// / git@ 以外（ext:: や file:// 等の危険なスキーム、先頭 "-" による git の
# 引数注入）を拒否する。既定値も https:// で始まるため通常運用に影響はない。
case "$TOOLS_CLONE_URL" in
    https://*|git@*) ;;
    *)
        echo "❌ TOOLS_CLONE_URL は https:// または git@ で始まる必要があります: $TOOLS_CLONE_URL" >&2
        exit 1 ;;
esac

# ================================
# バージョン固定（再現性・安全性）
# ================================
# このスクリプトが内部で clone・利用する student-repo-management の参照先（ref）。
#
# EMBEDDED_REF はリリース時にタグ（例: v1.0.0）へ書き換えられる。main ブランチ上では
# "main" のまま。これにより、タグ付き URL から取得した setup.sh は、内部で clone する
# 内容も同じタグに固定され、完全な再現性が得られる（リリース手順は docs/RELEASE.md）。
#
# 明示的に上書きしたい場合は環境変数で指定する：
#   UNIVERSAL_REF=v1.0.0   タグ / コミットSHA / ブランチを固定（推奨）。解決できない
#                          場合はエラー終了する（再現性・監査性のため main へ暗黙
#                          フォールバックしない）。
#   UNIVERSAL_BRANCH=...   後方互換のためのエイリアス（UNIVERSAL_REF を優先）。従来
#                          どおり、解決できない場合は警告して main へフォールバックする。
# 優先順位: UNIVERSAL_REF > UNIVERSAL_BRANCH > EMBEDDED_REF
EMBEDDED_REF="main"
if [ -n "$UNIVERSAL_REF" ]; then
    SETUP_REF="$UNIVERSAL_REF"
    SETUP_REF_LENIENT=0
elif [ -n "$UNIVERSAL_BRANCH" ]; then
    SETUP_REF="$UNIVERSAL_BRANCH"
    SETUP_REF_LENIENT=1   # 後方互換: 解決失敗時は main へフォールバック
else
    SETUP_REF="$EMBEDDED_REF"
    SETUP_REF_LENIENT=0
fi

# ================================
# 文書タイプ設定
# ================================

# 引数または環境変数から文書タイプを取得（引数を優先）
DOC_TYPE="${1:-$DOC_TYPE}"

# 学籍番号は環境変数から取得
STUDENT_ID="${STUDENT_ID}"

# 文書タイプの検証
if [ -z "$DOC_TYPE" ]; then
    echo "❌ 文書タイプが指定されていません"
    echo ""
    echo "使用例："
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\" bash thesis"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\" bash wr"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\" bash latex"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\" bash ise"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\" bash poster"
    echo ""
    echo "学籍番号を指定する場合（環境変数）："
    echo "  STUDENT_ID=k21rs001 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\" bash thesis"
    echo ""
    echo "環境変数での指定も可能："
    echo "  DOC_TYPE=thesis /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/main/create-repo/setup.sh)\""
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
        poster)
            DOC_DESCRIPTION="📊 学会ポスターリポジトリ"
            DOCKERFILE_NAME="Dockerfile-poster"
            DOCKER_IMAGE_NAME="poster-setup-alpine"
            MAIN_SCRIPT="main-poster.sh"
            ;;
        *)
            echo "❌ サポートされていない文書タイプ: $doc_type"
            echo "対応タイプ: thesis, wr, latex, ise, poster"
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
# 第2引数で渡された組織のメンバーシップを確認する（既定は DEFAULT_ORG、
# TARGET_ORG が明示指定されていれば呼び出し側でそちらを渡す）。
detect_user_type() {
    local current_user="$1"
    local org="$2"

    if [ "${DEBUG:-0}" = "1" ]; then
        echo "🔍 ユーザータイプを判定中: $current_user (組織: $org)"
    fi

    # INDIVIDUAL_MODE環境変数による明示的指定
    if [[ "${INDIVIDUAL_MODE:-false}" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
        echo "individual_user"
        return 0
    fi

    # 対象組織のメンバーシップを確認する。org が個人アカウント名の場合は
    # /orgs/<name>/members が 404 となり individual_user と判定される
    # （個人アカウントを作成先に指定したケースの意図どおりの挙動）。
    if gh api "orgs/$org/members/$current_user" >/dev/null 2>&1; then
        echo "organization_member"
    else
        echo "individual_user"
    fi
}

# ユーザータイプの判定
# メンバーシップ確認の対象は、TARGET_ORG が明示指定されていればその組織、
# 無ければ既定組織 (DEFAULT_ORG)。TARGET_ORG が明示指定されている場合は、
# ここ（型判定）と後段の作成先妥当性チェックの 2 か所でメンバーシップ API を
# 呼ぶ。型判定とアクセス検証は別関心なので、冗長 1 回は許容し分離を優先する。
MEMBERSHIP_ORG="${TARGET_ORG:-$DEFAULT_ORG}"
USER_TYPE=$(detect_user_type "$CURRENT_USER" "$MEMBERSHIP_ORG")

if [ "${DEBUG:-0}" = "1" ]; then
    echo "🔍 判定結果: $USER_TYPE"
fi

# TARGET_ORG（対象組織）の設定
if [ "$USER_TYPE" = "individual_user" ]; then
    # 個人アカウントに作成する。INDIVIDUAL_MODE が明示指定された場合は
    # 「個人アカウントに作成する」契約を優先し、TARGET_ORG の明示値があっても
    # 本人アカウントへ上書きする（矛盾した指定を安全側に倒す）。それ以外は
    # 明示された TARGET_ORG を尊重し、未指定なら本人アカウントを既定にする。
    if [[ "${INDIVIDUAL_MODE:-false}" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
        # 矛盾指定（INDIVIDUAL_MODE=true かつ TARGET_ORG=組織）は、無視される側を
        # 明示してからユーザーへ知らせる。
        if [ -n "${TARGET_ORG:-}" ] && [ "$TARGET_ORG" != "$CURRENT_USER" ]; then
            echo "⚠️ INDIVIDUAL_MODE が有効なため TARGET_ORG=$TARGET_ORG を無視し、個人アカウント ($CURRENT_USER) を使用します"
        fi
        TARGET_ORG="$CURRENT_USER"
    else
        TARGET_ORG="${TARGET_ORG:-$CURRENT_USER}"
    fi
    echo "👤 個人ユーザーモードで実行中"
    echo "   作成先: $TARGET_ORG (個人アカウント)"
else
    # 組織ユーザーの場合、既定組織 (DEFAULT_ORG) を作成先とする
    TARGET_ORG="${TARGET_ORG:-$DEFAULT_ORG}"
    echo "🏢 組織ユーザーモードで実行中"
    echo "   作成先: $TARGET_ORG (組織)"
fi

# 作成先の妥当性チェック：
# TARGET_ORG が本人の個人アカウント (== CURRENT_USER) でも、CURRENT_USER が
# メンバーである組織でもない場合、そこにはリポジトリを作成できないため停止する。
# （旧実装は「TARGET_ORG == CURRENT_USER」の等値のみを許可していたため、実在の
# 組織を指定すると必ず不整合と判定されていた。実メンバーシップ判定に置き換える。）
# なお INDIVIDUAL_MODE 有効時は上のブロックで TARGET_ORG=$CURRENT_USER に確定する
# ため、この妥当性チェックは等値で必ずスキップされる。
if [ "$TARGET_ORG" != "$CURRENT_USER" ]; then
    if ! gh api "orgs/$TARGET_ORG/members/$CURRENT_USER" >/dev/null 2>&1; then
        echo "⚠️ 作成先組織にアクセスできません"
        echo "  指定組織: $TARGET_ORG"
        echo "  現在のアカウント: $CURRENT_USER"
        echo ""
        echo "$CURRENT_USER は $TARGET_ORG のメンバーではないか、組織が存在しません。"
        echo ""
        echo "対処法："
        echo "  - メンバーのアカウントに切り替える: gh auth switch --user <member>"
        echo "  - 現在のアカウントで個人リポジトリとして作成: TARGET_ORG=$CURRENT_USER $0"
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

if ! git clone "$TOOLS_CLONE_URL" "$TEMP_DIR" 2>/dev/null; then
    echo "❌ リポジトリのクローンに失敗しました ($TOOLS_CLONE_URL)"
    exit 1
fi

cd "$TEMP_DIR"

# 指定された参照（タグ / コミットSHA / ブランチ）に切り替える。
# clone 直後は既定ブランチ（main）に居るため、main 指定時は切り替え不要。
if [ "$SETUP_REF" != "main" ]; then
    # オプション注入対策: git がオプションと解釈するのは先頭が "-" の値のみ。
    # そのような値（例: UNIVERSAL_REF=-x）は不正な参照として拒否する。
    case "$SETUP_REF" in
        -*)
            echo "❌ 不正な参照指定です: $SETUP_REF"
            exit 1
            ;;
    esac

    # SETUP_REF をコミットに解決する。git rev-parse はリビジョンのみを解決し
    # パスは解決しないため、SETUP_REF が（ref ではなく）パスとして誤って checkout され、
    # HEAD が main のまま「固定成功」と表示される事態を防げる。
    # ローカルに無いブランチ名は origin/ 経由でも解決を試みる。
    if SETUP_COMMIT=$(git rev-parse --verify --quiet "${SETUP_REF}^{commit}"); then
        :
    elif SETUP_COMMIT=$(git rev-parse --verify --quiet "origin/${SETUP_REF}^{commit}"); then
        :
    elif [ "$SETUP_REF_LENIENT" = "1" ]; then
        # 後方互換（UNIVERSAL_BRANCH）: 解決できない場合は従来どおり警告して main を使用する。
        echo "⚠️ 指定された参照 ($SETUP_REF) が見つかりません。mainブランチを使用します。"
        SETUP_COMMIT=""
    else
        # 固定版（UNIVERSAL_REF / リリースタグ）が見つからない場合、main への暗黙
        # フォールバックは再現性・監査性を損なうため、エラーとして終了する。
        echo "❌ 指定された参照 ($SETUP_REF) が見つかりません。"
        echo "   タグ名・コミットSHA・ブランチ名が正しいか確認してください。"
        echo "   利用可能なバージョン: https://github.com/${TOOLS_REPO_OWNER}/${TOOLS_REPO}/releases"
        exit 1
    fi

    # 解決できた場合のみ detached HEAD で切り替える（lenient フォールバック時は main のまま）
    if [ -n "$SETUP_COMMIT" ]; then
        if ! git checkout --detach "$SETUP_COMMIT" 2>/dev/null; then
            echo "❌ 参照 ($SETUP_REF) への切り替えに失敗しました。"
            exit 1
        fi
        echo "📌 バージョン固定: $SETUP_REF"
    fi
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

# リポジトリ名規約の override をコンテナへ転送（未設定なら渡さない = 規約デフォルト）
# DOCKER_ENV_VARS は既存慣習どおり無引用展開されるため、安全な文字のみ許可する
valid_repo_name() {
    case "$1" in
        *[!A-Za-z0-9._-]*) return 1 ;;
        "") return 1 ;;
        *) return 0 ;;
    esac
}
if [ -n "${REGISTRY_REPO_NAME:-}" ]; then
    valid_repo_name "$REGISTRY_REPO_NAME" || { echo "❌ REGISTRY_REPO_NAME に使用できない文字が含まれています: $REGISTRY_REPO_NAME" >&2; exit 1; }
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e REGISTRY_REPO_NAME=$REGISTRY_REPO_NAME"
fi
if [ -n "${TOOLS_REPO_NAME:-}" ]; then
    valid_repo_name "$TOOLS_REPO_NAME" || { echo "❌ TOOLS_REPO_NAME に使用できない文字が含まれています: $TOOLS_REPO_NAME" >&2; exit 1; }
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e TOOLS_REPO_NAME=$TOOLS_REPO_NAME"
fi

# 他 org 展開向けの override をコンテナへ転送（未設定なら渡さない = 既定）。
# いずれも無引用展開に載るため、空白を含まない安全な文字種のみ許可する。
if [ -n "${TEMPLATE_REPO:-}" ]; then
    case "$TEMPLATE_REPO" in
        *[!A-Za-z0-9._/-]*|"") echo "❌ TEMPLATE_REPO に使用できない文字が含まれています: $TEMPLATE_REPO" >&2; exit 1 ;;
    esac
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e TEMPLATE_REPO=$TEMPLATE_REPO"
fi
if [ -n "${AUTO_ASSIGN_REVIEWER:-}" ]; then
    case "$AUTO_ASSIGN_REVIEWER" in
        *[!A-Za-z0-9-]*|"") echo "❌ AUTO_ASSIGN_REVIEWER に使用できない文字が含まれています: $AUTO_ASSIGN_REVIEWER" >&2; exit 1 ;;
    esac
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e AUTO_ASSIGN_REVIEWER=$AUTO_ASSIGN_REVIEWER"
fi
if [ -n "${ALDC_URL:-}" ]; then
    case "$ALDC_URL" in
        https://*) ;;
        *) echo "❌ ALDC_URL は https:// で始まる必要があります: $ALDC_URL" >&2; exit 1 ;;
    esac
    # 無引用展開（docker run $DOCKER_ENV_VARS）に載るため、URL 安全文字のみ許可し、
    # 空白（単語分割）と glob 文字（* ? [）を排除する。他の転送変数と同じ流儀。
    case "$ALDC_URL" in
        *[!A-Za-z0-9._~:/%-]*) echo "❌ ALDC_URL に使用できない文字が含まれています: $ALDC_URL" >&2; exit 1 ;;
    esac
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e ALDC_URL=$ALDC_URL"
fi
if [ -n "${SETUP_GIT_EMAIL_DOMAIN:-}" ]; then
    case "$SETUP_GIT_EMAIL_DOMAIN" in
        *[!A-Za-z0-9.-]*|"") echo "❌ SETUP_GIT_EMAIL_DOMAIN に使用できない文字が含まれています: $SETUP_GIT_EMAIL_DOMAIN" >&2; exit 1 ;;
    esac
    DOCKER_ENV_VARS="$DOCKER_ENV_VARS -e SETUP_GIT_EMAIL_DOMAIN=$SETUP_GIT_EMAIL_DOMAIN"
fi

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

# 対話的入力が必要かどうかを判断
DOCKER_OPTIONS="--rm"
if [ "$DOC_TYPE" = "latex" ] && [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]] && [ -n "$DOCUMENT_NAME" ]; then
    # INDIVIDUAL_MODEでDOCUMENT_NAMEが指定されている場合は非対話的モード
    echo "📋 非対話的モードで実行（DOCUMENT_NAME: $DOCUMENT_NAME）"
else
    # その他の場合は対話的モード
    DOCKER_OPTIONS="$DOCKER_OPTIONS -it"
fi

# 統一されたDocker実行（全タイプ共通）
if [ -n "$STUDENT_ID" ]; then
    if ! docker run $DOCKER_OPTIONS $DOCKER_ENV_VARS -v "$TOKEN_FILE:/tmp/gh_token:ro" "$DOCKER_IMAGE_NAME" "$STUDENT_ID"; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        echo "学籍番号: $STUDENT_ID"
        exit 1
    fi
else
    if ! docker run $DOCKER_OPTIONS $DOCKER_ENV_VARS -v "$TOKEN_FILE:/tmp/gh_token:ro" "$DOCKER_IMAGE_NAME"; then
        echo "❌ セットアップスクリプトの実行に失敗しました"
        exit 1
    fi
fi

# 成功メッセージ（クリーンアップは trap で自動実行）
echo ""
echo "✅ $DOC_DESCRIPTION のセットアップが完了しました！"