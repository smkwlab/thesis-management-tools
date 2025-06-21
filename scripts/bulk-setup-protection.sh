#!/bin/bash
#
# Bulk Branch Protection Setup Script
# 
# 学生リストファイルから一括でブランチ保護設定を実行
# Usage: ./bulk-setup-protection.sh [student_list_file]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PENDING_FILE="${1:-$SCRIPT_DIR/../student-repos/pending-protection.txt}"
COMPLETED_FILE="$SCRIPT_DIR/../student-repos/completed-protection.txt"

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

# ブランチ保護設定を実行
setup_branch_protection() {
    local student_id="$1"
    
    # 論文タイプの判定
    if [[ "$student_id" =~ ^k[0-9]{2}rs[0-9]{3}$ ]]; then
        thesis_type="sotsuron"
    elif [[ "$student_id" =~ ^k[0-9]{2}gjk[0-9]{2}$ ]]; then
        thesis_type="thesis"
    else
        error "Invalid student ID format: $student_id"
        return 1
    fi
    
    local repo_name="${student_id}-${thesis_type}"
    
    log "Setting up branch protection: smkwlab/$repo_name"
    
    # GitHub CLIでブランチ保護設定
    if gh api "repos/smkwlab/$repo_name/branches/main/protection" \
        --method PUT \
        --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
        --field enforce_admins=false \
        --field allow_force_pushes=false \
        --field allow_deletions=false \
        >/dev/null 2>&1; then
        success "Branch protection configured for $repo_name"
        return 0
    else
        error "Failed to configure branch protection for $repo_name"
        return 1
    fi
}

# メイン処理
main() {
    log "Starting bulk branch protection setup..."
    
    if [ ! -f "$PENDING_FILE" ]; then
        error "Pending file not found: $PENDING_FILE"
        exit 1
    fi
    
    # GitHub CLI認証確認
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI is not authenticated. Run 'gh auth login' first."
        exit 1
    fi
    
    local total_count=0
    local success_count=0
    local failed_students=""
    
    # 処理対象の学生をカウント
    while IFS=' ' read -r student_id _; do
        if [[ "$student_id" =~ ^k[0-9]{2}[a-z]{2,3}[0-9]+$ ]]; then
            ((total_count++))
        fi
    done < "$PENDING_FILE"
    
    if [ "$total_count" -eq 0 ]; then
        warn "No students found in pending file"
        exit 0
    fi
    
    log "Processing $total_count students..."
    echo
    
    # 各学生のブランチ保護設定
    while IFS=' ' read -r student_id _; do
        if [[ "$student_id" =~ ^k[0-9]{2}[a-z]{2,3}[0-9]+$ ]]; then
            if setup_branch_protection "$student_id"; then
                ((success_count++))
                # 完了リストに移動
                local line
                line=$(grep "^$student_id " "$PENDING_FILE" || echo "")
                if [ -n "$line" ]; then
                    echo "$line # Protected: $(date +%Y-%m-%d)" >> "$COMPLETED_FILE"
                fi
            else
                failed_students+="$student_id "
            fi
        fi
    done < "$PENDING_FILE"
    
    # 成功分をpendingから削除
    if [ "$success_count" -gt 0 ]; then
        # 成功した学生IDを一時ファイルに保存
        local temp_success=$(mktemp)
        while IFS=' ' read -r student_id _; do
            if [[ "$student_id" =~ ^k[0-9]{2}[a-z]{2,3}[0-9]+$ ]]; then
                if grep -q "^$student_id.*Protected:" "$COMPLETED_FILE"; then
                    echo "$student_id"
                fi
            fi
        done < "$PENDING_FILE" > "$temp_success"
        
        # pendingファイルから成功分を除外
        local temp_pending=$(mktemp)
        while IFS=' ' read -r student_id rest; do
            if [[ "$student_id" =~ ^k[0-9]{2}[a-z]{2,3}[0-9]+$ ]]; then
                if ! grep -q "^$student_id$" "$temp_success"; then
                    echo "$student_id $rest"
                fi
            else
                # コメント行はそのまま保持
                echo "$student_id $rest"
            fi
        done < "$PENDING_FILE" > "$temp_pending"
        
        mv "$temp_pending" "$PENDING_FILE"
        rm -f "$temp_success"
    fi
    
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