#!/bin/bash
#
# Thesis Repository Manager - GitHub上の学生論文リポジトリ管理ツール
#
# ecosystem-manager.sh とは独立して動作
# GitHub APIを使用してリモートリポジトリの状態を調査
#
# Usage: ./thesis-repo-manager.sh [command] [options]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PENDING_FILE="$SCRIPT_DIR/student-repos/pending-protection.txt"
COMPLETED_FILE="$SCRIPT_DIR/student-repos/completed-protection.txt"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ヘルパー関数
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

# GitHub CLI 認証確認
check_github_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        error "GitHub CLI (gh) is not installed. Please install it first."
        return 1
    fi
    
    # 認証状態確認
    local auth_output
    auth_output=$(gh auth status 2>&1)
    if ! echo "$auth_output" | grep -q "Active account: true"; then
        error "GitHub CLI is not authenticated. Run 'gh auth login' first."
        return 1
    fi
    
    return 0
}

# GitHub API レート制限チェック（大量処理前の確認）
check_rate_limit() {
    local required_calls="${1:-100}"  # デフォルト100リクエスト
    
    log "GitHub API レート制限を確認中..."
    
    # GitHub APIのレート制限情報を取得
    local rate_info
    rate_info=$(gh api rate_limit 2>/dev/null) || {
        warn "レート制限情報の取得に失敗しました"
        return 0  # 情報取得失敗時は処理を続行
    }
    
    local remaining used reset_time
    remaining=$(echo "$rate_info" | jq -r '.rate.remaining // 0')
    used=$(echo "$rate_info" | jq -r '.rate.used // 0')
    reset_time=$(echo "$rate_info" | jq -r '.rate.reset // 0')
    
    if [ "$remaining" -lt "$required_calls" ]; then
        local reset_date
        if command -v gdate >/dev/null 2>&1; then
            # macOS with GNU coreutils
            reset_date=$(gdate -d "@$reset_time" +'%Y-%m-%d %H:%M:%S')
        else
            # Linux or fallback
            reset_date=$(date -d "@$reset_time" +'%Y-%m-%d %H:%M:%S' 2>/dev/null || date +'%Y-%m-%d %H:%M:%S')
        fi
        
        warn "GitHub API レート制限に近づいています"
        warn "  残り: $remaining/$((remaining + used)) リクエスト"
        warn "  必要: $required_calls リクエスト"
        warn "  リセット: $reset_date"
        warn ""
        warn "大量処理を実行する場合は、リセット後に再実行することを推奨します"
        
        # 対話的確認（非対話環境では警告のみ）
        if [ -t 0 ]; then
            echo -n "処理を続行しますか？ (y/N): "
            read -r response
            case "$response" in
                [yY]|[yY][eE][sS])
                    warn "処理を続行します（レート制限に注意してください）"
                    ;;
                *)
                    error "処理を中止しました"
                    return 1
                    ;;
            esac
        fi
    else
        success "✅ GitHub API レート制限OK（残り: $remaining リクエスト）"
    fi
    
    return 0
}

# API呼び出し間のスリープ（レート制限対策）
api_sleep() {
    local sleep_time="${1:-0.1}"  # デフォルト100ms
    sleep "$sleep_time"
}

# 学生ID検証
validate_student_id() {
    local student_id="$1"
    if ! [[ "$student_id" =~ ^k[0-9]{2}(rs[0-9]{3}|gjk[0-9]{2})$ ]]; then
        warn "Invalid student ID format: $student_id"
        return 1
    fi
    return 0
}

# 学生IDからリポジトリ名を決定
determine_repo_name() {
    local student_id="$1"
    
    # 学生ID検証
    if ! validate_student_id "$student_id"; then
        echo ""
        return 1
    fi
    
    if [[ "$student_id" =~ ^k[0-9]{2}rs[0-9]{3}$ ]]; then
        # 卒業論文
        echo "${student_id}-sotsuron"
    elif [[ "$student_id" =~ ^k[0-9]{2}gjk[0-9]{2}$ ]]; then
        # 修士論文
        echo "${student_id}-thesis"
    else
        echo ""
    fi
}

# GitHub API経由でリポジトリ情報取得
get_repo_info() {
    local student_id="$1"
    local repo_name
    repo_name=$(determine_repo_name "$student_id")
    
    if [ -z "$repo_name" ]; then
        echo "{}"
        return 1
    fi
    
    gh api "repos/smkwlab/$repo_name" 2>/dev/null || echo "{}"
}

# ブランチ保護状態を確認
check_branch_protection() {
    local repo_name="$1"
    
    if gh api "repos/smkwlab/$repo_name/branches/main/protection" >/dev/null 2>&1; then
        echo "protected"
    else
        echo "unprotected"
    fi
}

