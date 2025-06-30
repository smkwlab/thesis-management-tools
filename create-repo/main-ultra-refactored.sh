#!/bin/bash
# 論文リポジトリセットアップスクリプト（超リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

echo "🎓 論文リポジトリセットアップツール"
echo "=============================================="

# GitHub認証（Docker内用）
check_github_auth_docker || exit 1

# 動作モードの判定
OPERATION_MODE=$(determine_operation_mode)
INDIVIDUAL_MODE=false
if [ "$OPERATION_MODE" = "individual" ]; then
    INDIVIDUAL_MODE=true
    echo -e "${BLUE}   - ブランチ保護: 無効${NC}"
    echo -e "${BLUE}   - Registry登録: 無効${NC}"
    echo -e "${BLUE}   - Issue作成: 無効${NC}"
else
    echo -e "${GREEN}   - ブランチ保護: 有効${NC}"
    echo -e "${GREEN}   - Registry登録: 有効${NC}"
    echo -e "${GREEN}   - Issue作成: 有効${NC}"
fi

# 組織設定（共通関数使用）
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
if [ -n "$TEMPLATE_REPO" ]; then
    TEMPLATE_REPOSITORY="$TEMPLATE_REPO"
else
    TEMPLATE_REPOSITORY="${ORGANIZATION}/sotsuron-template"
fi
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力（共通関数使用）
STUDENT_ID=$(read_student_id "$1" "卒業論文の例: k21rs001, 修士論文の例: k21gjk01")

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1

# 学籍番号から論文の種類を判定
determine_thesis_type() {
    local student_id="$1"
    
    if echo "$student_id" | grep -qE '^k[0-9]{2}rs[0-9]+$'; then
        echo "sotsuron"
        return 0
    elif echo "$student_id" | grep -qE '^k[0-9]{2}(jk|gjk)[0-9]+$'; then
        echo "shuuron"
        return 0
    else
        echo -e "${RED}エラー: 学籍番号の形式を認識できません: $student_id${NC}" >&2
        echo "  卒業論文: k21rs001 形式" >&2
        echo "  修士論文: k21gjk01 形式" >&2
        return 1
    fi
}

# 論文タイプの判定と表示
THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID") || exit 1
if [ "$THESIS_TYPE" = "sotsuron" ]; then
    echo -e "${GREEN}✓ 卒業論文リポジトリとして設定します${NC}"
else
    echo -e "${GREEN}✓ 修士論文リポジトリとして設定します${NC}"
fi

# リポジトリ名の生成
REPO_NAME="${STUDENT_ID}-${THESIS_TYPE}"

# 現在のユーザーアカウントを取得
echo "GitHub認証情報を確認中..."
if ! CURRENT_USER=$(gh api user --jq .login 2>/dev/null); then
    echo -e "${RED}エラー: GitHub APIアクセスに失敗しました${NC}"
    echo "認証トークンを更新してください："
    echo "  gh auth refresh"
    exit 1
fi
echo -e "${GREEN}✓ GitHubユーザー: $CURRENT_USER${NC}"

# 組織へのアクセス権限確認（共通関数使用）
if [ "$INDIVIDUAL_MODE" = false ]; then
    check_organization_membership "$ORGANIZATION" "$CURRENT_USER" || exit 1
fi

# リポジトリパスの決定
if [ "$INDIVIDUAL_MODE" = false ]; then
    REPO_PATH="${ORGANIZATION}/${REPO_NAME}"
else
    REPO_PATH="${CURRENT_USER}/${REPO_NAME}"
fi

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}エラー: リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# リポジトリ作成確認（共通関数使用）
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成（共通関数使用）
echo ""
echo "リポジトリ ${REPO_PATH} を作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "private" "true" || exit 1

# リポジトリディレクトリに移動
cd "$REPO_NAME"

# Git設定確認
git_user=$(git config --global user.name 2>/dev/null || echo "")
git_email=$(git config --global user.email 2>/dev/null || echo "")

