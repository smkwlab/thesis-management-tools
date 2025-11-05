#!/bin/bash
# 週報リポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "週報リポジトリセットアップツール" "📝"

# 組織設定
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/wr-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力
STUDENT_ID=$(read_student_id "$1")

# 学籍番号の正規化と検証
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# リポジトリ名の生成
REPO_NAME="${STUDENT_ID}-wr"

# 組織アクセス確認
check_organization_access "$ORGANIZATION"

# リポジトリパス決定
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}❌ リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成
echo ""
echo "📁 リポジトリを作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "private" "true" || exit 1
cd "$REPO_NAME"

# LaTeX環境のセットアップ
setup_latex_environment

# STEP 1: main ブランチでファイルをセットアップ
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true
rm -rf docs/ 2>/dev/null || true
find . -name '*-aldc' -exec rm -rf {} + 2>/dev/null || true
git add .

# Git設定
setup_git_auth || exit 1
setup_git_user "setup-wr@smkwlab.github.io" "Weekly Report Setup Tool"

# 変更をコミットしてプッシュ
echo "📤 変更をコミット中..."
commit_and_push "Initialize weekly report repository for ${STUDENT_ID}

- Setup LaTeX environment for weekly reports
" || exit 1

# Registry Manager連携（組織ユーザーのみ）
if [ "$INDIVIDUAL_MODE" = false ] && gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
    if ! create_repository_issue "$REPO_NAME" "$STUDENT_ID" "wr" "$ORGANIZATION"; then
        echo -e "${YELLOW}⚠️ Registry Manager登録でエラーが発生しました。手動で登録が必要な場合があります。${NC}"
    fi
fi

# 完了メッセージ
echo ""
echo "===============================================" 
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "リポジトリ: https://github.com/${REPO_PATH}"
echo ""
echo "次のステップ:"
echo "1. テンプレートファイル (20yy-mm-dd.tex) をコピーして、日付に基づいたファイル名 (例: 2024-04-01.tex) に変更後、編集"
echo "2. git add, commit, pushで変更を保存"
echo "3. 毎週新しい週報ファイルを追加"
echo ""
echo "=============================================="