# 全学生リストの取得（pending + completed）
get_all_students() {
    {
        if [ -f "$PENDING_FILE" ]; then
            grep -E '^k[0-9]{2}[a-z]{2,3}[0-9]+' "$PENDING_FILE" | cut -d' ' -f1
        fi
        if [ -f "$COMPLETED_FILE" ]; then
            grep -E '^k[0-9]{2}[a-z]{2,3}[0-9]+' "$COMPLETED_FILE" | cut -d' ' -f1
        fi
    } | sort -u
}

# 学生リポジトリ一覧表示
show_status() {
    log "Fetching student repository status from GitHub..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    # 学生数に基づいてレート制限チェック
    local students
    students=$(get_all_students)
    local student_count=0
    if [ -n "$students" ]; then
        student_count=$(echo "$students" | wc -l | tr -d ' ')
    fi
    
    # 学生1人あたり約3-4 API呼び出し（リポジトリ確認、情報取得、保護状態確認）
    local required_calls=$((student_count * 4))
    if [ "$required_calls" -gt 50 ]; then
        if ! check_rate_limit "$required_calls"; then
            return 1
        fi
    fi
    
    echo
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         Student Thesis Repository Status                      ║"
    echo "╠════════════╤════════════════════════╤═══════════╤════════════╤══════════════╣"
    echo "║ Student ID │ Repository             │ Status    │ Protection │ Last Update  ║"
    echo "╠════════════╪════════════════════════╪═══════════╪════════════╪══════════════╣"
    
    local students
    students=$(get_all_students)
    
    if [ -z "$students" ]; then
        echo "║            │                        │           │            │              ║"
        echo "║            │     No students found │           │            │              ║"
        echo "║            │                        │           │            │              ║"
    else
        while IFS= read -r student_id; do
            local repo_name
            repo_name=$(determine_repo_name "$student_id")
            
            if [ -z "$repo_name" ]; then
                continue
            fi
            
            # GitHub APIでリポジトリ情報取得
            local repo_exists=false
            local repo_info=""
            if gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
                repo_exists=true
                api_sleep 0.1  # レート制限対策
                repo_info=$(gh api "repos/smkwlab/$repo_name" 2>/dev/null)
                api_sleep 0.1  # レート制限対策
            fi
            
            if [ "$repo_exists" = true ] && [ -n "$repo_info" ]; then
                local status="Active"
                local last_update
                last_update=$(echo "$repo_info" | jq -r 'if .pushed_at then .pushed_at[:10] else "N/A" end' 2>/dev/null || echo "N/A")
                # null や空文字を N/A に変換
                [ "$last_update" = "null" ] || [ -z "$last_update" ] && last_update="N/A"
                
                local protection_status
                api_sleep 0.1  # レート制限対策
                protection_status=$(check_branch_protection "$repo_name")
                
                if [ "$protection_status" = "protected" ]; then
                    protection_icon="✅"
                else
                    protection_icon="❌"
                fi
            else
                status="Not Found"
                last_update="N/A"
                protection_icon="N/A"
            fi
            
            printf "║ %-10s │ %-22s │ %-9s │ %-10s │ %-12s ║\n" \
                "$student_id" "$repo_name" "$status" "$protection_icon" "$last_update"
        done <<< "$students"
    fi
    
    echo "╚════════════╧════════════════════════╧═══════════╧════════════╧══════════════╝"
    echo
    
    # 統計情報
    local total_students
    if [ -n "$students" ]; then
        total_students=$(echo "$students" | wc -l | tr -d ' ')
    else
        total_students=0
    fi
    
    local protected_count=0
    local unprotected_count=0
    
    if [ "$total_students" -gt 0 ]; then
        while IFS= read -r student_id; do
            local repo_name
            repo_name=$(determine_repo_name "$student_id")
            if [ -n "$repo_name" ]; then
                local protection
                protection=$(check_branch_protection "$repo_name")
                if [ "$protection" = "protected" ]; then
                    ((protected_count++))
                else
                    ((unprotected_count++))
                fi
            fi
        done <<< "$students"
    fi
    
    echo "📊 Summary: Total: $total_students, Protected: $protected_count, Unprotected: $unprotected_count"
}

# PR/Issue統計表示
show_pr_stats() {
    log "Collecting PR/Issue statistics from GitHub..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    echo
    echo "📊 Pull Request and Issue Statistics"
    echo "===================================="
    echo
    
    local students
    students=$(get_all_students)
    
    if [ -z "$students" ]; then
        echo "No students found in repository lists."
        return
    fi
    
    while IFS= read -r student_id; do
        local repo_name
        repo_name=$(determine_repo_name "$student_id")
        
        if [ -n "$repo_name" ] && gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
            local open_prs draft_prs open_issues
            open_prs=$(gh pr list --repo "smkwlab/$repo_name" --state open --json number --jq 'length' 2>/dev/null || echo "0")
            draft_prs=$(gh pr list --repo "smkwlab/$repo_name" --state open --draft --json number --jq 'length' 2>/dev/null || echo "0")
            open_issues=$(gh issue list --repo "smkwlab/$repo_name" --state open --json number --jq 'length' 2>/dev/null || echo "0")
            
            echo "[$student_id] $repo_name"
            echo "  Open PRs: $open_prs (Draft: $draft_prs)"
            echo "  Open Issues: $open_issues"
            echo
        fi
    done <<< "$students"
}

