#!/bin/bash
# 論文リポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "論文リポジトリセットアップツール" "🎓"

# 設定
ORGANIZATION=$(determine_organization)
TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/sotsuron-template}"
VISIBILITY="private"

log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# 学籍番号の入力と検証
STUDENT_ID=$(read_student_id "$1" "卒業論文の例: k21rs001, 修士論文の例: k21gjk01")
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
log_info "学籍番号: $STUDENT_ID"

# 論文タイプの判定
determine_thesis_type() {
    local student_id="$1"
    # kxxの次の文字がgの場合は修士論文、それ以外は卒業論文
    if echo "$student_id" | grep -qE '^k[0-9]{2}g'; then
        echo "shuuron"
    else
        echo "sotsuron"
    fi
}

THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID")

# リポジトリ名の決定
if [ "$THESIS_TYPE" = "shuuron" ]; then
    REPO_NAME="${STUDENT_ID}-master"
    log_info "修士論文リポジトリとして設定します"
else
    REPO_NAME="${STUDENT_ID}-sotsuron"
    log_info "卒業論文リポジトリとして設定します"
fi

# 標準セットアップフロー
run_standard_setup "thesis"

# LaTeX環境のセットアップ
setup_latex_environment

# 論文タイプに応じて不要なファイルを削除
if [ "$THESIS_TYPE" = "shuuron" ]; then
    rm -f sotsuron.tex gaiyou.tex example.tex example-gaiyou.tex 2>/dev/null || true
    log_debug "修士論文用: sotsuron.tex, gaiyou.tex, example.tex, example-gaiyou.tex を削除しました"
else
    rm -f thesis.tex abstract.tex 2>/dev/null || true
    log_debug "卒業論文用: thesis.tex, abstract.tex を削除しました"
fi

# smkwlab 組織メンバーの場合は auto-assign 設定を追加
setup_auto_assign_for_organization_members

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# main ブランチでの初期セットアップコミット
git add -u
git add .github/ 2>/dev/null || true
git add .devcontainer/ 2>/dev/null || true
git commit -m "Initial setup for ${THESIS_TYPE}" >/dev/null 2>&1 || true

if git push origin main >/dev/null 2>&1; then
    log_info "main ブランチセットアップ完了"
else
    die "main ブランチのプッシュに失敗しました"
fi

# ドラフトブランチを作成
setup_review_workflow "0th-draft" || exit 1

# 初期ドラフトをコミット・プッシュ
commit_and_push "Initial setup for ${THESIS_TYPE}" "0th-draft" || exit 1

# Registry Manager連携
run_registry_integration "$THESIS_TYPE"

# 完了メッセージ
print_completion_message "論文執筆の開始方法:
  https://github.com/$REPO_PATH/blob/main/WRITING-GUIDE.md"
