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

# 関連Issueを自動クローズ
close_related_issue() {
    local repo_name="$1"
    
    log "関連Issueの検索とクローズ中..."
    
    # リポジトリ名に基づいてIssueを検索（絵文字を避けてより安全に）
    local search_term="smkwlab/${repo_name}"
    local issues
    
    # GitHub CLIでIssue検索（タイトルにリポジトリ名が含まれるものを検索）
    issues=$(gh issue list --repo smkwlab/thesis-management-tools \
        --state open \
        --label "branch-protection" \
        --json number,title \
        --jq ".[] | select(.title | contains(\"$search_term\")) | .number" 2>/dev/null || echo "")
    
    if [ -n "$issues" ]; then
        for issue_number in $issues; do
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
            fi
        done
    else
        warn "⚠️  関連Issueが見つかりませんでした（リポジトリ: $search_term）"
        warn "   手動でIssueをクローズしてください"
    fi
}

# 処理前バックアップ（重要ファイルの保護）
create_backup() {
    local operation="$1"
    local timestamp=$(date +'%Y%m%d_%H%M%S')
    local backup_dir="$SCRIPT_DIR/../backups/${operation}_${timestamp}"
    
    log "処理前バックアップを作成中..."
    
    mkdir -p "$backup_dir"
    
    # 重要ファイルのバックアップ
    if [ -f "$SCRIPT_DIR/../student-repos/pending-protection.txt" ]; then
        cp "$SCRIPT_DIR/../student-repos/pending-protection.txt" "$backup_dir/"
    fi
    if [ -f "$SCRIPT_DIR/../student-repos/completed-protection.txt" ]; then
        cp "$SCRIPT_DIR/../student-repos/completed-protection.txt" "$backup_dir/"
    fi
    
    # Git状態のバックアップ
    cd "$SCRIPT_DIR/.." 2>/dev/null && {
        git log --oneline -5 > "$backup_dir/git_log.txt" 2>/dev/null || true
        git status --porcelain > "$backup_dir/git_status.txt" 2>/dev/null || true
    }
    
    success "✅ バックアップ作成完了: $backup_dir"
    echo "$backup_dir"
}

# ブランチ保護設定
setup_protection() {
    local student_id="$1"
    
    # 処理前バックアップ
    local backup_dir
    backup_dir=$(create_backup "branch_protection_${student_id}")
    
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
    
    # リポジトリ存在確認
    if ! gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
        error "Repository not found: smkwlab/$repo_name"
        error "Please ensure the repository exists before setting up protection"
        return 1
    fi
    
    # mainブランチ存在確認
    if ! gh api "repos/smkwlab/$repo_name/branches/main" >/dev/null 2>&1; then
        error "Main branch not found in repository: smkwlab/$repo_name"
        return 1
    fi
    
    # ブランチ保護設定
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
    
    if echo "$protection_config" | gh api "repos/smkwlab/$repo_name/branches/main/protection" \
        --method PUT \
        --input - >/dev/null 2>&1; then
        success "✅ Branch protection configured successfully"
        success "   Repository: https://github.com/smkwlab/$repo_name"
        success "   Protection rules:"
        success "     - Requires 1 approving review before merge"
        success "     - Dismisses stale reviews when new commits are pushed"
        success "     - Prevents force pushes and branch deletion"
        
        # 対応するIssueを自動クローズ
        close_related_issue "$repo_name"
        
        return 0
    else
        error "❌ Failed to configure branch protection"
        error "   This may be due to insufficient permissions or API limits"
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
    
    # GitHub CLI認証確認
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI is not authenticated"
        error "Please run 'gh auth login' first"
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