# 最近のコミット活動を表示
show_activity() {
    log "Fetching recent commit activity..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    echo
    echo "📈 Recent Commit Activity (Last 7 days)"
    echo "======================================"
    echo
    
    local students
    students=$(get_all_students)
    
    if [ -z "$students" ]; then
        echo "No students found in repository lists."
        return
    fi
    
    # 7日前の日付を取得（macOS/Linux対応）
    local since_date
    if date -u -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
        # Linux
        since_date=$(date -u -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ')
    else
        # macOS
        since_date=$(date -u -v-7d '+%Y-%m-%dT%H:%M:%SZ')
    fi
    
    local any_activity=false
    
    while IFS= read -r student_id; do
        local repo_name
        repo_name=$(determine_repo_name "$student_id")
        
        if [ -n "$repo_name" ] && gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
            local commits
            commits=$(gh api "repos/smkwlab/$repo_name/commits?since=$since_date" \
                      --jq 'length' 2>/dev/null || echo "0")
            
            if [ "$commits" -gt 0 ]; then
                any_activity=true
                echo "[$student_id] $repo_name: $commits commits"
                
                # 最新3件のコミットメッセージ
                gh api "repos/smkwlab/$repo_name/commits?since=$since_date" \
                    --jq '.[:3] | .[] | "  - \(.commit.message | split("\n")[0])"' 2>/dev/null || echo "  - (Unable to fetch commit messages)"
                echo
            fi
        fi
    done <<< "$students"
    
    if [ "$any_activity" = false ]; then
        echo "No recent activity found in student repositories."
    fi
}

# ブランチ保護の一括チェック
check_protection() {
    log "Checking branch protection status..."
    
    if ! check_github_cli; then
        return 1
    fi
    
    echo
    
    local unprotected_count=0
    local unprotected_repos=""
    local pending_students
    
    if [ -f "$PENDING_FILE" ]; then
        pending_students=$(grep -E '^k[0-9]{2}[a-z]{2,3}[0-9]+' "$PENDING_FILE" | cut -d' ' -f1)
    fi
    
    if [ -n "$pending_students" ]; then
        while IFS= read -r student_id; do
            local repo_name
            repo_name=$(determine_repo_name "$student_id")
            
            if [ -n "$repo_name" ] && gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
                local protection
                protection=$(check_branch_protection "$repo_name")
                
                if [ "$protection" = "unprotected" ]; then
                    ((unprotected_count++))
                    unprotected_repos+="  - $student_id ($repo_name)\n"
                fi
            fi
        done <<< "$pending_students"
    fi
    
    if [ $unprotected_count -gt 0 ]; then
        warn "Found $unprotected_count unprotected repositories in pending list:"
        echo -e "$unprotected_repos"
        echo
        echo "To set up protection, run:"
        echo "  cd scripts"
        echo "  ./bulk-setup-protection.sh"
    else
        success "All pending repositories are properly protected! ✅"
    fi
}

# ヘルプ表示
show_help() {
    cat <<EOF
Thesis Repository Manager - GitHub上の学生論文リポジトリ管理ツール

Usage: $0 [command] [options]

Commands:
  status      Show all student repository status (GitHub API)
  pr-stats    Show PR and issue statistics  
  activity    Show recent commit activity (last 7 days)
  check       Check branch protection status for pending repositories
  help        Show this help message

Options:
  --verbose   Show detailed API responses (not yet implemented)

Examples:
  $0 status           # Show all repositories status
  $0 pr-stats         # Show PR/Issue statistics
  $0 activity         # Show recent activity
  $0 check            # Check protection status

Note: 
- This script requires GitHub CLI (gh) to be authenticated
- Student data is read from student-repos/pending-protection.txt and completed-protection.txt
- Repository names are automatically determined from student ID patterns:
  - k##rs### (undergraduate) → {student_id}-sotsuron
  - k##gjk## (graduate) → {student_id}-thesis

For more information, see: student-repos/README.md
EOF
}

# メイン処理
main() {
    case "${1:-help}" in
        status)
            show_status
            ;;
        pr-stats|stats)
            show_pr_stats
            ;;
        activity)
            show_activity
            ;;
        check)
            check_protection
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"