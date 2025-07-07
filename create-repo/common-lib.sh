#!/bin/bash
# 共通ライブラリ: main*.sh スクリプト用の共通関数・変数定義（リファクタリング版）

# ================================
# 設定・定数
# ================================

# 色定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BRIGHT_WHITE='\033[1;37m'
readonly NC='\033[0m'

# デフォルト設定
readonly DEFAULT_ORG="smkwlab"
readonly STUDENT_ID_PATTERN='^k[0-9]{2}(rs|jk|gjk)[0-9]+$'

# ================================
# ユーティリティ関数
# ================================

# ログ出力（統一フォーマット）
log_info() { echo -e "${GREEN}✓ $*${NC}" >&2; }
log_warn() { echo -e "${YELLOW}⚠️ $*${NC}" >&2; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }
log_debug() { echo -e "${BLUE}🔍 $*${NC}" >&2; }

# エラー終了
die() { log_error "$*"; exit 1; }

# コマンド存在確認
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ================================
# 初期化・設定関数
# ================================

# スクリプト共通初期化
init_script_common() {
    local script_name="$1"
    local script_emoji="$2"
    
    echo "$script_emoji $script_name"
    echo "=============================================="
    
    # 依存関数の呼び出し
    check_github_auth_docker || exit 1
    setup_operation_mode
    get_current_user || exit 1
    
    # グローバル変数として設定
    export OPERATION_MODE INDIVIDUAL_MODE CURRENT_USER
}

# 動作モード設定
setup_operation_mode() {
    local user_type="${USER_TYPE:-organization_member}"
    
    if [ "$user_type" = "individual_user" ]; then
        log_info "👤 個人ユーザーモード有効"
        OPERATION_MODE="individual"
        INDIVIDUAL_MODE=true
    else
        log_info "🏢 組織ユーザーモード（従来通り）"
        OPERATION_MODE="organization"
        INDIVIDUAL_MODE=false
    fi
}

# 現在ユーザー取得
get_current_user() {
    log_debug "GitHub認証情報を確認中..."
    
    if ! CURRENT_USER=$(gh api user --jq .login 2>/dev/null); then
        log_error "GitHub APIアクセスに失敗しました"
        echo "認証トークンを更新してください："
        echo "  gh auth refresh"
        return 1
    fi
    
    log_info "GitHubユーザー: $CURRENT_USER"
}

# ================================
# 認証関連関数
# ================================

# GitHub認証確認（統合版）
check_github_auth_docker() {
    log_debug "GitHub認証を確認中..."
    
    # セキュアファイル認証
    if validate_token_file "/tmp/gh_token"; then
        log_info "GitHub認証済み（セキュアファイル認証）"
        return 0
    fi
    
    # 環境変数認証
    if validate_token_env; then
        log_info "GitHub認証済み（トークン認証）"
        return 0
    fi
    
    # インタラクティブ認証
    if ! gh auth status &>/dev/null; then
        perform_interactive_auth || return 1
    else
        log_info "GitHub認証済み"
    fi
}

# トークンファイル検証
validate_token_file() {
    local token_file="$1"
    
    [ -f "$token_file" ] || return 1
    
    log_info "ホストからセキュアトークンを取得しました"
    export GH_TOKEN=$(cat "$token_file")
    
    if gh auth status &>/dev/null; then
        return 0
    else
        log_error "提供されたトークンが無効です"
        return 1
    fi
}

# 環境変数トークン検証
validate_token_env() {
    [ -n "$GH_TOKEN" ] || return 1
    
    log_info "ホストから認証トークンを取得しました（環境変数）"
    export GH_TOKEN
    
    if gh auth status &>/dev/null; then
        return 0
    else
        log_error "提供されたトークンが無効です"
        return 1
    fi
}

# インタラクティブ認証実行
perform_interactive_auth() {
    log_warn "GitHub認証が必要です"
    echo ""
    echo "=== ブラウザ認証手順 ==="
    echo "1. ブラウザで https://github.com/login/device が開いているはずです"
    echo -e "2. ${GREEN}Continue${NC} ボタンをクリック"
    echo -e "3. 下から2行目の以下のような行の ${YELLOW}XXXX-XXXX${NC} をコピーしてブラウザに入力:"
    echo -e "   ${YELLOW}!${NC} First copy your one-time code: ${BRIGHT_WHITE}XXXX-XXXX${NC}"
    echo -e "4. ${GREEN}Authorize github${NC} ボタンをクリックする"
    echo ""

    if echo -e "Y\n" | gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --scopes "repo,workflow,read:org,gist"; then
        log_info "GitHub認証完了"
    else
        log_error "GitHub認証に失敗しました"
        return 1
    fi
}

