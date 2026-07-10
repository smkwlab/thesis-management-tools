#!/bin/bash
# 学会ポスターリポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "学会ポスターリポジトリセットアップツール" "📊"

# 設定
ORGANIZATION=$(determine_organization)
# poster-template は個人ユーザー（ORGANIZATION=個人アカウント）も利用する共有テンプレ
# のため、org 追従にはせず既定を smkwlab に固定する。他 org で独自テンプレを使う場合は
# TEMPLATE_REPO で上書きする。
TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-smkwlab/poster-template}"
VISIBILITY="private"

log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# 学籍番号の取得（INDIVIDUAL_MODE のときはスキップして空文字）
STUDENT_ID=$(read_student_id_if_needed "$1") || exit 1

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

# リポジトリ名の決定
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    REPO_NAME="${POSTER_NAME}"
else
    REPO_NAME="${STUDENT_ID}-${POSTER_NAME}"
fi

# 標準セットアップフロー
run_standard_setup "poster"

# LaTeX環境のセットアップ
setup_latex_environment

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# テンプレートファイルの整理（aldc 実行後に行う必要がある: Issue #433）
cleanup_template_files

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
