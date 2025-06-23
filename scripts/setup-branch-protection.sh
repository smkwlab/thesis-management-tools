#!/bin/bash
#
# Individual Branch Protection Setup Script
#
# 個別学生のブランチ保護設定
# Usage: ./setup-branch-protection.sh <student_id>
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# APIレート制限チェック
check_rate_limit() {
    local remaining=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo "0")
    local reset_time=$(gh api rate_limit --jq '.resources.core.reset' 2>/dev/null || echo "0")
    
    if [ "$remaining" -lt 10 ]; then
        warn "GitHub API レート制限に接近しています: 残り${remaining}リクエスト"
        if [ "$reset_time" -gt 0 ]; then
            local reset_date=$(date -r "$reset_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "不明")
            warn "リセット時刻: $reset_date"
        fi
        return 1
    fi
    return 0
}

# アカウント権限チェック
check_admin_permissions() {
    log "GitHub CLI認証とアカウント権限を確認中..."
    
    # 現在のユーザー名を取得（GitHub Actionsとローカル両対応）
    local current_user
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        # GitHub Actions環境ではgithub-actions[bot]を使用
        current_user="github-actions[bot]"
        log "GitHub Actions環境で実行中"
    else
        # ローカル環境ではgh api userを使用
        current_user=$(gh api user --jq '.login' 2>/dev/null)
        if [ -z "$current_user" ]; then
            error "GitHub CLI認証に失敗しました"
            error "gh auth login を実行してください"
            return 1
        fi
    fi
    
    log "現在のアクティブアカウント: $current_user"
    
    # GitHub Actions環境では権限チェックをスキップ（GITHUB_TOKENで十分な権限が保証されている）
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        success "✅ GitHub Actions環境: GITHUB_TOKENで権限確認済み"
        return 0
    fi
    
    # ローカル環境でのみadmin権限をチェック
    local test_repo="smkwlab/thesis-management-tools"
    local has_admin
    
    has_admin=$(gh api "repos/$test_repo" --jq '.permissions.admin' 2>/dev/null)
    
    if [ "$has_admin" = "true" ]; then
        success "✅ 管理者権限を確認しました"
        return 0
    elif [ "$has_admin" = "false" ]; then
        error "❌ 現在のアカウント（$current_user）は管理者権限がありません"
        error "   このアカウントではブランチ保護設定に失敗します"
        echo
        error "解決方法："
        error "  管理者アカウントに切り替えてから再実行してください"
        error "  gh auth switch --user <admin-username>"
        echo
        return 1
    else
        error "権限確認に失敗しました（テストリポジトリ: $test_repo）"
        error "リポジトリへのアクセス権限がない可能性があります"
        return 1
    fi
}

# 学生リストの更新（pending → completed）
update_student_lists() {
    local student_id="$1"
    local repo_name="$2"
    local base_dir="$(dirname "$SCRIPT_DIR")"
    local pending_file="$base_dir/data/protection-status/pending-protection.txt"
    local completed_file="$base_dir/data/protection-status/completed-protection.txt"
    
    log "学生リストを更新中..."
    
    # pending-protection.txt から該当リポジトリを削除
    if [ -f "$pending_file" ]; then
        # 一時ファイルを作成
        local temp_file
        if ! temp_file=$(mktemp); then
            error "一時ファイルの作成に失敗しました"
            return 1
        fi
        
        # grep -v で該当行を除外（見つからない場合はエラーではない）
        if ! grep -v "^$repo_name$" "$pending_file" > "$temp_file"; then
            # grep -v が失敗した場合は元ファイルをコピー
            if ! cp "$pending_file" "$temp_file"; then
                error "ファイルのコピーに失敗しました: $pending_file"
                rm -f "$temp_file"
                return 1
            fi
        fi
        
        # 元のファイルを更新
        if ! mv "$temp_file" "$pending_file"; then
            error "ファイルの更新に失敗しました: $pending_file"
            rm -f "$temp_file"
            return 1
        fi
        log "pending-protection.txt から $repo_name を削除しました"
    fi
    
    # completed-protection.txt に追加（重複チェック付き）
    if [ -f "$completed_file" ]; then
        if ! grep -q "^$repo_name " "$completed_file"; then
            if ! echo "$repo_name # Completed: $(date +%Y-%m-%d) Student: $student_id" >> "$completed_file"; then
                error "completed-protection.txt への書き込みに失敗しました: $completed_file"
                return 1
            fi
            log "completed-protection.txt に $repo_name を追加しました"
        else
            log "$repo_name は既に completed-protection.txt に存在します"
        fi
    else
        # ファイルが存在しない場合は作成
        if ! echo "$repo_name # Completed: $(date +%Y-%m-%d) Student: $student_id" >> "$completed_file"; then
            error "completed-protection.txt の作成に失敗しました: $completed_file"
            return 1
        fi
        log "completed-protection.txt を作成し、$repo_name を追加しました"
    fi
    
    success "✅ 学生リストの更新が完了しました"
}

