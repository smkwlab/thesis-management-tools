#!/bin/bash
#
# Bulk Branch Protection Setup Script
# 
# 学生リストファイルから一括でブランチ保護設定を実行
# Usage: ./bulk-setup-protection.sh [student_list_file]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PENDING_FILE="${1:-$SCRIPT_DIR/../data/protection-status/pending-protection.txt}"
COMPLETED_FILE="$SCRIPT_DIR/../data/protection-status/completed-protection.txt"
FAILED_FILE="$SCRIPT_DIR/../data/protection-status/failed-protection.txt"
ACTIVE_REPOS_FILE="$SCRIPT_DIR/../data/repositories/active.txt"

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

# ブランチ保護設定を実行（リポジトリ名指定版）
setup_branch_protection_for_repo() {
    local repo_name="$1"
    local student_id="$2"
    local org_name="smkwlab"
    
    log "Setting up branch protection for $repo_name..."
    
    # リポジトリ存在確認
    if ! gh repo view "$org_name/$repo_name" >/dev/null 2>&1; then
        error "Repository not found: $org_name/$repo_name"
        return 1
    fi
    
    # mainブランチ保護設定
    local api_response
    local protection_json='{
        "required_status_checks": null,
        "enforce_admins": true,
        "required_pull_request_reviews": {
            "required_approving_review_count": 1,
            "dismiss_stale_reviews": true,
            "bypass_pull_request_allowances": {
                "users": [],
                "teams": [],
                "apps": ["github-actions"]
            }
        },
        "restrictions": null,
        "allow_force_pushes": false,
        "allow_deletions": false
    }'
    
    if api_response=$(echo "$protection_json" | gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/$org_name/$repo_name/branches/main/protection" \
        --input - \
        2>&1); then
        success "Main branch protection configured for $repo_name"
    else
        error "Failed to configure main branch protection for $repo_name: $api_response"
        return 1
    fi
    
    # review-branchブランチ保護設定
    if api_response=$(echo "$protection_json" | gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/$org_name/$repo_name/branches/review-branch/protection" \
        --input - \
        2>&1); then
        success "Review branch protection configured for $repo_name"
        return 0
    else
        warn "Failed to configure review branch protection (branch might not exist yet): $api_response"
        return 0  # 成功扱い（review-branchは初回コミット時に作成される）
    fi
}

# 関連Issueを自動クローズ
close_related_issue() {
    local repo_name="$1"
    
    log "Looking for related issue for $repo_name..."
    
    # ブランチ保護設定依頼Issueを検索
    local issue_number=$(gh issue list \
        --repo smkwlab/thesis-management-tools \
        --state open \
        --search "in:title ブランチ保護設定依頼 in:body $repo_name" \
        --json number \
        --jq '.[0].number' 2>/dev/null || echo "")
    
    if [ -n "$issue_number" ] && [ "$issue_number" != "null" ]; then
        log "Found related issue #$issue_number, closing..."
        if gh issue comment "$issue_number" \
            --repo smkwlab/thesis-management-tools \
            --body "✅ ブランチ保護設定が自動実行されました

リポジトリ: smkwlab/$repo_name
設定完了時刻: $(date '+%Y-%m-%d %H:%M:%S JST')

以下のブランチに保護設定を適用しました:
- main ブランチ
- review-branch ブランチ" >/dev/null 2>&1; then
            success "Added completion comment to issue #$issue_number"
        fi
        
        if gh issue close "$issue_number" --repo smkwlab/thesis-management-tools >/dev/null 2>&1; then
            success "Closed issue #$issue_number"
        else
            warn "Failed to close issue #$issue_number"
        fi
    else
        info "No related issue found for $repo_name"
    fi
}

# メイン処理
main() {
    log "Starting bulk branch protection setup..."
    
    if [ ! -f "$PENDING_FILE" ]; then
        log "Pending file not found: $PENDING_FILE"
        log "No repositories to process. Exiting normally."
        exit 0
    fi
    
    # GitHub CLI認証確認
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI is not authenticated. Run 'gh auth login' first."
        exit 1
    fi
    
    local total_count=0
    local success_count=0
    local failed_students=""
    
    # ファイルが空かチェック
    if [ ! -s "$PENDING_FILE" ]; then
        log "Pending file is empty. No repositories to process."
        exit 0
    fi
    
    # 処理対象のリポジトリをカウント
    while read -r repo_name; do
        if [ -n "$repo_name" ] && [[ "$repo_name" =~ ^k[0-9]{2}[rg][sjk][0-9]+-[a-z]+$ ]]; then
            total_count=$((total_count + 1))
        fi
    done < "$PENDING_FILE"
    
    if [ "$total_count" -eq 0 ]; then
        warn "No repositories found in pending file"
        exit 0
    fi
    
    log "Processing $total_count repositories..."
    echo
    
    # 各リポジトリのブランチ保護設定
    while read -r repo_name; do
        if [ -n "$repo_name" ] && [[ "$repo_name" =~ ^k[0-9]{2}[rg][sjk][0-9]+-[a-z]+$ ]]; then
            local student_id=$(echo "$repo_name" | cut -d'-' -f1)
            if setup_branch_protection_for_repo "$repo_name" "$student_id"; then
                ((success_count++))
                # 完了リストに移動
                echo "$repo_name # Protected: $(date +%Y-%m-%d)" >> "$COMPLETED_FILE"
                # アクティブリポジトリリストに追加
                echo "$repo_name" >> "$ACTIVE_REPOS_FILE"
                # Issue自動クローズ
                close_related_issue "$repo_name"
            else
                failed_students+="$repo_name "
                # 失敗リストに追加
                echo "$repo_name # Failed: $(date +%Y-%m-%d)" >> "$FAILED_FILE"
            fi
        fi
    done < "$PENDING_FILE"
    
    # 成功分をpendingから削除
    if [ "$success_count" -gt 0 ]; then
        # 処理済みリポジトリをpendingから削除
        local temp_pending=$(mktemp)
        while read -r repo_name; do
            if [ -n "$repo_name" ]; then
                # 完了済みまたは失敗済みでない場合のみ残す
                if ! grep -q "^$repo_name" "$COMPLETED_FILE" 2>/dev/null && \
                   ! grep -q "^$repo_name" "$FAILED_FILE" 2>/dev/null; then
                    echo "$repo_name" >> "$temp_pending"
                fi
            fi
        done < "$PENDING_FILE"
        # pendingファイルを更新
        mv "$temp_pending" "$PENDING_FILE"
    fi
    
    # ファイルの重複除去とディレクトリ作成
    mkdir -p "$(dirname "$COMPLETED_FILE")" "$(dirname "$FAILED_FILE")" "$(dirname "$ACTIVE_REPOS_FILE")"
    
    # 重複除去
    [ -f "$COMPLETED_FILE" ] && sort -u "$COMPLETED_FILE" -o "$COMPLETED_FILE"
    [ -f "$FAILED_FILE" ] && sort -u "$FAILED_FILE" -o "$FAILED_FILE"
    [ -f "$ACTIVE_REPOS_FILE" ] && sort -u "$ACTIVE_REPOS_FILE" -o "$ACTIVE_REPOS_FILE"
    
    # 結果報告
    echo
    log "Bulk setup completed"
    echo "📊 Results:"
    echo "   Total: $total_count"
    echo "   Success: $success_count"
    echo "   Failed: $((total_count - success_count))"
    
    if [ -n "$failed_students" ]; then
        echo
        warn "Failed students: $failed_students"
        warn "Please check these repositories manually"
    fi
    
    if [ "$success_count" -gt 0 ]; then
        echo
        success "Branch protection setup completed for $success_count repositories"
        success "Updated files:"
        success "  - $COMPLETED_FILE (added $success_count entries)"
        success "  - $PENDING_FILE (removed $success_count entries)"
    fi
}

# ヘルプ表示
show_help() {
    cat <<EOF
Bulk Branch Protection Setup Script

Usage: $0 [student_list_file]

Arguments:
  student_list_file    Path to student list file (default: ../student-repos/pending-protection.txt)

Description:
  Reads student IDs from the specified file and sets up branch protection
  for their repositories. Successfully processed students are moved from
  pending-protection.txt to completed-protection.txt.

Examples:
  $0                                    # Use default pending file
  $0 student-repos/pending-protection.txt  # Specify file explicitly

Requirements:
  - GitHub CLI (gh) must be authenticated
  - Admin access to target repositories
EOF
}

# コマンドライン処理
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac