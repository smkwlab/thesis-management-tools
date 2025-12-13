#!/bin/bash
# 週報リポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "週報リポジトリセットアップツール" "📝"

# 設定
ORGANIZATION=$(determine_organization)
TEMPLATE_REPOSITORY="${ORGANIZATION}/wr-template"
VISIBILITY="private"

log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# INDIVIDUAL_MODEの場合は学籍番号をスキップ
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    log_debug "個人モード: 学籍番号の入力をスキップします"
    STUDENT_ID=""
else
    # 学籍番号の入力と検証
    STUDENT_ID=$(read_student_id "$1")
    STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
    log_info "学籍番号: $STUDENT_ID"
fi

# リポジトリ名の生成
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    REPO_NAME="weekly-report"
else
    REPO_NAME="${STUDENT_ID}-wr"
fi

# 標準セットアップフロー
run_standard_setup "wr"

# LaTeX環境のセットアップ
setup_latex_environment

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# 変更をコミットしてプッシュ
commit_and_push "Initialize weekly report repository for ${STUDENT_ID}

- Setup LaTeX environment for weekly reports
" || exit 1

# Registry Manager連携（INDIVIDUAL_MODEでない場合のみ）
if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    run_registry_integration "wr"
fi

# 完了メッセージ
print_completion_message "次のステップ:
1. テンプレートファイル (20yy-mm-dd.tex) をコピーして、日付に基づいたファイル名 (例: 2024-04-01.tex) に変更後、編集
2. git add, commit, pushで変更を保存
3. 毎週新しい週報ファイルを追加"
