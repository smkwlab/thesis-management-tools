#!/bin/bash
# 論文リポジトリセットアップスクリプト（最終リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "論文リポジトリセットアップツール" "🎓"

# 機能設定情報は内部処理のみ（表示不要）

# 組織設定（共通関数使用）
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/sotsuron-template}"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力（共通関数使用）
STUDENT_ID=$(read_student_id "$1" "卒業論文の例: k21rs001, 修士論文の例: k21gjk01")

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1

# 論文タイプの判定
determine_thesis_type() {
    local student_id="$1"
    
    if echo "$student_id" | grep -qE '^k[0-9]{2}rs[0-9]+$'; then
        echo "sotsuron"
    elif echo "$student_id" | grep -qE '^k[0-9]{2}(jk|gjk)[0-9]+$'; then
        echo "shuuron"
    else
        echo -e "${RED}エラー: 学籍番号の形式を認識できません: $student_id${NC}" >&2
        return 1
    fi
}

THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID") || exit 1
REPO_NAME="${STUDENT_ID}-${THESIS_TYPE}"

echo -e "${GREEN}✓ GitHubユーザー: $CURRENT_USER${NC}"
[ "$THESIS_TYPE" = "sotsuron" ] && echo -e "${GREEN}✓ 卒業論文リポジトリとして設定します${NC}" || echo -e "${GREEN}✓ 修士論文リポジトリとして設定します${NC}"

# 組織アクセス確認（共通関数使用）
check_organization_access "$ORGANIZATION"

# リポジトリパス決定（共通関数使用）
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}エラー: リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認（共通関数使用）
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成（共通関数使用）
echo ""
echo "リポジトリ ${REPO_PATH} を作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "private" "true" || exit 1

cd "$REPO_NAME"

# Git設定（共通関数使用）
setup_git_auth || exit 1
setup_git_user "thesis-setup@smkwlab.github.io" "Thesis Setup Tool"

# テンプレート整理
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true

# LaTeX環境のセットアップ（共通関数使用）
setup_latex_environment

# ブランチ設定
echo "ブランチを設定中..."
git add . >/dev/null 2>&1
git diff-index --quiet HEAD -- || git commit -m "Initialize repository with template cleanup" >/dev/null 2>&1 || true

if ! git rev-parse --verify review-branch >/dev/null 2>&1; then
    git checkout -b review-branch >/dev/null 2>&1
    git push -u origin review-branch >/dev/null 2>&1
fi
git checkout main >/dev/null 2>&1

# Issue作成（組織モードのみ）
[ "$INDIVIDUAL_MODE" = false ] && create_repository_issue "$REPO_NAME" "$STUDENT_ID" "$THESIS_TYPE" "$ORGANIZATION"

# 完了メッセージ
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL:"
echo "  https://github.com/$REPO_PATH"
echo ""
echo "論文執筆の開始方法:"
echo "  https://github.com/$REPO_PATH/blob/main/WRITING-GUIDE.md"