# 関連Issueを自動クローズ
close_related_issue() {
    local repo_name="$1"
    
    log "関連Issueの検索とクローズ中..."
    
    # リポジトリ名に基づいてIssueを検索（絵文字を避けてより安全に）
    local search_term="smkwlab/${repo_name}"
    local issues
    
    # デバッグ情報の出力
    if [ "${DEBUG:-0}" = "1" ]; then
        log "🔍 Issue検索詳細:"
        log "   検索対象: $search_term"
        log "   条件: タイトルに'ブランチ保護設定依頼'を含む"
        log "   状態: open"
    fi
    
    # GitHub CLIでIssue検索（タイトルにリポジトリ名が含まれるものを検索）
    # まずラベル付きで検索、見つからなければラベルなしで検索
    issues=$(gh issue list --repo smkwlab/thesis-management-tools \
        --state open \
        --label "branch-protection" \
        --json number,title \
        --jq ".[] | select(.title | contains(\"$search_term\")) | .number" 2>/dev/null || echo "")
    
    # ラベル付きで見つからない場合は、ラベルなしで検索
    if [ -z "$issues" ]; then
        issues=$(gh issue list --repo smkwlab/thesis-management-tools \
            --state open \
            --json number,title \
            --jq ".[] | select((.title | contains(\"$search_term\")) and (.title | contains(\"ブランチ保護設定依頼\"))) | .number" 2>/dev/null || echo "")
    fi
    
    if [ -n "$issues" ]; then
        for issue_number in $issues; do
            log "Issue #${issue_number} をクローズ中..."
            
            if gh issue close "$issue_number" --repo smkwlab/thesis-management-tools \
                --comment "✅ ブランチ保護設定が完了しました。

### 設定内容
- 1つ以上の承認レビューが必要
- 新しいコミット時に古いレビューを無効化  
- フォースプッシュとブランチ削除を禁止

### 確認
リポジトリ設定: https://github.com/smkwlab/${repo_name}/settings/branches

このIssueは自動的にクローズされました。" 2>/dev/null; then
                success "✅ 関連Issue #${issue_number} を自動クローズしました"
            else
                warn "⚠️  Issue #${issue_number} のクローズに失敗しました"
                if [ "${DEBUG:-0}" = "1" ]; then
                    warn "   権限不足またはAPI制限の可能性があります"
                fi
            fi
        done
    else
        if [ "${DEBUG:-0}" = "1" ]; then
            warn "⚠️  関連Issueが見つかりませんでした（検索: ${search_term}）"
            warn "   以下を確認してください："
            warn "   - Issueタイトルにリポジトリ名が含まれているか"
            warn "   - 'ブランチ保護設定依頼'の文字が含まれているか" 
            warn "   - Issueがopen状態か"
        else
            warn "⚠️  関連Issueが見つかりませんでした（リポジトリ: ${search_term}）"
            warn "   手動でIssueをクローズしてください"
        fi
    fi
}


