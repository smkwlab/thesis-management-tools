#!/bin/bash
# 学会ポスターリポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "学会ポスターリポジトリセットアップツール" "📊"

# 組織設定
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定（常にsmkwlab/poster-templateを使用）
TEMPLATE_REPOSITORY="smkwlab/poster-template"
log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# INDIVIDUAL_MODEの場合は学籍番号をスキップ（柔軟な値判定）
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    log_debug "個人モード: 学籍番号の入力をスキップします"
    STUDENT_ID=""
else
    # 学籍番号の入力
    STUDENT_ID=$(read_student_id "$1")

    # 学籍番号の正規化と検証
    STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
    log_info "学籍番号: $STUDENT_ID"
fi

# ポスター名の入力
read_poster_name() {
    if [ -n "$POSTER_NAME" ]; then
        log_info "ポスター名: $POSTER_NAME（環境変数指定）"
        return 0
    fi

    if [ -n "$DOCUMENT_NAME" ]; then
        POSTER_NAME="$DOCUMENT_NAME"
        log_info "ポスター名: $POSTER_NAME（環境変数指定）"
        return 0
    fi

    echo ""
    echo "📊 ポスター名を入力してください (デフォルト: poster):"
    echo "   例: jxiv2025-poster, conference2024, symposium-poster"
    read -r -p "> " POSTER_NAME

    POSTER_NAME="${POSTER_NAME:-poster}"

    if ! [[ "$POSTER_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "ポスター名は英数字、ハイフン、アンダースコアのみ使用可能です"
        POSTER_NAME=""
        read_poster_name
    fi
}

read_poster_name

# リポジトリ名の決定（柔軟な値判定）
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    REPO_NAME="${POSTER_NAME}"
else
    REPO_NAME="${STUDENT_ID}-${POSTER_NAME}"
fi

# 組織アクセス確認
check_organization_access "$ORGANIZATION"

# リポジトリパス決定
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    die "リポジトリ $REPO_PATH は既に存在します"
fi

# 作成確認
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成
echo ""
echo "📁 リポジトリを作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "public" "true" || exit 1
cd "$REPO_NAME"

# LaTeX環境のセットアップ
setup_latex_environment

# STEP 1: main ブランチでファイルをセットアップ
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true
rm -rf docs/ 2>/dev/null || true
find . -name '*-aldc' -exec rm -rf {} + 2>/dev/null || true

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# Git設定
setup_git_auth || exit 1
setup_git_user "setup-poster@smkwlab.github.io" "Poster Setup Tool"

# 変更をコミットしてプッシュ
commit_and_push "Initial setup for ${POSTER_NAME}

- Configure LaTeX environment
- Remove template documentation files
- Prepare for poster development" || exit 1

# Registry Manager連携（INDIVIDUAL_MODEでない場合のみ）
if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    run_registry_integration "poster"
fi

# 完了メッセージ
print_completion_message "次のステップ:
1. a0poster.texを編集してポスターを作成
2. git add, commit, pushで変更を保存
3. GitHub Actionsで自動的にPDFが生成されます

ポスターテンプレートの特徴:
- A0サイズ学会ポスター用
- tikzposterによる柔軟なレイアウト
- LuaLaTeXで日本語完全対応
- 複数のテーマとスタイルから選択可能"
