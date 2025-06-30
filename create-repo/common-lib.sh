#!/bin/bash
# 共通ライブラリ: main*.sh スクリプト用の共通関数・変数定義

# ================================
# 色定義
# ================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export BRIGHT_WHITE='\033[1;37m'
export NC='\033[0m'

# ================================
# 共通関数
# ================================

# 学籍番号の正規化
normalize_student_id() {
    local student_id="$1"
    
    # 小文字化
    student_id=$(echo "$student_id" | tr '[:upper:]' '[:lower:]')
    
    # k プリフィックスの自動追加
    if echo "$student_id" | grep -qE '^[0-9]{2}(rs|jk|gjk)[0-9]+$'; then
        local original="$student_id"
        student_id="k${student_id}"
        echo -e "${YELLOW}✓ 学籍番号を正規化しました: $original → $student_id${NC}" >&2
    fi
    
    # 形式検証
    if ! echo "$student_id" | grep -qE '^k[0-9]{2}(rs|jk|gjk)[0-9]+$'; then
        echo -e "${RED}❌ 学籍番号の形式が正しくありません: $student_id${NC}" >&2
        echo "   正しい形式: k21rs001, k22gjk01 など" >&2
        return 1
    fi
    
    echo "$student_id"
}

# GitHub認証確認（Docker内用）
check_github_auth_docker() {
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
            return 1
        fi
    elif [ -n "$GH_TOKEN" ]; then
        echo -e "${GREEN}✓ ホストから認証トークンを取得しました（環境変数）${NC}"
        export GH_TOKEN
        
        # トークンの有効性を確認
        if gh auth status &>/dev/null; then
            echo -e "${GREEN}✓ GitHub認証済み（トークン認証）${NC}"
        else
            echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
            return 1
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
            return 1
        fi
    else
        echo -e "${GREEN}✓ GitHub認証済み${NC}"
    fi
}

# Git認証設定
setup_git_auth() {
    echo "Git認証を設定中..."
    if ! gh auth setup-git; then
        echo -e "${RED}✗ Git認証設定に失敗しました${NC}"
        echo -e "${RED}GitHub CLIの認証が正しく設定されているか確認してください${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Git認証設定完了${NC}"
}

# Gitユーザー設定（Docker環境用）
setup_git_user() {
    local email="${1:-setup@smkwlab.github.io}"
    local name="${2:-Setup Tool}"
    
    git config user.email "$email"
    git config user.name "$name"
}

# リポジトリクローン（エラーハンドリング付き）
clone_repository() {
    local repo_url="$1"
    local repo_name="${2:-$(basename "$repo_url" .git)}"
    
    echo "📦 リポジトリをクローン中..."
    if ! git clone "$repo_url"; then
        echo -e "${RED}❌ リポジトリのクローンに失敗しました${NC}"
        echo "リポジトリ: $repo_url"
        return 1
    fi
    
    echo -e "${GREEN}✓ リポジトリクローン完了${NC}"
    cd "$repo_name" || return 1
}

# 組織メンバーシップ確認
check_organization_membership() {
    local org="$1"
    local user="$2"
    
    echo "🏢 組織アクセス権限を確認中..."
    if ! gh api "orgs/${org}/members/${user}" >/dev/null 2>&1; then
        echo -e "${RED}❌ ${org} 組織のメンバーではありません${NC}"
        echo ""
        echo "以下を確認してください："
        echo "  1. GitHub 組織への招待メールを確認"
        echo "  2. 組織のメンバーシップが有効化されているか確認"
        echo "  3. 正しいGitHubアカウントでログインしているか確認"
        echo ""
        echo "招待が届いていない場合は、担当教員にお問い合わせください。"
        return 1
    fi
    
    echo -e "${GREEN}✅ ${org} 組織のメンバーシップ確認済み${NC}"
}

# ユーザー確認プロンプト
confirm_creation() {
    local repo_path="$1"
    
    echo ""
    echo -e "${BRIGHT_WHITE}🎯 作成予定リポジトリ: $repo_path${NC}"
    echo ""
    read -p "続行しますか? [Y/n]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        echo -e "${YELLOW}キャンセルしました${NC}"
        return 1
    fi
    return 0
}

# 動作モード判定
determine_operation_mode() {
    local user_type="${USER_TYPE:-organization_member}"
    
    if [ "$user_type" = "individual_user" ]; then
        echo -e "${BLUE}👤 個人ユーザーモード有効${NC}"
        echo "individual"
    else
        echo -e "${GREEN}🏢 組織ユーザーモード（従来通り）${NC}"
        echo "organization"
    fi
}