# Git認証設定
setup_git_auth() {
    log_debug "Git認証を設定中..."
    
    if ! gh auth setup-git; then
        log_error "Git認証設定に失敗しました"
        log_error "GitHub CLIの認証が正しく設定されているか確認してください"
        return 1
    fi
    
    log_info "Git認証設定完了"
}

# Gitユーザー設定
setup_git_user() {
    local email="${1:-setup@smkwlab.github.io}"
    local name="${2:-Setup Tool}"
    
    git config user.email "$email"
    git config user.name "$name"
}

# ================================
# 学籍番号・組織関連関数
# ================================

# 学籍番号正規化（改良版）
normalize_student_id() {
    local student_id="$1"
    
    # 入力検証
    [ -n "$student_id" ] || die "学籍番号が指定されていません"
    
    # 小文字化
    student_id=$(echo "$student_id" | tr '[:upper:]' '[:lower:]')
    
    # k プリフィックスの自動追加
    if echo "$student_id" | grep -qE '^[0-9]{2}(rs|jk|gjk)[0-9]+$'; then
        local original="$student_id"
        student_id="k${student_id}"
        log_warn "学籍番号を正規化しました: $original → $student_id"
    fi
    
    # 形式検証
    if ! echo "$student_id" | grep -qE "$STUDENT_ID_PATTERN"; then
        log_error "学籍番号の形式が正しくありません: $student_id"
        echo "   正しい形式: k21rs001, k22gjk01 など" >&2
        return 1
    fi
    
    echo "$student_id"
}

# 学籍番号入力
read_student_id() {
    local input_id="$1"
    local examples="${2:-k21rs001, k21gjk01}"
    
    if [ -n "$input_id" ]; then
        echo "$input_id"
        return 0
    fi
    
    echo "" >&2
    echo "学籍番号を入力してください" >&2
    echo "  例: $examples" >&2
    echo "" >&2
    read -p "学籍番号: " student_id
    
    # 無入力の場合、GitHubユーザー名を自動使用
    if [ -z "$student_id" ]; then
        # GitHub CLIの存在確認とユーザー名取得
        if command -v gh >/dev/null 2>&1; then
            local github_username=$(gh api user --jq .login 2>/dev/null || echo "")
            if [ -n "$github_username" ]; then
                # GitHubユーザー名を使用することを通知（開発者向け機能として控えめに）
                echo -e "${BLUE}→ GitHub ユーザー名を使用: $github_username${NC}" >&2
                student_id="$github_username"
            else
                # GitHub CLIは存在するが認証されていない場合
                log_debug "GitHub ユーザー名の取得に失敗しました"
            fi
        else
            # GitHub CLIがインストールされていない場合
            log_debug "GitHub CLIがインストールされていません"
        fi
    fi
    
    echo "$student_id"
}

# 組織設定決定
determine_organization() {
    local default_org="${1:-$DEFAULT_ORG}"
    
    if [ -n "$TARGET_ORG" ]; then
        echo "$TARGET_ORG"
        log_info "指定された組織: $TARGET_ORG"
    elif [ -n "$GITHUB_REPOSITORY" ]; then
        local org=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
        echo "$org"
        log_info "自動検出された組織: $org"
    else
        echo "$default_org"
        log_warn "デフォルト組織を使用: $default_org"
    fi
}

# 組織メンバーシップ確認
check_organization_membership() {
    local org="$1"
    local user="$2"
    
    log_debug "🏢 組織アクセス権限を確認中..."
    
    if ! gh api "orgs/${org}/members/${user}" >/dev/null 2>&1; then
        log_error "${org} 組織のメンバーではありません"
        echo ""
        echo "以下を確認してください："
        echo "  1. GitHub 組織への招待メールを確認"
        echo "  2. 組織のメンバーシップが有効化されているか確認"
        echo "  3. 正しいGitHubアカウントでログインしているか確認"
        echo ""
        echo "招待が届いていない場合は、担当教員にお問い合わせください。"
        return 1
    fi
    
    log_info "${org} 組織のメンバーシップ確認済み"
}

# 組織アクセス確認（条件付き）
check_organization_access() {
    local organization="$1"
    
    [ "$INDIVIDUAL_MODE" = false ] && check_organization_membership "$organization" "$CURRENT_USER" || exit 1
}

# ================================
# リポジトリ操作関数
# ================================

# リポジトリパス決定
determine_repository_path() {
    local organization="$1"
    local repo_name="$2"
    
    if [ "$INDIVIDUAL_MODE" = false ]; then
        echo "${organization}/${repo_name}"
    else
        echo "${CURRENT_USER}/${repo_name}"
    fi
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
        log_warn "キャンセルしました"
        return 1
    fi
    
    return 0
}

