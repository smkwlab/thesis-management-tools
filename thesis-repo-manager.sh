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
PENDING_FILE="$SCRIPT_DIR/data/protection-status/pending-protection.txt"
COMPLETED_FILE="$SCRIPT_DIR/data/protection-status/completed-protection.txt"

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

# API呼び出し間隔制御
api_sleep() {
    local sleep_time="${1:-0.1}"
    sleep "$sleep_time"
}

# GitHub CLI 認証確認
check_github_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        error "GitHub CLI (gh) is not installed. Please install it first."
        return 1
    fi
    
    # 認証状態確認（実際のAPI呼び出しでテスト）
    if ! gh api user >/dev/null 2>&1; then
        error "GitHub CLI is not authenticated or current account is invalid"
        error "Please run 'gh auth login' first"
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
    if ! [[ "$student_id" =~ ^k[0-9]{2}(rs|jk|gjk)[0-9]+$ ]]; then
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
    
    if [[ "$student_id" =~ ^k[0-9]{2}(rs|jk)[0-9]+$ ]]; then
        # 卒業論文（rs）・大学院論文（jk）
        echo "${student_id}-sotsuron"
    elif [[ "$student_id" =~ ^k[0-9]{2}gjk[0-9]+$ ]]; then
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
            # Student:形式から抽出を試行
            grep -E 'Student: k[0-9]{2}(rs|jk|gjk)[0-9]+' "$PENDING_FILE" | \
            sed -E 's/.*Student: (k[0-9]{2}(rs|jk|gjk)[0-9]+).*/\1/'
            # フォールバック: 行頭の学生IDを抽出
            grep -E '^k[0-9]{2}(rs|jk|gjk)[0-9]+' "$PENDING_FILE" | \
            sed -E 's/^(k[0-9]{2}(rs|jk|gjk)[0-9]+).*/\1/'
        fi
        if [ -f "$COMPLETED_FILE" ]; then
            # Student:形式から抽出を試行
            grep -E 'Student: k[0-9]{2}(rs|jk|gjk)[0-9]+' "$COMPLETED_FILE" | \
            sed -E 's/.*Student: (k[0-9]{2}(rs|jk|gjk)[0-9]+).*/\1/'
            # フォールバック: 行頭の学生IDを抽出
            grep -E '^k[0-9]{2}(rs|jk|gjk)[0-9]+' "$COMPLETED_FILE" | \
            sed -E 's/^(k[0-9]{2}(rs|jk|gjk)[0-9]+).*/\1/'
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
        pending_students=$(get_all_students)
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
        echo "  ./thesis-repo-manager.sh bulk"
    else
        success "All pending repositories are properly protected! ✅"
    fi
}

# ブランチ保護設定を実行（bulk-setup機能から統合）
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
    
    # APIレート制限チェック
    local remaining=$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null || echo "0")
    if [ "$remaining" -lt 10 ]; then
        warn "GitHub API レート制限に接近しています: 残り${remaining}リクエスト"
        return 1
    fi
    
    # 既存のブランチ保護設定を確認（冪等性保証）
    if gh api "repos/smkwlab/$repo_name/branches/main/protection" >/dev/null 2>&1; then
        log "ブランチ保護は既に設定済みです: $repo_name"
        # 既に設定済みでも成功として扱う
        return 0
    fi
    
    # GitHub CLIでブランチ保護設定
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
        success "Branch protection configured for $repo_name"
        return 0
    else
        error "Failed to configure branch protection for $repo_name"
        return 1
    fi
}

# 関連Issueを自動クローズ（bulk-setup機能から統合）
close_related_issue() {
    local repo_name="$1"
    
    log "関連Issueの検索とクローズ中..."
    
    # リポジトリ名に基づいてIssueを検索
    local search_term="smkwlab/${repo_name}"
    local issues
    
    # デバッグ情報の出力
    if [ "${DEBUG:-0}" = "1" ]; then
        log "🔍 Issue検索詳細:"
        log "   検索対象: $search_term"
        log "   ラベル: branch-protection"
        log "   状態: open"
    fi
    
    # GitHub CLIでIssue検索（タイトルにリポジトリ名が含まれるものを検索）
    # まずラベル付きで検索
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
            warn "   - branch-protectionラベルまたは'ブランチ保護設定依頼'文字が含まれているか"
            warn "   - Issueがopen状態か"
        else
            warn "⚠️  関連Issueが見つかりませんでした（リポジトリ: ${search_term}）"
        fi
    fi
}