# 組織設定の決定
determine_organization() {
    local default_org="${1:-smkwlab}"
    
    if [ -n "$TARGET_ORG" ]; then
        echo "$TARGET_ORG"
        echo -e "${GREEN}✓ 指定された組織: $TARGET_ORG${NC}" >&2
    elif [ -n "$GITHUB_REPOSITORY" ]; then
        local org=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
        echo "$org"
        echo -e "${GREEN}✓ 自動検出された組織: $org${NC}" >&2
    else
        echo "$default_org"
        echo -e "${YELLOW}✓ デフォルト組織を使用: $default_org${NC}" >&2
    fi
}

# 学籍番号の入力
read_student_id() {
    local input_id="$1"
    local examples="${2:-k21rs001, k21gjk01}"
    
    if [ -n "$input_id" ]; then
        echo "$input_id"
    else
        echo "" >&2
        echo "学籍番号を入力してください" >&2
        echo "  例: $examples" >&2
        echo "" >&2
        read -p "学籍番号: " student_id
        echo "$student_id"
    fi
}

# リポジトリ作成（統一インターフェース）
create_repository() {
    local repo_path="$1"
    local template_repo="$2"
    local visibility="${3:-private}"
    local clone_flag="${4:-true}"
    
    local create_args="$repo_path --template=$template_repo"
    
    if [ "$visibility" = "public" ]; then
        create_args="$create_args --public"
    else
        create_args="$create_args --private"
    fi
    
    if [ "$clone_flag" = "true" ]; then
        create_args="$create_args --clone"
    fi
    
    if gh repo create $create_args; then
        echo -e "${GREEN}✓ リポジトリを作成しました: https://github.com/$repo_path${NC}" >&2
        return 0
    else
        echo -e "${RED}エラー: リポジトリの作成に失敗しました${NC}" >&2
        echo "- 既に同名のリポジトリが存在する可能性があります" >&2
        echo "- 組織への権限が不足している可能性があります" >&2
        return 1
    fi
}

# Git設定とコミット・プッシュ
commit_and_push() {
    local commit_message="$1"
    local branch="${2:-main}"
    
    git add .
    git commit -m "$commit_message"
    
    if git push origin "$branch"; then
        echo -e "${GREEN}✓ 変更をプッシュしました${NC}" >&2
        return 0
    else
        echo -e "${RED}エラー: プッシュに失敗しました${NC}" >&2
        return 1
    fi
}

# リポジトリ作成Issue生成
create_repository_issue() {
    local repo_name="$1"
    local student_id="$2"
    local repo_type="${3:-sotsuron}"
    local organization="${4:-smkwlab}"
    
    echo "📋 ブランチ保護設定依頼Issueを作成中..."
    
    local issue_body="## リポジトリ登録依頼

### リポジトリ情報
- **リポジトリ**: [${organization}/${repo_name}](https://github.com/${organization}/${repo_name})
- **学生ID**: ${student_id}
- **作成日時**: $(date '+%Y-%m-%d %H:%M') JST

### 処理内容
- [ ] リポジトリをシステムに登録
- [ ] ブランチ保護設定（論文リポジトリのみ）
- [ ] 設定完了を確認: [リポジトリ設定](https://github.com/${organization}/${repo_name}/settings/branches)

### 一括処理オプション
複数の学生を一括処理する場合：
\`\`\`bash
cd thesis-management-tools/scripts
# GitHub Actionsの自動処理を利用
# または手動で一括実行
./bulk-setup-protection.sh
\`\`\`

### ブランチ保護ルール（論文リポジトリのみ）
- 1つ以上の承認レビューが必要
- 新しいコミット時に古いレビューを無効化
- フォースプッシュとブランチ削除を禁止

---
*この Issue は学生の setup.sh 実行時に自動生成されました*
*学生ID: ${student_id} | リポジトリ: ${repo_name} | 作成: $(date '+%Y-%m-%d %H:%M') JST*"
    
    local issue_number
    if issue_number=$(gh issue create \
        --repo "${organization}/thesis-management-tools" \
        --title "📋 リポジトリ登録依頼: ${organization}/${repo_name}" \
        --body "$issue_body" 2>&1 | grep -oE '[0-9]+$'); then
        echo -e "${GREEN}✅ ブランチ保護設定依頼Issue作成完了${NC}"
        echo "   Issue #${issue_number}: https://github.com/${organization}/thesis-management-tools/issues/${issue_number}"
        echo -e "${GREEN}ℹ️  教員が上記Issueを確認してブランチ保護設定を実行します${NC}"
    else
        echo -e "${YELLOW}⚠️ Issue作成に失敗しました（続行します）${NC}"
    fi
}