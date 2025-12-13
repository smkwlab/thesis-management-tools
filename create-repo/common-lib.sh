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
    
    # 環境変数認証（Git Bashからの受け渡し含む）
    if validate_token_env; then
        log_info "GitHub認証済み（環境変数認証）"
        return 0
    else
        log_debug "環境変数GH_TOKENが未設定または無効。セキュアファイル認証を試みます。"
    fi
    
    # セキュアファイル認証
    if validate_token_file "/tmp/gh_token"; then
        log_info "GitHub認証済み（セキュアファイル認証）"
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
    
    # INDIVIDUAL_MODEが有効でない場合のみ組織メンバーシップをチェック
    if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
        check_organization_membership "$organization" "$CURRENT_USER" || exit 1
    fi
}

# ================================
# リポジトリ操作関数
# ================================

# リポジトリパス決定
determine_repository_path() {
    local organization="$1"
    local repo_name="$2"
    
    if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
        echo "${CURRENT_USER}/${repo_name}"
    else
        echo "${organization}/${repo_name}"
    fi
}

# ユーザー確認プロンプト
confirm_creation() {
    local repo_path="$1"
    
    echo ""
    echo -e "${BRIGHT_WHITE}🎯 作成予定リポジトリ: $repo_path${NC}"
    echo ""
    
    # INDIVIDUAL_MODEの場合は自動承認（柔軟な値判定）
    if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
        echo "📋 個人モード: 自動的に続行します"
        return 0
    fi
    
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
# Note: git add . を使用するのは、セットアップ時に新規作成されるファイル
# （.devcontainer/, .github/ 等）も含めてステージングする必要があるため。
# 呼び出し元で git add -u を使用する場合は、事前にステージングを行うこと。
commit_and_push() {
    local commit_message="$1"
    local branch="${2:-main}"

    echo "📤 変更をコミット中..."
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
# レビューワークフロー管理関数
# ================================

#
# レビューワークフロー設定
#
# Args:
#   $1: draft_branch - ドラフトブランチ名（例: 0th-draft）
#
setup_review_workflow() {
    local draft_branch="$1"

    if [ -z "$draft_branch" ]; then
        log_error "setup_review_workflow: ドラフトブランチ名が指定されていません"
        return 1
    fi

    log_info "🌿 ドラフトブランチを作成中: $draft_branch"

    if ! git checkout -b "$draft_branch" >/dev/null 2>&1; then
        log_error "$draft_branch ブランチの作成に失敗しました"
        return 1
    fi

    log_info "✅ ドラフトブランチ作成完了"
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

# smkwlab 組織メンバー用の auto-assign 設定追加
#
# 組織メンバーの場合のみ、PR自動レビュワー割り当て設定を追加します。
# テンプレートリポジトリには含めず、setup時に動的に追加することで
# セキュアバイデフォルトを実現します。
#
# 環境変数:
#   USER_TYPE - "organization_member" または "individual_user"
#   SCRIPT_DIR - スクリプトのディレクトリパス（templates/ を参照）
#
# 戻り値:
#   0 - 成功（設定追加完了または不要）
setup_auto_assign_for_organization_members() {
    # 組織メンバーの場合のみ auto-assign 設定を追加
    if [ "$USER_TYPE" = "organization_member" ]; then
        log_info "組織メンバー: auto-assign設定を追加します"

        # .github/workflows ディレクトリが存在することを確認
        mkdir -p .github/workflows

        # スクリプトディレクトリを特定（SCRIPT_DIR が未定義の場合）
        local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
        local template_dir="${script_dir}/templates"

        # テンプレートディレクトリの存在確認
        if [ ! -d "${template_dir}" ]; then
            log_error "テンプレートディレクトリが見つかりません: ${template_dir}"
            return 1
        fi

        # テンプレートファイルをコピー
        if [ -f "${template_dir}/autoassignees.yml" ]; then
            cp "${template_dir}/autoassignees.yml" .github/workflows/
            log_info "  ✓ .github/workflows/autoassignees.yml を追加"
        else
            log_warn "  ⚠️ テンプレートファイルが見つかりません: ${template_dir}/autoassignees.yml"
        fi

        if [ -f "${template_dir}/auto_assign_myteams.yml" ]; then
            cp "${template_dir}/auto_assign_myteams.yml" .github/
            log_info "  ✓ .github/auto_assign_myteams.yml を追加"
        else
            log_warn "  ⚠️ テンプレートファイルが見つかりません: ${template_dir}/auto_assign_myteams.yml"
        fi
    else
        log_info "外部ユーザー: auto-assign設定はスキップします"
    fi
    return 0
}

# 組織専用ワークフローの削除
#
# 組織外ユーザーの場合、Organization Secretsに依存するワークフローを削除します。
# これにより、ワークフロー実行時のエラーを防ぎます。
#
# 環境変数:
#   USER_TYPE - "organization_member" または "individual_user"
#
# 削除対象:
#   - .github/workflows/notify-ml-on-pr.yml (組織MLへのPR通知)
#
# 戻り値:
#   0 - 成功（削除完了または不要）
remove_org_specific_workflows() {
    if [ "$USER_TYPE" = "individual_user" ]; then
        log_info "組織外ユーザー: ML通知ワークフローを削除"
        rm -f .github/workflows/notify-ml-on-pr.yml 2>/dev/null || true
    fi
    return 0
}

# ================================
# 高レベルセットアップ関数
# ================================

#
# 標準セットアップフロー
#
# 共通的なリポジトリセットアップ処理を実行します。
# - 組織アクセス確認
# - リポジトリ存在確認
# - 作成確認プロンプト
# - リポジトリ作成
# - Git認証設定
# - 共通ファイル整理
#
# 前提条件（呼び出し前に設定が必要）:
#   ORGANIZATION - 組織名
#   REPO_NAME - リポジトリ名
#   TEMPLATE_REPOSITORY - テンプレートリポジトリパス
#   VISIBILITY - "private" または "public"
#
# Args:
#   $1: doc_type - ドキュメントタイプ（thesis, wr, latex, ise）
#
# 結果:
#   REPO_PATH - 作成されたリポジトリのパス（グローバル変数として設定）
#
# 戻り値:
#   0 - 成功
#   1 - 失敗
#
run_standard_setup() {
    local doc_type="$1"

    # ドキュメントタイプの表示名マッピング（略語は大文字）
    local display_name
    case "$doc_type" in
        ise)    display_name="ISE" ;;
        wr)     display_name="WR" ;;
        *)      display_name="${doc_type^}" ;;
    esac

    # 組織アクセス確認
    check_organization_access "$ORGANIZATION"

    # リポジトリパス決定
    REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

    # リポジトリの存在確認
    if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
        die "リポジトリ $REPO_PATH は既に存在します"
    fi

    # 作成確認
    confirm_creation "$REPO_PATH" || exit 0

    # リポジトリ作成
    echo ""
    echo "📁 リポジトリを作成中..."
    create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "$VISIBILITY" "true" || exit 1
    cd "$REPO_NAME" || exit 1

    # Git設定
    setup_git_auth || exit 1
    setup_git_user "setup-${doc_type}@smkwlab.github.io" "${display_name} Setup Tool"

    # 共通ファイル整理
    echo "テンプレートファイルを整理中..."
    rm -f CLAUDE.md 2>/dev/null || true
    rm -rf docs/ 2>/dev/null || true
    find . -name '*-aldc' -exec rm -rf {} + 2>/dev/null || true
}