# リポジトリ作成（統一インターフェース）
create_repository() {
    local repo_path="$1"
    local template_repo="$2"
    local visibility="${3:-private}"
    local clone_flag="${4:-true}"
    local description="${5:-}"
    
    local create_args=("$repo_path" "--template=$template_repo")
    
    # 可視性設定
    if [ "$visibility" = "public" ]; then
        create_args+=("--public")
    else
        create_args+=("--private")
    fi
    
    # Description設定
    [ -n "$description" ] && create_args+=("--description" "$description")
    
    # クローン設定
    [ "$clone_flag" = "true" ] && create_args+=("--clone")
    
    if gh repo create "${create_args[@]}"; then
        log_info "リポジトリを作成しました: https://github.com/$repo_path"
        return 0
    else
        log_error "リポジトリの作成に失敗しました"
        echo "- 既に同名のリポジトリが存在する可能性があります" >&2
        echo "- 組織への権限が不足している可能性があります" >&2
        return 1
    fi
}

# リポジトリクローン
clone_repository() {
    local repo_url="$1"
    local repo_name="${2:-$(basename "$repo_url" .git)}"
    
    log_debug "📦 リポジトリをクローン中..."
    
    if ! git clone "$repo_url"; then
        log_error "リポジトリのクローンに失敗しました"
        echo "リポジトリ: $repo_url"
        return 1
    fi
    
    log_info "リポジトリクローン完了"
    cd "$repo_name" || return 1
}

# Git操作（コミット・プッシュ）
commit_and_push() {
    local commit_message="$1"
    local branch="${2:-main}"
    
    git add . >/dev/null 2>&1
    git commit -m "$commit_message" >/dev/null 2>&1
    
    if git push origin "$branch" >/dev/null 2>&1; then
        log_info "変更をプッシュしました"
        return 0
    else
        log_error "プッシュに失敗しました"
        return 1
    fi
}

# ================================
# Issue・レポート関連関数
# ================================

# リポジトリ作成Issue生成
create_repository_issue() {
    local repo_name="$1"
    local student_id="$2"
    local repo_type="${3:-latex}"
    local organization="${4:-$DEFAULT_ORG}"
    
    log_info "Registry Manager登録中..."
    
    local issue_body
    issue_body=$(generate_issue_body "$organization" "$repo_name" "$student_id" "$repo_type")
    
    local issue_number
    if issue_number=$(gh issue create \
        --repo "${organization}/thesis-management-tools" \
        --title "📋 リポジトリ登録依頼: ${organization}/${repo_name}" \
        --body "$issue_body" 2>&1 | grep -oE '[0-9]+$'); then
        
        # Issue作成成功時は何も出力しない（簡潔にする）
        return 0
    else
        log_warn "Registry Manager登録に失敗しました（続行します）"
        return 1
    fi
}

