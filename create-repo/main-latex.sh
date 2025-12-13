#!/bin/bash
# 汎用LaTeXリポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "汎用LaTeXリポジトリセットアップツール" "📝"

# 設定
ORGANIZATION=$(determine_organization)
TEMPLATE_REPOSITORY="smkwlab/latex-template"  # 常に固定
VISIBILITY="public"

log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# INDIVIDUAL_MODEの場合は学籍番号をスキップ
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    log_debug "個人モード: 学籍番号の入力をスキップします"
    STUDENT_ID=""
else
    STUDENT_ID=$(read_student_id "$1")
    STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
    log_info "学籍番号: $STUDENT_ID"
fi

# ドキュメント名の入力
read_document_name() {
    if [ -n "$DOCUMENT_NAME" ]; then
        log_info "ドキュメント名: $DOCUMENT_NAME（環境変数指定）"
        return 0
    fi

    echo ""
    echo "📝 ドキュメント名を入力してください (デフォルト: latex):"
    echo "   例: research-note, report2024, experiment-log"
    read -r -p "> " DOCUMENT_NAME

    DOCUMENT_NAME="${DOCUMENT_NAME:-latex}"

    if ! [[ "$DOCUMENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "ドキュメント名は英数字、ハイフン、アンダースコアのみ使用可能です"
        DOCUMENT_NAME=""
        read_document_name
    fi
}

read_document_name

# リポジトリ名の決定
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    REPO_NAME="${DOCUMENT_NAME}"
else
    REPO_NAME="${STUDENT_ID}-${DOCUMENT_NAME}"
fi

# 標準セットアップフロー
run_standard_setup "latex"

# LaTeX環境のセットアップ
setup_latex_environment

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# 変更をコミットしてプッシュ
commit_and_push "Initial customization for ${DOCUMENT_NAME}

- Setup LaTeX environment
" || exit 1

# Registry Manager連携（INDIVIDUAL_MODEでない場合のみ）
if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    run_registry_integration "latex"
fi

# 完了メッセージ
print_completion_message "次のステップ:
1. main.texを編集して文書を作成
2. git add, commit, pushで変更を保存
3. GitHub Actionsで自動的にPDFが生成されます"
