#!/bin/bash
# 論文リポジトリセットアップスクリプト
# ローカル環境またはDocker内で実行

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🎓 論文リポジトリセットアップツール (Docker版)"
echo "=============================================="

# 実行環境の表示
if [ -n "$GITHUB_ACTIONS" ]; then
    echo -e "${GREEN}🔧 実行環境: GitHub Actions${NC}"
    echo -e "${GREEN}📁 ワークフロー: $GITHUB_WORKFLOW${NC}"
elif [ -n "$RUNNER_OS" ]; then
    echo -e "${GREEN}🔧 実行環境: GitHub Runner${NC}"
else
    echo -e "${GREEN}🔧 実行環境: ローカル Docker${NC}"
fi
echo ""

# GitHub認証
echo "GitHub認証を確認中..."
if ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}GitHub認証が必要です${NC}"
    echo ""
    echo "=== 自動ブラウザ認証 ==="
    echo "1. ブラウザが自動で開きます（開かない場合は手動で https://github.com/login/device を開く）"
    echo "2. Continue ボタンをクリックする"
    echo "3. 以下の '! First copy your one-time code: XXXX-XXXX' の XXXX-XXXX をブラウザに入力する"
    echo "4. Authorize github ボタンをクリックする"
    
    # ブラウザを自動で開く
    echo ""
    echo "🌐 ブラウザを開いています..."
    if command -v open &> /dev/null; then
        # macOS
        open "https://github.com/login/device"
    elif command -v cmd.exe &> /dev/null; then
        # WSL
        cmd.exe /c start "https://github.com/login/device"
    elif command -v wslview &> /dev/null; then
        # WSL2 with wslu
        wslview "https://github.com/login/device"
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "https://github.com/login/device"
    else
        echo "⚠️ ブラウザを自動で開けませんでした。手動で https://github.com/login/device を開いてください"
    fi
    
    sleep 2

    if echo -e "Y\n" | gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key; then
        echo -e "${GREEN}✓ GitHub認証完了${NC}"
    else
        echo -e "${RED}エラー: GitHub認証に失敗しました${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ GitHub認証済み${NC}"
fi

# 組織/ユーザーの設定
if [ -n "$TARGET_ORG" ]; then
    # 環境変数で明示的に指定された場合
    ORGANIZATION="$TARGET_ORG"
    echo -e "${GREEN}✓ 指定された組織: $ORGANIZATION${NC}"
elif [ -n "$GITHUB_REPOSITORY" ]; then
    # GitHub Actions等で実行されている場合、リポジトリから組織を取得
    ORGANIZATION=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
    echo -e "${GREEN}✓ 自動検出された組織: $ORGANIZATION${NC}"
else
    # デフォルトは smkwlab
    ORGANIZATION="smkwlab"
    echo -e "${YELLOW}✓ デフォルト組織を使用: $ORGANIZATION${NC}"
fi

# テンプレートリポジトリの設定
if [ -n "$TEMPLATE_REPO" ]; then
    TEMPLATE_REPOSITORY="$TEMPLATE_REPO"
else
    TEMPLATE_REPOSITORY="${ORGANIZATION}/sotsuron-template"
fi
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力または引数から取得
if [ -n "$1" ]; then
    STUDENT_ID="$1"
    echo -e "${GREEN}学籍番号: $STUDENT_ID${NC}"
else
    echo ""
    echo "学籍番号を入力してください"
    echo "  卒業論文の例: k21rs001"
    echo "  修士論文の例: k21gjk01"
    echo ""
    read -p "学籍番号: " STUDENT_ID
fi

# 論文タイプの判定
if [[ "$STUDENT_ID" =~ k[0-9]{2}rs[0-9]{3} ]]; then
    THESIS_TYPE="sotsuron"
    echo -e "${GREEN}✓ 卒業論文として設定します${NC}"
elif [[ "$STUDENT_ID" =~ k[0-9]{2}gjk[0-9]{2} ]]; then
    THESIS_TYPE="thesis"
    echo -e "${GREEN}✓ 修士論文として設定します${NC}"
else
    echo -e "${RED}エラー: 学籍番号の形式が正しくありません${NC}"
    exit 1
