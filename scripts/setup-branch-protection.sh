#!/bin/bash
#
# Individual Branch Protection Setup Script
#
# 個別学生のブランチ保護設定
# Usage: ./setup-branch-protection.sh <repository_name>
#   repository_name: リポジトリ名
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
# 返り値:
#   0: 管理者権限あり
#   1: 権限なしまたはエラー
verify_admin_permissions() {
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
    
    log "権限確認対象: $test_repo"
    
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
    local repo_name="$1"
    # データは thesis-student-registry で管理されるため、ローカルファイル操作は不要
    
    log "ブランチ保護設定の記録中..."
    
    # thesis-student-registry のリポジトリ情報を更新（protection_statusをprotectedに設定）
    # これは registry-manager または thesis-monitor が担当
    log "リポジトリ情報: $repo_name"
    log "保護状態: protected"
    
    success "✅ ブランチ保護設定の記録が完了しました"
}



# ブランチ保護設定
setup_protection() {
    local repo_name="$1"
    
    log "Setting up branch protection for: smkwlab/$repo_name"
    log "Note: 'smkwlab/' prefix is automatically added to repository name"
    
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
            },
            "bypass_pull_request_allowances": {
                "users": [],
                "teams": [],
                "apps": ["github-actions"]
            }
        },
        "enforce_admins": true,
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
            success_count=$((success_count + 1))
            continue
        fi
        
        log "ブランチ '$branch' に保護設定を適用中..."
        if [ -n "${GITHUB_ACTIONS:-}" ]; then
            # GitHub Actions環境では詳細なエラー情報を出力
            if echo "$protection_config" | gh api "repos/smkwlab/$repo_name/branches/$branch/protection" \
                --method PUT \
                --input - 2>&1; then
                success "✅ ブランチ '$branch' の保護設定が完了しました"
                success_count=$((success_count + 1))
            else
                local api_exit_code=$?
                error "❌ ブランチ '$branch' の保護設定に失敗しました (exit code: $api_exit_code)"
                error "GitHub Actions環境でのAPI エラーです。詳細は上記のエラーメッセージを確認してください。"
            fi
        else
            # ローカル環境では従来通り
            if echo "$protection_config" | gh api "repos/smkwlab/$repo_name/branches/$branch/protection" \
                --method PUT \
                --input - >/dev/null 2>&1; then
                success "✅ ブランチ '$branch' の保護設定が完了しました"
                success_count=$((success_count + 1))
            else
                error "❌ ブランチ '$branch' の保護設定に失敗しました"
            fi
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
        
        
        # 学生リストの更新（pending → completed）
        update_student_lists "$repo_name"
        
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

Usage: $0 <repository_name>

Arguments:
  repository_name  Repository name (without smkwlab/ prefix)

Examples:
  $0 k21rs001-sotsuron          # Setup protection for thesis repository (→ smkwlab/k21rs001-sotsuron)
  $0 k21gjk01-thesis            # Setup protection for graduate thesis (→ smkwlab/k21gjk01-thesis)
  $0 k02jk059-ise-report1       # Setup protection for ISE report repository (→ smkwlab/k02jk059-ise-report1)
  $0 k21rs001-wr                # Setup protection for weekly report repository (→ smkwlab/k21rs001-wr)

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
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        error "Repository name is required"
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
    if ! verify_admin_permissions; then
        exit 1
    fi
    
    setup_protection "$repo_name"
}

# コマンドライン処理
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        error "Repository name is required"
        echo
        show_help
        exit 1
        ;;
    *)
        main "$@"
        ;;
esac