# Issue本文生成
generate_issue_body() {
    local organization="$1"
    local repo_name="$2"
    local student_id="$3"
    local repo_type="${4:-latex}"  # デフォルトは最も汎用的な latex タイプ
    
    cat << EOF
## リポジトリ登録依頼

### リポジトリ情報
- **リポジトリ**: [${organization}/${repo_name}](https://github.com/${organization}/${repo_name})
- **学生ID**: ${student_id}
- **リポジトリタイプ**: ${repo_type}
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
*学生ID: ${student_id} | リポジトリ: ${repo_name} | 作成: $(date '+%Y-%m-%d %H:%M') JST*
EOF
}

# ================================
# Orphan Branch 管理関数
# ================================

#
# initial ブランチ（orphan）の作成
# 
# Args:
#   $1: placeholder_file - 作成するプレースホルダーファイル名（例: "index.html", ".tex_placeholder"）
#   $2: files_to_remove - 削除対象ファイルパターン（例: "index.html", "*.tex *.cls *.sty"）  
#   $3: context - コンテキスト名（例: "ISE report", "thesis"） - エラーメッセージ用
#
create_orphan_initial_branch() {
    local placeholder_file="$1"
    local files_to_remove="$2"
    local context="$3"
    
    # 引数の検証
    if [ -z "$placeholder_file" ] || [ -z "$context" ]; then
        log_error "create_orphan_initial_branch: 必須引数が不足しています"
        log_error "使用方法: create_orphan_initial_branch <placeholder_file> <files_to_remove> <context>"
        return 1
    fi
    
    log_info "📝 initial ブランチを作成中..."
    
    # orphan ブランチとして initial を作成（履歴を継承しない）
    if ! git checkout --orphan initial >/dev/null 2>&1; then
        log_error "orphan ブランチの作成に失敗しました"
        return 1
    fi
    
    # 指定されたファイルを削除（オプション）
    if [ -n "$files_to_remove" ]; then
        if ! git rm --cached --ignore-unmatch $files_to_remove >/dev/null 2>&1; then
            log_warn "${context}ファイルの削除に失敗しました。ファイルが存在しない可能性があります。"
        fi
    fi
    
    # プレースホルダーファイルを作成
    > "$placeholder_file"
    if ! git add "$placeholder_file" >/dev/null 2>&1; then
        log_error "プレースホルダーファイルの追加に失敗しました"
        return 1
    fi
    
    # コミット作成
    local commit_message="Setup initial branch with empty placeholder

- Empty placeholder for student content creation
- Orphan branch with no history for proper diff comparison"
    
    if ! git commit -m "$commit_message" >/dev/null 2>&1; then
        log_error "initial ブランチのコミットに失敗しました"
        return 1
    fi
    
    # リモートへプッシュ
    if ! git push origin initial >/dev/null 2>&1; then
        log_error "initial ブランチのプッシュに失敗しました"
        return 1
    fi
    
    log_info "✓ initial ブランチ作成完了"
    return 0
}

#
# review-branch の作成（initial から分岐後、main の内容をマージ）
#
# Args:
#   $1: context - コンテキスト名（例: "ISE report", "thesis"） - エラーメッセージ用
#
create_review_branch_from_initial() {
    local context="$1"
    
    # 引数の検証
    if [ -z "$context" ]; then
        log_error "create_review_branch_from_initial: context引数が必要です"
        log_error "使用方法: create_review_branch_from_initial <context>"
        return 1
    fi
    
    log_info "📝 review-branch ブランチを作成中..."
    
    # review-branch を initial から作成
    if ! git checkout -b review-branch >/dev/null 2>&1; then
        log_error "review-branch の作成に失敗しました"
        return 1
    fi
    
    # main ブランチの内容をマージして学生の作業内容を含める
    if ! git merge main --no-edit --allow-unrelated-histories >/dev/null 2>&1; then
        log_error "❌ review-branch への main ブランチのマージでエラーが発生しました"
        log_warn "   ⚠️ 通常この段階ではコンフリクトは発生しません"
        log_warn "   考えられる原因: テンプレートの問題、または学生による誤った変更"
        log_warn "   管理者にお問い合わせください"
        return 1
    fi
    
    # リモートへプッシュ
    if ! git push origin review-branch >/dev/null 2>&1; then
        log_error "❌ review-branch のプッシュに失敗しました"
        log_warn "   考えられる原因: 権限不足、ネットワークの問題、またはリモートリポジトリの設定"
        return 1
    fi
    
    log_info "✓ review-branch 作成完了"
    return 0
}

#
# orphan branch ワークフロー全体のセットアップ（ラッパー関数）
#
# Args:
#   $1: placeholder_file - 作成するプレースホルダーファイル名（例: "index.html", ".tex_placeholder"）
#   $2: files_to_remove - 削除対象ファイルパターン（例: "index.html", "*.tex *.cls *.sty"）  
#   $3: context - コンテキスト名（例: "ISE report", "thesis"） - エラーメッセージ用
#   $4: return_branch - 処理後に戻るブランチ名（オプション、デフォルト: main）
#
setup_orphan_branch_workflow() {
    local placeholder_file="$1"
    local files_to_remove="$2"
    local context="$3"
    local return_branch="${4:-main}"
    
    # 引数の検証
    if [ -z "$placeholder_file" ] || [ -z "$context" ]; then
        log_error "setup_orphan_branch_workflow: 必須引数が不足しています"
        log_error "使用方法: setup_orphan_branch_workflow <placeholder_file> <files_to_remove> <context> [return_branch]"
        return 1
    fi
    
    log_info "🌿 orphan branch ワークフローを開始します..."
    
    # STEP 1: initial ブランチ作成
    if ! create_orphan_initial_branch "$placeholder_file" "$files_to_remove" "$context"; then
        log_error "initial ブランチの作成に失敗しました"
        return 1
    fi
    
    # STEP 2: review-branch 作成
    if ! create_review_branch_from_initial "$context"; then
        log_error "review-branch の作成に失敗しました"
        return 1
    fi
    
    # STEP 3: 指定されたブランチに戻る
    if ! git checkout "$return_branch" >/dev/null 2>&1; then
        log_warn "⚠️ $return_branch ブランチへの切り替えに失敗しました"
        log_info "現在のブランチ: $(git branch --show-current)"
    else
        log_info "✓ $return_branch ブランチに戻りました"
    fi
    
    log_info "✅ orphan branch ワークフロー完了"
    return 0
}

#
# LaTeX環境セットアップ関数
#
setup_latex_environment() {
    log_info "LaTeX環境をセットアップ中..."
    
    # curlでaldcスクリプトを実行（メッセージ抑制）
    if ALDC_QUIET=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)" 2>/dev/null; then
        log_info "LaTeX環境のセットアップ完了"
        return 0
    else
        log_warn "LaTeX環境は手動設定が必要"
        log_info "手動セットアップ手順:"
        log_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)\""
        return 1
    fi
}