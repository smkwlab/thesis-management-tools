#!/bin/bash
# 論文リポジトリセットアップスクリプト

set -e

# スクリプトディレクトリを保存（templates/ 参照用）
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリの読み込み
source "${SCRIPT_DIR}/common-lib.sh"

# 共通初期化
init_script_common "論文リポジトリセットアップツール" "🎓"

# 組織設定
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/sotsuron-template}"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力
STUDENT_ID=$(read_student_id "$1" "卒業論文の例: k21rs001, 修士論文の例: k21gjk01")

# 学籍番号の正規化と検証
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

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

THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID") || exit 1

# リポジトリ名の決定
if [ "$THESIS_TYPE" = "shuuron" ]; then
    REPO_NAME="${STUDENT_ID}-master"
else
    REPO_NAME="${STUDENT_ID}-sotsuron"
fi

echo -e "${GREEN}✓ GitHubユーザー: $CURRENT_USER${NC}"
[ "$THESIS_TYPE" = "sotsuron" ] && echo -e "${GREEN}✓ 卒業論文リポジトリとして設定します${NC}" || echo -e "${GREEN}✓ 修士論文リポジトリとして設定します${NC}"

# リポジトリパス決定
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}エラー: リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 組織アクセス確認
check_organization_access "$ORGANIZATION"

# 作成確認
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成
echo ""
echo "リポジトリ ${REPO_PATH} を作成中..."

create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "private" "true" || exit 1

cd "$REPO_NAME"

# Git設定
setup_git_auth || exit 1
setup_git_user "setup-thesis@smkwlab.github.io" "Thesis Setup Tool"

# LaTeX環境のセットアップ
setup_latex_environment

# レビューワークフロー機能の有効化
echo "レビューワークフロー機能を有効化中..."
mkdir -p .devcontainer
touch .devcontainer/.review-workflow
echo -e "${GREEN}✓ レビューワークフロー機能を有効化しました${NC}"

# STEP 1: main ブランチでファイルをセットアップ
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true
rm -rf docs/ 2>/dev/null || true
find . -name '*-aldc' -exec rm -rf {} + 2>/dev/null || true

# 論文タイプに応じて不要なファイルを削除
if [ "$THESIS_TYPE" = "shuuron" ]; then
    # 修士論文: sotsuron.tex, gaiyou.tex, example.tex, example-gaiyou.tex を削除
    rm -f sotsuron.tex gaiyou.tex example.tex example-gaiyou.tex 2>/dev/null || true
    echo "修士論文用: sotsuron.tex, gaiyou.tex, example.tex, example-gaiyou.tex を削除しました"
elif [ "$THESIS_TYPE" = "sotsuron" ]; then
    # 卒業論文: thesis.tex, abstract.tex を削除
    rm -f thesis.tex abstract.tex 2>/dev/null || true
    echo "卒業論文用: thesis.tex, abstract.tex を削除しました"
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
    echo -e "${GREEN}✓ main ブランチセットアップ完了${NC}"
else
    echo -e "${RED}❌ main ブランチのプッシュに失敗しました${NC}"
    exit 1
fi

# ドラフトブランチを作成
setup_review_workflow "0th-draft" || exit 1

# 初期ドラフトをコミット・プッシュ
echo "📤 初期ドラフトをコミット中..."
commit_and_push "Initial setup for ${THESIS_TYPE}" "0th-draft" || exit 1

# Registry Manager連携（組織ユーザーのみ）
if [ "$INDIVIDUAL_MODE" = false ] && gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
    if ! create_repository_issue "$REPO_NAME" "$STUDENT_ID" "$THESIS_TYPE" "$ORGANIZATION"; then
        echo -e "${YELLOW}⚠️ Registry Manager登録でエラーが発生しました。手動で登録が必要な場合があります。${NC}"
    fi
fi

# 完了メッセージ
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL:"
echo "  https://github.com/$REPO_PATH"
echo ""
echo "論文執筆の開始方法:"
echo "  https://github.com/$REPO_PATH/blob/main/WRITING-GUIDE.md"

