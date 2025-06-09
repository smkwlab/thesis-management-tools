#!/bin/bash
# 学生用論文リポジトリセットアップスクリプト
# Windows (Git Bash) / macOS 対応

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🎓 論文リポジトリセットアップツール"
echo "======================================"

# 学籍番号の入力
read -p "学籍番号を入力してください (例: k21rs001): " STUDENT_ID

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

# GitHub CLI の確認
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) がインストールされていません${NC}"
    echo "インストール方法:"
    echo "  macOS: brew install gh"
    echo "  Windows: https://cli.github.com/ からダウンロード"
    exit 1
fi

# GitHub 認証確認
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}GitHub にログインしてください${NC}"
    gh auth login
fi

# リポジトリ作成
echo "リポジトリを作成中..."
gh repo create "$REPO_NAME" \
    --template smkwlab/sotsuron-template \
    --private \
    --clone \
    --description "${STUDENT_ID}の${THESIS_TYPE}"

cd "$REPO_NAME"

# 不要なファイルを削除
echo "テンプレートファイルを整理中..."
if [ "$THESIS_TYPE" = "sotsuron" ]; then
    rm -f thesis.tex abstract.tex
else
    rm -f sotsuron.tex gaiyou.tex example*.tex
fi

# devcontainer セットアップ
echo "LaTeX 環境をセットアップ中..."
if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)"; then
    echo -e "${GREEN}✓ LaTeX 環境のセットアップ完了${NC}"
else
    echo -e "${YELLOW}⚠ LaTeX 環境のセットアップに失敗しました${NC}"
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

# review ブランチ
git checkout -b review-branch
git push -u origin review-branch

# VS Code で開く
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "次の手順:"
echo "1. VS Code でフォルダを開く: code ."
echo "2. 'Reopen in Container' を選択"
echo "3. sotsuron.tex または thesis.tex を編集開始"
echo ""
echo "詳細な使い方: https://github.com/smkwlab/thesis-management-tools/blob/main/docs/WRITING-GUIDE.md"

# VS Code で開くか確認
read -p "VS Code で開きますか？ (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    code .
fi