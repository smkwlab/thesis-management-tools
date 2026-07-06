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

# 学籍番号の取得（INDIVIDUAL_MODE のときはスキップして空文字）
STUDENT_ID=$(read_student_id_if_needed "$1" "卒業論文の例: k21rs001, 修士論文の例: k21gjk01") || exit 1

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

# リポジトリ名の決定
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    THESIS_TYPE="sotsuron"
    REPO_NAME="thesis"
    log_info "個人モード: 卒業論文リポジトリとして設定します"
else
    THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID")
    if [ "$THESIS_TYPE" = "shuuron" ]; then
        REPO_NAME="${STUDENT_ID}-master"
        log_info "修士論文リポジトリとして設定します"
    else
        REPO_NAME="${STUDENT_ID}-sotsuron"
        log_info "卒業論文リポジトリとして設定します"
    fi
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

# テンプレートファイルの整理（aldc 実行後に行う必要がある: Issue #433）
cleanup_template_files

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

# Registry Manager連携（INDIVIDUAL_MODEでない場合のみ）
if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    # registry の正式語彙へ変換（内部値 shuuron はテンプレート整理用、issue #471）
    if [ "$THESIS_TYPE" = "shuuron" ]; then
        run_registry_integration "master"
    else
        run_registry_integration "$THESIS_TYPE"
    fi
fi

# 完了メッセージ
print_completion_message "論文執筆の開始方法:
  https://github.com/$REPO_PATH/blob/main/WRITING-GUIDE.md"