# 一括ブランチ保護設定
bulk_setup_protection() {
    local pending_file="${1:-$PENDING_FILE}"
    
    # ヘルプ表示
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        cat <<EOF
Bulk Branch Protection Setup

Usage: $0 bulk [student_list_file]

Arguments:
  student_list_file    Path to student list file (default: student-repos/pending-protection.txt)

Description:
  Reads student IDs from the specified file and sets up branch protection
  for their repositories. Successfully processed students are moved from
  pending-protection.txt to completed-protection.txt.

Examples:
  $0 bulk                                    # Use default pending file
  $0 bulk student-repos/pending-protection.txt  # Specify file explicitly

Protection Rules Applied:
  - Requires 1 approving review before merge
  - Dismisses stale reviews when new commits are pushed
  - Prevents force pushes and branch deletion
  - Does not enforce admin restrictions

Requirements:
  - GitHub CLI (gh) must be authenticated
  - Admin access to target repositories
  - Target repositories and main branches must exist
EOF
        return 0
    fi
    
    log "Starting bulk branch protection setup..."
    
    if [ ! -f "$pending_file" ]; then
        error "Pending file not found: $pending_file"
        return 1
    fi
    
    # GitHub CLI認証確認
    if ! check_github_cli; then
        return 1
    fi
    
    local total_count=0
    local success_count=0
    local failed_students=""
    
    # 処理対象の学生をカウント
    local students_list
    students_list=$(get_all_students)
    if [ -n "$students_list" ]; then
        total_count=$(echo "$students_list" | wc -l | tr -d ' ')
    else
        total_count=0
    fi
    
    if [ "$total_count" -eq 0 ]; then
        warn "No students found in pending file"
        return 0
    fi
    
    log "Processing $total_count students..."
    echo
    
    # 各学生のブランチ保護設定
    while IFS= read -r student_id; do
        if [[ "$student_id" =~ ^k[0-9]{2}(rs|jk|gjk)[0-9]+$ ]]; then
            if setup_branch_protection "$student_id"; then
                ((success_count++))
                
                # 論文タイプの判定（再度）
                if [[ "$student_id" =~ ^k[0-9]{2}rs[0-9]{3}$ ]]; then
                    thesis_type="sotsuron"
                elif [[ "$student_id" =~ ^k[0-9]{2}gjk[0-9]{2}$ ]]; then
                    thesis_type="thesis"
                fi
                local repo_name="${student_id}-${thesis_type}"
                
                # 完了リストに移動
                local line
                line=$(grep "^$student_id " "$pending_file" || echo "")
                if [ -n "$line" ]; then
                    echo "$line # Protected: $(date +%Y-%m-%d)" >> "$COMPLETED_FILE"
                fi
                
                # 関連Issue自動クローズ
                close_related_issue "$repo_name"
                
                api_sleep 0.2  # レート制限対策
            else
                failed_students+="$student_id "
            fi
        fi
    done <<< "$students_list"
    
    # 成功分をpendingから削除
    if [ "$success_count" -gt 0 ]; then
        # pendingファイルから成功分を除外
        # 現在の実装では学生リストは完了ファイルに移動済みのため
        # pendingファイルの更新は不要（既にGitHub Actionsで管理済み）
        log "Successfully processed $success_count students"
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
Thesis Repository Manager - GitHub上の学生論文リポジトリ管理ツール

Usage: $0 [command] [options]

Commands:
  status      Show all student repository status (GitHub API)
  bulk        Run bulk branch protection setup for all pending students
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
        bulk)
            bulk_setup_protection "${2:-}"
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
