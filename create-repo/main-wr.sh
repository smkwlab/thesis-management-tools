#!/bin/bash
# 週間報告リポジトリセットアップスクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BRIGHT_WHITE='\033[1;37m'
NC='\033[0m'

echo "📝 週間報告リポジトリセットアップツール"
echo "=============================================="

# GitHub認証
echo "GitHub認証を確認中..."

# セキュアファイルからトークンを読み取り（フォールバック：環境変数）
if [ -f "/tmp/gh_token" ]; then
    echo -e "${GREEN}✓ ホストからセキュアトークンを取得しました${NC}"
    export GH_TOKEN=$(cat /tmp/gh_token)
    
    # トークンの有効性を確認
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓ GitHub認証済み（セキュアファイル認証）${NC}"
    else
        echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
        exit 1
    fi
elif [ -n "$GH_TOKEN" ]; then
    echo -e "${GREEN}✓ ホストから認証トークンを取得しました（環境変数）${NC}"
    export GH_TOKEN
    
    # トークンの有効性を確認
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓ GitHub認証済み（トークン認証）${NC}"
    else
        echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
        exit 1
    fi
elif ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}GitHub認証が必要です${NC}"
    echo ""
    echo "=== ブラウザ認証手順 ==="
    echo "1. ブラウザで https://github.com/login/device が開いているはずです"
    echo -e "2. ${GREEN}Continue${NC} ボタンをクリック"
    echo -e "3. 下から2行目の以下のような行の ${YELLOW}XXXX-XXXX${NC} をコピーしてブラウザに入力:"
    echo -e "   ${YELLOW}!${NC} First copy your one-time code: ${BRIGHT_WHITE}XXXX-XXXX${NC}"
    echo -e "4. ${GREEN}Authorize github${NC} ボタンをクリックする"
    echo ""

    if echo -e "Y\n" | gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --scopes "repo,workflow,read:org,gist"; then
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

# テンプレートリポジトリの設定（週報用）
if [ -n "$TEMPLATE_REPO" ]; then
    TEMPLATE_REPOSITORY="$TEMPLATE_REPO"
else
    TEMPLATE_REPOSITORY="${ORGANIZATION}/wr-template"
fi
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力または引数から取得
if [ -n "$1" ]; then
    STUDENT_ID="$1"
else
    echo ""
    echo "学籍番号を入力してください"
    echo "  例: k21rs001, k21gjk01"
    echo ""
    read -p "学籍番号: " STUDENT_ID
fi

# 学籍番号の正規化（自動補正）
normalize_student_id() {
    local input="$1"
    
    # 空文字チェック
    if [ -z "$input" ]; then
        echo ""
        return 1
    fi
    
    # 小文字に変換
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    # 先頭に k がない場合は追加
    if [ "${input:0:1}" != "k" ]; then
        input="k$input"
    fi
    
    # 正規化結果を返す
    echo "$input"
    return 0
}

# 学籍番号を正規化
NORMALIZED_STUDENT_ID=$(normalize_student_id "$STUDENT_ID")

if [ -z "$NORMALIZED_STUDENT_ID" ]; then
    echo -e "${RED}エラー: 学籍番号が入力されていません${NC}"
    exit 1
fi

# 入力値と正規化後が異なる場合は表示
if [ "$STUDENT_ID" != "$NORMALIZED_STUDENT_ID" ]; then
    echo -e "${YELLOW}✓ 学籍番号を正規化しました: $STUDENT_ID → $NORMALIZED_STUDENT_ID${NC}"
fi

# 正規化後の学籍番号を使用
STUDENT_ID="$NORMALIZED_STUDENT_ID"

# 学籍番号の形式チェック（週報は学年・専攻問わず）
if [[ ! "$STUDENT_ID" =~ ^k[0-9]{2}(rs[0-9]{3}|jk[0-9]{3}|gjk[0-9]{2})$ ]]; then
    echo -e "${RED}エラー: 学籍番号の形式が正しくありません${NC}"
    echo "期待される形式:"
    echo "  学部生: k[年度2桁]rs[番号3桁] (例: k21rs001)"
    echo "  大学院生: k[年度2桁]gjk[番号2桁] (例: k21gjk01)"
    echo "入力された値: $STUDENT_ID"
    exit 1
fi

REPO_NAME="${STUDENT_ID}-wr"
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
    --description "${STUDENT_ID}の週間報告"; then
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

# devcontainer セットアップ
echo "LaTeX環境をセットアップ中..."
if ALDC_QUIET=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)"; then
    echo -e "${GREEN}✓ LaTeX環境のセットアップ完了${NC}"
    
    # aldc一時ファイルの削除
    echo "一時ファイルを削除中..."
    if find . -name "*-aldc" -type f -delete; then
        echo -e "${GREEN}✓ 一時ファイル削除完了${NC}"
    else
        echo -e "${YELLOW}⚠ 一時ファイル削除で警告が発生しましたが、処理を続行します${NC}"
    fi
    
    # LaTeX環境セットアップ完了をコミット
    git add -A && git commit -m "Add LaTeX development environment with devcontainer" >/dev/null 2>&1
else
    echo -e "${YELLOW}⚠ LaTeX環境のセットアップに失敗しました${NC}"
fi

# GitHub CLIの認証情報をgitに設定
echo "Git認証を設定中..."
if ! gh auth setup-git; then
    echo -e "${RED}✗ Git認証設定に失敗しました${NC}"
    echo -e "${RED}GitHub CLIの認証が正しく設定されているか確認してください${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git認証設定完了${NC}"

# 初期プッシュ（週報は単純な main ブランチ運用）
echo "初期プッシュを実行中..."
git push -u origin main >/dev/null 2>&1

# 完了メッセージ
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL:"
echo "  https://github.com/${FULL_REPO_NAME}"
echo ""
echo "週間報告の作成方法:"
echo "  1. VS Code でリポジトリを開く"
echo "  2. 20yy-mm-dd.tex をコピーして日付入りファイルを作成"
echo "  3. 内容を編集してコミット・プッシュ"