if [ -z "$git_user" ] || [ -z "$git_email" ]; then
    # Git認証設定（共通関数使用）
    setup_git_auth || exit 1
    
    # Gitユーザー設定（共通関数使用）
    setup_git_user "thesis-setup@smkwlab.github.io" "Thesis Setup Tool"
else
    echo -e "${GREEN}✓ Git設定完了: $git_user <$git_email>${NC}"
fi

# テンプレートファイルの整理
echo "テンプレートファイルを整理中..."

# 開発者向けファイルを削除
echo "開発者向けファイルを削除中..."
rm -f CLAUDE.md 2>/dev/null || true

# LaTeX環境のセットアップ
echo "LaTeX環境をセットアップ中..."
if command -v aldc &> /dev/null; then
    if aldc --force-update; then
        echo -e "${GREEN}✓ LaTeX環境のセットアップ完了${NC}"
    else
        echo -e "${YELLOW}⚠️ LaTeX環境のセットアップに失敗しました（手動設定が必要）${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ aldcコマンドが見つかりません（LaTeX環境は手動設定が必要）${NC}"
fi

# 一時ファイルの削除
echo "一時ファイルを削除中..."
find . -name "*.aux" -o -name "*.log" -o -name "*.dvi" -o -name "*.toc" \
     -o -name "*.lof" -o -name "*.lot" -o -name "*.out" \
     -o -name "*.fls" -o -name "*.fdb_latexmk" -o -name "*.synctex.gz" \
     -o -name "*.nav" -o -name "*.snm" -o -name "*.vrb" \
     -o -name "*.bcf" -o -name "*.bbl" -o -name "*.blg" -o -name "*.run.xml" | xargs rm -f 2>/dev/null || true
echo -e "${GREEN}✓ 一時ファイル削除完了${NC}"

# Git認証を再設定（プッシュ用）
setup_git_auth || exit 1

# ブランチ設定
echo "ブランチを設定中..."
git add .
if ! git diff-index --quiet HEAD --; then
    git commit -m "Initialize repository with template cleanup" || true
fi

# review-branch が存在しない場合のみ作成
if ! git rev-parse --verify review-branch >/dev/null 2>&1; then
    git checkout -b review-branch
    git push -u origin review-branch
fi

# mainブランチに戻る
git checkout main

# Issue作成（組織モードのみ）
if [ "$INDIVIDUAL_MODE" = false ]; then
    # 処理ロックファイルの生成
    LOCK_KEY=$(echo -n "${STUDENT_ID}-${REPO_NAME}-$(date +%s)" | sha256sum | cut -c1-8)
    echo -e "${GREEN}✅ 処理ロック獲得完了${NC}"
    
    # 学生IDの重複チェック
    echo "📋 既存学生ID登録状況をチェック中..."
    echo "   thesis-student-registry での登録状況を確認中..."
    
    # thesis-student-registryリポジトリの存在確認
    if gh repo view "${ORGANIZATION}/thesis-student-registry" >/dev/null 2>&1; then
        # 既存のIssueをチェック
        EXISTING_ISSUES=$(gh issue list --repo "${ORGANIZATION}/thesis-management-tools" --state all --search "$STUDENT_ID" --json number,title | jq -r '.[] | select(.title | contains("'"$STUDENT_ID"'")) | .number' || echo "")
        
        if [ -n "$EXISTING_ISSUES" ]; then
            echo -e "${YELLOW}⚠️ 学生ID $STUDENT_ID に関連する既存のIssueが見つかりました:${NC}"
            for issue_num in $EXISTING_ISSUES; do
                echo "   Issue #$issue_num"
            done
        else
            echo -e "${GREEN}✅ 学生ID重複チェック完了（新規登録）${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ thesis-student-registryリポジトリが見つかりません${NC}"
    fi
    
    # リポジトリ作成Issueの生成（共通関数使用）
    create_repository_issue "$REPO_NAME" "$STUDENT_ID" "$THESIS_TYPE" "$ORGANIZATION"
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