# ブランチ保護設定
setup_protection() {
    local student_id="$1"
    
    # 学生ID検証
    if ! [[ "$student_id" =~ ^k[0-9]{2}(rs[0-9]{3}|gjk[0-9]{2})$ ]]; then
        error "Invalid student ID format: $student_id"
        error "Expected format: k##rs### (undergraduate) or k##gjk## (graduate)"
        return 1
    fi
    
    # 論文タイプの判定
    if [[ "$student_id" =~ ^k[0-9]{2}rs[0-9]{3}$ ]]; then
        thesis_type="sotsuron"
    elif [[ "$student_id" =~ ^k[0-9]{2}gjk[0-9]{2}$ ]]; then
        thesis_type="thesis"
    fi
    
    local repo_name="${student_id}-${thesis_type}"
    
    log "Setting up branch protection for: smkwlab/$repo_name"
    
    # APIレート制限チェック
    if ! check_rate_limit; then
        error "API レート制限のため処理を中断します"
        return 1
    fi
    
    # リポジトリ存在確認
    if ! gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
        error "Repository not found: smkwlab/$repo_name"
        error "Please ensure the repository exists before setting up protection"
        return 1
    fi
    
    # ブランチ存在確認
    local branches_to_protect=("main")
    
    if ! gh api "repos/smkwlab/$repo_name/branches/main" >/dev/null 2>&1; then
        error "Main branch not found in repository: smkwlab/$repo_name"
        return 1
    fi
    
    # review-branchの存在確認（存在する場合は保護対象に追加）
    if gh api "repos/smkwlab/$repo_name/branches/review-branch" >/dev/null 2>&1; then
        branches_to_protect+=("review-branch")
        log "review-branchが見つかりました。保護対象に追加します。"
    fi
    
    # 各ブランチへの保護設定
    local protection_config='{
        "required_status_checks": {
            "strict": false,
            "contexts": []
        },
        "required_pull_request_reviews": {
            "required_approving_review_count": 1,
            "dismiss_stale_reviews": true,
            "require_code_owner_reviews": false,
            "dismissal_restrictions": {
                "users": [],
                "teams": []
            }
        },
        "enforce_admins": false,
        "restrictions": null,
        "allow_force_pushes": false,
        "allow_deletions": false
    }'
    
    local success_count=0
    local total_branches=${#branches_to_protect[@]}
    
    for branch in "${branches_to_protect[@]}"; do
        log "ブランチ '$branch' の保護設定を確認中..."
        
        # 既存の保護設定確認（冪等性保証）
        if gh api "repos/smkwlab/$repo_name/branches/$branch/protection" >/dev/null 2>&1; then
            log "ブランチ '$branch' は既に保護設定済みです"
            ((success_count++))
            continue
        fi
        
        log "ブランチ '$branch' に保護設定を適用中..."
        if echo "$protection_config" | gh api "repos/smkwlab/$repo_name/branches/$branch/protection" \
            --method PUT \
            --input - >/dev/null 2>&1; then
            success "✅ ブランチ '$branch' の保護設定が完了しました"
            ((success_count++))
        else
            error "❌ ブランチ '$branch' の保護設定に失敗しました"
        fi
    done
    
    if [ "$success_count" -eq "$total_branches" ]; then
        success "✅ すべてのブランチ保護設定が完了しました ($success_count/$total_branches)"
        success "   Repository: https://github.com/smkwlab/$repo_name"
        success "   Protected branches: ${branches_to_protect[*]}"
        success "   Protection rules:"
        success "     - Requires 1 approving review before merge"
        success "     - Dismisses stale reviews when new commits are pushed"
        success "     - Prevents force pushes and branch deletion"
        
        # 対応するIssueを自動クローズ
        close_related_issue "$repo_name"
        
        # 学生リストの更新（pending → completed）
        update_student_lists "$student_id" "$repo_name"
        
        return 0
    else
        error "❌ 一部のブランチ保護設定に失敗しました ($success_count/$total_branches)"
        error "   成功: $success_count, 失敗: $((total_branches - success_count))"
        return 1
    fi
}

# ヘルプ表示
show_help() {
    cat <<EOF
Individual Branch Protection Setup Script

Usage: $0 <student_id>

Arguments:
  student_id    Student ID (k##rs### for undergraduate, k##gjk## for graduate)

Examples:
  $0 k21rs001   # Setup protection for k21rs001-sotsuron
  $0 k21gjk01   # Setup protection for k21gjk01-thesis

Protection Rules Applied:
  - Requires 1 approving review before merge
  - Dismisses stale reviews when new commits are pushed
  - Prevents force pushes and branch deletion
  - Does not enforce admin restrictions

Requirements:
  - GitHub CLI (gh) must be authenticated
  - Admin access to target repository
  - Target repository and main branch must exist
EOF
}

# メイン処理
main() {
    local student_id="$1"
    
    if [ -z "$student_id" ]; then
        error "Student ID is required"
        echo
        show_help
        exit 1
    fi
    
    # GitHub CLI認証確認（GitHub Actionsとローカル両対応）
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI is not authenticated or current account is invalid"
        error "Please run 'gh auth login' first"
        exit 1
    fi
    
    # アカウント権限チェック
    if ! check_admin_permissions; then
        exit 1
    fi
    
    setup_protection "$student_id"
}

# コマンドライン処理
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        error "Student ID is required"
        echo
        show_help
        exit 1
        ;;
    *)
        main "$@"
        ;;
esac