#
# Registry Manager連携
#
# 組織ユーザーの場合、リポジトリをRegistry Managerに登録します。
# 以下の条件を全て満たす場合のみ登録を実行します:
# - INDIVIDUAL_MODE が false（または未設定）
# - STUDENT_ID が空でない
# - thesis-student-registry リポジトリにアクセス可能
#
# 前提条件:
#   INDIVIDUAL_MODE - 個人モードフラグ（true の場合は登録スキップ）
#   STUDENT_ID - 学籍番号（空の場合は登録スキップ）
#   ORGANIZATION - 組織名
#   REPO_NAME - リポジトリ名
#
# Args:
#   $1: doc_type - ドキュメントタイプ（thesis, wr, latex, ise, poster）
#
run_registry_integration() {
    local doc_type="$1"

    # 条件: 個人モードが無効 AND 学籍番号が存在 AND Registryリポジトリがアクセス可能
    if [ "$INDIVIDUAL_MODE" = false ] && [ -n "$STUDENT_ID" ] && \
       gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
        if ! create_repository_issue "$REPO_NAME" "$STUDENT_ID" "$doc_type" "$ORGANIZATION"; then
            log_warn "Registry Manager登録でエラーが発生しました。手動で登録が必要な場合があります。"
        fi
    fi
}

#
# 完了メッセージ表示
#
# 標準的な完了メッセージを表示します。
#
# 前提条件:
#   REPO_PATH - リポジトリパス
#
# Args:
#   $1: additional_message - 追加メッセージ（オプション、改行区切り）
#
print_completion_message() {
    local additional_message="$1"

    echo ""
    echo "=============================================="
    echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
    echo ""
    echo "リポジトリ: https://github.com/${REPO_PATH}"

    if [ -n "$additional_message" ]; then
        echo ""
        echo "$additional_message"
    fi

    echo ""
    echo "=============================================="
}