fi

REPO_NAME="${STUDENT_ID}-${THESIS_TYPE}"
FULL_REPO_NAME="${ORGANIZATION}/${REPO_NAME}"

# GitHubユーザー名の取得
echo "GitHub認証情報を確認中..."
GITHUB_USER=$(gh api user --jq .login)
echo -e "${GREEN}✓ GitHubユーザー: $GITHUB_USER${NC}"

# 組織への権限確認
echo "組織への権限を確認中..."
if gh api orgs/"$ORGANIZATION"/members/"$GITHUB_USER" &>/dev/null; then
    echo -e "${GREEN}✓ 組織 $ORGANIZATION のメンバーです${NC}"
elif [ "$ORGANIZATION" = "$GITHUB_USER" ]; then
    echo -e "${GREEN}✓ 個人アカウントにリポジトリを作成します${NC}"
else
    echo -e "${RED}エラー: 組織 $ORGANIZATION への権限がありません${NC}"
    echo "対処法:"
    echo "1. 組織の管理者に招待を依頼してください"
    echo "2. または個人アカウントに作成: docker run -e TARGET_ORG=$GITHUB_USER ..."
    exit 1
fi

# リポジトリ作成
echo "リポジトリ ${FULL_REPO_NAME} を作成中..."
if gh repo create "$FULL_REPO_NAME" \
    --template "$TEMPLATE_REPOSITORY" \
    --private \
    --clone \
    --description "${STUDENT_ID}の${THESIS_TYPE}"; then
    echo -e "${GREEN}✓ リポジトリ作成完了${NC}"
else
    echo -e "${RED}リポジトリ作成に失敗しました${NC}"
    exit 1
fi

cd "$REPO_NAME"

# Git設定
echo "Git設定を確認中..."
GITHUB_EMAIL=$(gh api user --jq .email)
GITHUB_NAME=$(gh api user --jq .name)

if [ "$GITHUB_EMAIL" = "null" ] || [ -z "$GITHUB_EMAIL" ]; then
    GITHUB_EMAIL="${GITHUB_USER}@users.noreply.github.com"
fi
if [ "$GITHUB_NAME" = "null" ] || [ -z "$GITHUB_NAME" ]; then
    GITHUB_NAME="$GITHUB_USER"
fi

git config user.email "$GITHUB_EMAIL"
git config user.name "$GITHUB_NAME"
echo -e "${GREEN}✓ Git設定完了: $GITHUB_NAME <$GITHUB_EMAIL>${NC}"

# 不要なファイルを削除
echo "テンプレートファイルを整理中..."
if [ "$THESIS_TYPE" = "sotsuron" ]; then
    rm -f thesis.tex abstract.tex
    git add -A && git commit -m "Remove graduate thesis template files"
else
    rm -f sotsuron.tex gaiyou.tex example*.tex
    git add -A && git commit -m "Remove undergraduate thesis template files"
fi

# devcontainer セットアップ
echo "LaTeX環境をセットアップ中..."
if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)"; then
    echo -e "${GREEN}✓ LaTeX環境のセットアップ完了${NC}"
else
    echo -e "${YELLOW}⚠ LaTeX環境のセットアップに失敗しました${NC}"
fi

# 初期ブランチ構成
echo "ブランチを設定中..."
git checkout -b initial-empty
git rm -rf . &>/dev/null || true
git commit --allow-empty -m "初期状態（空のブランチ）"
git push -u origin initial-empty

git checkout main
git checkout -b 0th-draft
git push -u origin 0th-draft

git checkout -b review-branch
git push -u origin review-branch

git checkout 0th-draft

# 完了メッセージ
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL: https://github.com/${FULL_REPO_NAME}"
echo ""
echo "次の手順:"
echo "1. リポジトリをクローン:"
echo "   git clone https://github.com/${FULL_REPO_NAME}.git"
echo "2. VS Code で開く:"
echo "   cd ${REPO_NAME}"
echo "   code ."
echo "3. 'Reopen in Container' を選択"
echo ""
echo "詳細: https://github.com/${ORGANIZATION}/thesis-management-tools/blob/main/docs/WRITING-GUIDE.md"
