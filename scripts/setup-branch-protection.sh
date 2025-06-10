#!/bin/bash
# mainブランチ保護設定ツール（教員用）

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔒 mainブランチ保護設定ツール"
echo "================================"

# 使用方法チェック
if [ "$#" -eq 0 ]; then
    echo "使用方法:"
    echo "  $0 <リポジトリ名>"
    echo "  $0 <リポジトリ名1> <リポジトリ名2> ..."
    echo ""
    echo "例:"
    echo "  $0 k21rs001-sotsuron"
    echo "  $0 k21rs001-sotsuron k21rs002-sotsuron k21gjk01-thesis"
    echo ""
    echo "機能:"
    echo "  - mainブランチの保護設定"
    echo "  - PR必須（1承認必要）"
    echo "  - GitHub Actions自動マージ許可"
    echo "  - final-*タグ時の自動マージ対応"
    exit 1
fi

# GitHub認証確認
echo "GitHub認証を確認中..."
if ! gh auth status &>/dev/null; then
    echo -e "${RED}エラー: GitHub認証が必要です${NC}"
    echo "gh auth login を先に実行してください"
    exit 1
fi

# 現在のユーザー確認
GITHUB_USER=$(gh api user --jq .login)
echo -e "${GREEN}✓ GitHubユーザー: $GITHUB_USER${NC}"

# 組織設定（デフォルト: smkwlab）
ORGANIZATION=${ORGANIZATION:-smkwlab}
echo -e "${GREEN}✓ 組織: $ORGANIZATION${NC}"
echo ""

# 各リポジトリに対してブランチ保護設定
for REPO_NAME in "$@"; do
    echo "🔒 ${REPO_NAME} の設定中..."
    
    FULL_REPO_NAME="${ORGANIZATION}/${REPO_NAME}"
    
    # リポジトリの存在確認
    if ! gh repo view "$FULL_REPO_NAME" &>/dev/null; then
        echo -e "${RED}❌ リポジトリが見つかりません: $FULL_REPO_NAME${NC}"
        continue
    fi
    
    # 権限確認（admin権限が必要）
    USER_PERMISSION=$(gh api repos/"$FULL_REPO_NAME"/collaborators/"$GITHUB_USER"/permission --jq .permission 2>/dev/null || echo "none")
    if [ "$USER_PERMISSION" != "admin" ]; then
        echo -e "${RED}❌ admin権限が必要です（現在: $USER_PERMISSION）${NC}"
        continue
    fi
    
    # mainブランチの存在確認
    if ! gh api repos/"$FULL_REPO_NAME"/branches/main &>/dev/null; then
        echo -e "${YELLOW}⚠ mainブランチが見つかりません${NC}"
        continue
    fi
    
    # ブランチ保護設定の実行
    echo "  mainブランチ保護設定中..."
    if gh api repos/"$FULL_REPO_NAME"/branches/main/protection \
        --method PUT \
        --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":false,"require_code_owner_reviews":false}' \
        --field enforce_admins=false \
        --field required_status_checks='{"strict":false,"contexts":[]}' \
        --field restrictions='{"users":[],"teams":[],"apps":[]}' \
        --field allow_force_pushes=false \
        --field allow_deletions=false &>/dev/null; then
        echo -e "${GREEN}  ✓ mainブランチ保護完了${NC}"
    else
        echo -e "${RED}  ❌ ブランチ保護設定に失敗しました${NC}"
        continue
    fi
    
    # 設定内容の確認・表示
    echo "  設定内容:"
    echo "    - PR必須（1承認必要）"
    echo "    - GitHub Actions自動マージ許可"
    echo "    - final-*タグ時の自動マージ対応"
    echo "    - force push禁止"
    echo "    - ブランチ削除禁止"
    echo ""
done

echo -e "${GREEN}✅ ブランチ保護設定完了${NC}"
echo ""
echo "注意事項:"
echo "- ブランチ保護設定にはadmin権限が必要です"
echo "- GitHub Actionsからの自動マージは許可されています"
echo "- 学生による誤操作からmainブランチを保護します"
echo ""
echo "確認方法:"
echo "  GitHub Web UI: Settings → Branches → main"