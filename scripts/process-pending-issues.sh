#!/bin/bash
#
# 未処理Issue一括処理スクリプト
# Usage: ./process-pending-issues.sh [options]
#
# 蓄積された「リポジトリ登録依頼」Issueを効率的に処理します
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# デフォルト設定
DEFAULT_REPO="smkwlab/thesis-management-tools"
DEFAULT_REGISTRY_REPO="smkwlab/thesis-student-registry"
DEFAULT_LOG_DIR="$PROJECT_ROOT/logs"
DEFAULT_BACKUP_DIR="$PROJECT_ROOT/backups"

# 実行時設定
REPO="${REPO:-$DEFAULT_REPO}"
REGISTRY_REPO="${REGISTRY_REPO:-$DEFAULT_REGISTRY_REPO}"
LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"

# モード設定
INTERACTIVE_MODE=false
DRY_RUN_MODE=false
DEBUG_MODE=false
BATCH_CONFIRM_MODE=false

# フィルター設定
FILTER_TYPE=""
LIMIT_COUNT=""

# ログ設定
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/process-pending-issues-$TIMESTAMP.log"
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 統計変数
TOTAL_ISSUES=0
PROCESSED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
EXTRACTION_ERROR_COUNT=0
declare -a FAILED_ISSUES=()
declare -a EXTRACTION_ERROR_ISSUES=()

#
# ログ関数
#
log_raw() {
    echo "$1" | tee -a "$LOG_FILE"
}

log_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${BLUE}$msg${NC}" | tee -a "$LOG_FILE" >&2
}

log_warn() {
    local msg="[WARN] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}$msg${NC}" | tee -a "$LOG_FILE" >&2
}

log_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}$msg${NC}" | tee -a "$LOG_FILE" >&2
}

log_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}$msg${NC}" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        local msg="[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1"
        echo -e "${CYAN}$msg${NC}" | tee -a "$LOG_FILE" >&2
    fi
}

#
# ヘルプ表示
#
show_help() {
    cat <<EOF
未処理Issue一括処理スクリプト

Usage: $0 [options]

OPTIONS:
    -i, --interactive       インタラクティブモード
    -d, --dry-run          ドライランモード（変更なし）
    --debug                デバッグモード
    --batch-confirm        バッチ確認モード（インタラクティブ+一括確認）
    --type TYPE            処理対象タイプ指定 (wr|sotsuron|thesis)
    --limit NUM            最大処理数制限
    --repo REPO            対象リポジトリ (default: $DEFAULT_REPO)
    --registry-repo REPO   レジストリリポジトリ (default: $DEFAULT_REGISTRY_REPO)
    --log-dir DIR          ログディレクトリ (default: $DEFAULT_LOG_DIR)
    --backup-dir DIR       バックアップディレクトリ (default: $DEFAULT_BACKUP_DIR)
    -h, --help             このヘルプを表示

EXAMPLES:
    # 自動モード
    $0

    # インタラクティブモード
    $0 --interactive

    # 週報リポジトリのみ処理
    $0 --type wr

    # ドライラン
    $0 --dry-run

    # デバッグモード
    $0 --debug --dry-run
EOF
}

#
# オプション解析
#
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --batch-confirm)
                BATCH_CONFIRM_MODE=true
                INTERACTIVE_MODE=true
                shift
                ;;
            --type)
                FILTER_TYPE="$2"
                if [[ ! "$FILTER_TYPE" =~ ^(wr|sotsuron|thesis)$ ]]; then
                    log_error "無効なタイプ: $FILTER_TYPE (有効: wr, sotsuron, thesis)"
                    exit 1
                fi
                shift 2
                ;;
            --limit)
                LIMIT_COUNT="$2"
                if ! [[ "$LIMIT_COUNT" =~ ^[0-9]+$ ]]; then
                    log_error "無効な制限数: $LIMIT_COUNT"
                    exit 1
                fi
                shift 2
                ;;
            --repo)
                REPO="$2"
                shift 2
                ;;
            --registry-repo)
                REGISTRY_REPO="$2"
                shift 2
                ;;
            --log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

#
# 前提条件チェック
#
check_prerequisites() {
    log_info "前提条件をチェック中..."

    # 必要なコマンドの確認
    local required_commands=("gh" "jq" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "必要なコマンドが見つかりません: $cmd"
            return 1
        fi
        log_debug "✓ $cmd コマンド確認済み"
    done

    # GitHub CLI認証確認
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI認証が必要です: gh auth login"
        return 1
    fi
    log_debug "✓ GitHub CLI認証確認済み"

    # ディレクトリ作成
    for dir in "$LOG_DIR" "$BACKUP_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_debug "ディレクトリを作成: $dir"
        fi
    done

    # プロジェクトルートの確認
    if [ ! -f "$PROJECT_ROOT/data/protection-status/completed-protection.txt" ]; then
        log_error "プロジェクトルートが正しくありません: $PROJECT_ROOT"
        return 1
    fi

    log_success "前提条件チェック完了"
    return 0
}

#
# バックアップ作成
#
create_backup() {
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] バックアップ作成をスキップ"
        return 0
    fi

    log_info "データファイルをバックアップ中..."

    mkdir -p "$BACKUP_PATH"

    # thesis-management-tools のデータバックアップ
    local data_dir="$PROJECT_ROOT/data"
    if [ -d "$data_dir" ]; then
        cp -r "$data_dir" "$BACKUP_PATH/thesis-management-tools-data"
        log_debug "バックアップ作成: thesis-management-tools/data"
    fi

    log_success "バックアップ作成完了: $BACKUP_PATH"
    return 0
}

#
# thesis-student-registry の準備（GitHub API使用時は不要）
#
prepare_registry() {
    log_info "GitHub API経由でthesis-student-registryを更新します"
    
    # GitHub APIアクセステスト（読み取り＋書き込み権限確認）
    if ! gh api repos/smkwlab/thesis-student-registry >/dev/null 2>&1; then
        log_error "thesis-student-registryへのアクセスに失敗しました"
        log_error "GitHub CLI認証またはリポジトリ権限を確認してください"
        return 1
    fi
    
    # 書き込み権限の具体的確認（repositories.jsonファイルアクセステスト）
    if ! gh api repos/smkwlab/thesis-student-registry/contents/data/repositories.json >/dev/null 2>&1; then
        log_error "repositories.jsonへのアクセスに失敗しました"
        log_error "ファイルの読み取り権限を確認してください"
        return 1
    fi
    
    # 実際の書き込み権限確認（現在のユーザーの権限レベルをチェック）
    local user_permission
    if user_permission=$(gh api repos/smkwlab/thesis-student-registry --jq '.permissions.push' 2>/dev/null); then
        if [ "$user_permission" != "true" ]; then
            log_error "リポジトリへの書き込み権限がありません"
            log_error "管理者にpush権限の付与を依頼してください"
            return 1
        fi
    else
        log_warn "権限レベルの確認に失敗しましたが、処理を続行します"
    fi
    
    log_success "GitHub API経由での thesis-student-registry アクセス確認完了"
    return 0
}

#
# Issue取得（リトライ機能付き）
#
fetch_pending_issues() {
    log_info "未処理Issueを検索中..."
    log_debug "対象リポジトリ: $REPO"
    
    local issues_json
    local gh_error_output
    local retry_count=0
    local max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        log_debug "Issue取得試行 $((retry_count + 1))/$max_retries"
        
        # GitHub CLI でサポートされているフィールドのみを使用（author情報も含める）
        if gh_error_output=$(gh issue list \
            --repo "$REPO" \
            --state open \
            --json number,title,body,createdAt,url,author \
            --limit 100 2>&1); then
            issues_json="$gh_error_output"
            log_debug "GitHub CLI コマンド実行成功"
            break
        else
            retry_count=$((retry_count + 1))
            log_warn "Issue取得試行 $retry_count 失敗: $gh_error_output"
            
            if [ $retry_count -lt $max_retries ]; then
                local wait_time=$((retry_count * 2))
                log_info "${wait_time}秒待機後に再試行します..."
                sleep $wait_time
            else
                log_error "Issue取得に失敗しました (全${max_retries}回の試行):"
                log_error "最終エラー: $gh_error_output"
                log_error "考えられる原因:"
                log_error "  - GitHub APIレート制限"
                log_error "  - ネットワーク接続問題"
                log_error "  - GitHub CLI認証期限切れ"
                log_error "  - リポジトリアクセス権限不足"
                return 1
            fi
        fi
    done
    
    # タイトルでフィルター
    log_debug "タイトルフィルターを適用中..."
    local all_issues_count=$(echo "$issues_json" | jq length)
    log_debug "取得したIssue総数: $all_issues_count"
    
    issues_json=$(echo "$issues_json" | jq '[.[] | select(.title | test("リポジトリ登録依頼|ブランチ保護設定依頼"))]')
    local filtered_count=$(echo "$issues_json" | jq length)
    log_debug "フィルター後のIssue数: $filtered_count"
    
    # フィルター適用
    if [ -n "$FILTER_TYPE" ]; then
        log_debug "タイプフィルター適用: $FILTER_TYPE"
        case "$FILTER_TYPE" in
            wr)
                issues_json=$(echo "$issues_json" | jq '[.[] | select(.title | contains("-wr"))]')
                ;;
            sotsuron)
                issues_json=$(echo "$issues_json" | jq '[.[] | select(.title | contains("-sotsuron"))]')
                ;;
            thesis)
                issues_json=$(echo "$issues_json" | jq '[.[] | select(.title | contains("-thesis"))]')
                ;;
        esac
    fi
    
    # 制限数適用
    if [ -n "$LIMIT_COUNT" ]; then
        log_debug "制限数適用: $LIMIT_COUNT"
        issues_json=$(echo "$issues_json" | jq ".[0:$LIMIT_COUNT]")
        local final_count=$(echo "$issues_json" | jq length)
        log_debug "制限適用後のIssue数: $final_count"
    fi
    
    echo "$issues_json"
    return 0
}

#
# Issue情報抽出
#
extract_issue_info() {
    local issue_json="$1"
    
    # グローバル変数に設定（関数間でのデータ共有用）
    CURRENT_ISSUE_NUMBER=$(echo "$issue_json" | jq -r '.number')
    CURRENT_ISSUE_TITLE=$(echo "$issue_json" | jq -r '.title')
    CURRENT_ISSUE_BODY=$(echo "$issue_json" | jq -r '.body')
    CURRENT_ISSUE_URL=$(echo "$issue_json" | jq -r '.url')
    CURRENT_ISSUE_CREATED=$(echo "$issue_json" | jq -r '.createdAt')
    CURRENT_ISSUE_AUTHOR=$(echo "$issue_json" | jq -r '.author.login // "unknown"')
    
    # リポジトリ名抽出（複数パターン対応）
    CURRENT_REPO_NAME=""
    
    # パターン1: smkwlab/k##xxx-yyy 形式
    if [[ "$CURRENT_ISSUE_TITLE" =~ smkwlab/([k][0-9]{2}[a-z0-9]+-[a-z]+) ]]; then
        CURRENT_REPO_NAME="${BASH_REMATCH[1]}"
    # パターン2: Issue本文からリポジトリ名を抽出
    elif [[ "$CURRENT_ISSUE_BODY" =~ smkwlab/([k][0-9]{2}[a-z0-9]+-[a-z]+) ]]; then
        CURRENT_REPO_NAME="${BASH_REMATCH[1]}"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: 本文からリポジトリ名を抽出: $CURRENT_REPO_NAME"
    # パターン3: より柔軟なパターン（バックティック囲み等）
    elif [[ "$CURRENT_ISSUE_TITLE$CURRENT_ISSUE_BODY" =~ \`([k][0-9]{2}[a-z0-9]+-[a-z]+)\` ]]; then
        CURRENT_REPO_NAME="${BASH_REMATCH[1]}"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: バックティック囲みからリポジトリ名を抽出: $CURRENT_REPO_NAME"
    else
        log_error "Issue #${CURRENT_ISSUE_NUMBER}: リポジトリ名を抽出できませんでした"
        log_debug "タイトル: $CURRENT_ISSUE_TITLE"
        log_debug "本文（先頭200文字）: ${CURRENT_ISSUE_BODY:0:200}"
        return 2  # 情報抽出エラーとして区別
    fi
    
    # 学生ID抽出（Issue本文とリポジトリ名の両方から試行）
    CURRENT_STUDENT_ID=""
    
    # パターン1: Issue本文から抽出
    if [[ "$CURRENT_ISSUE_BODY" =~ (k[0-9]{2}(rs|jk|gjk)[0-9]+) ]]; then
        CURRENT_STUDENT_ID="${BASH_REMATCH[1]}"
    # パターン2: リポジトリ名から抽出
    elif [[ "$CURRENT_REPO_NAME" =~ ^(k[0-9]{2}[a-z0-9]+)- ]]; then
        CURRENT_STUDENT_ID="${BASH_REMATCH[1]}"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: リポジトリ名から学生IDを抽出: $CURRENT_STUDENT_ID"
    else
        log_error "Issue #${CURRENT_ISSUE_NUMBER}: 学生IDを抽出できませんでした"
        log_debug "Issue本文（先頭200文字）: ${CURRENT_ISSUE_BODY:0:200}"
        log_debug "リポジトリ名: $CURRENT_REPO_NAME"
        return 2  # 情報抽出エラーとして区別
    fi
    
    # リポジトリタイプ判定（複数要素から総合判断）
    CURRENT_REPO_TYPE=""
    
    # パターン1: リポジトリ名から判定
    if [[ "$CURRENT_REPO_NAME" == *"-wr" ]]; then
        CURRENT_REPO_TYPE="wr"
    elif [[ "$CURRENT_REPO_NAME" == *"-sotsuron" ]]; then
        CURRENT_REPO_TYPE="sotsuron"
    elif [[ "$CURRENT_REPO_NAME" == *"-thesis" ]]; then
        CURRENT_REPO_TYPE="thesis"
    # パターン2: Issue本文から判定
    elif [[ "$CURRENT_ISSUE_BODY" =~ 週報|weekly ]]; then
        CURRENT_REPO_TYPE="wr"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: Issue本文から週報タイプを判定"
    elif [[ "$CURRENT_ISSUE_BODY" =~ 卒業論文|undergraduate|sotsuron ]]; then
        CURRENT_REPO_TYPE="sotsuron"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: Issue本文から卒論タイプを判定"
    elif [[ "$CURRENT_ISSUE_BODY" =~ 修士論文|graduate|thesis ]]; then
        CURRENT_REPO_TYPE="thesis"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: Issue本文から修論タイプを判定"
    # パターン3: 学生IDパターンから推測
    elif [[ "$CURRENT_STUDENT_ID" =~ ^k[0-9]{2}rs[0-9]+ ]]; then
        CURRENT_REPO_TYPE="sotsuron"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: 学生IDパターンから卒論タイプを推測"
    elif [[ "$CURRENT_STUDENT_ID" =~ ^k[0-9]{2}gjk[0-9]+ ]]; then
        CURRENT_REPO_TYPE="thesis"
        log_debug "Issue #${CURRENT_ISSUE_NUMBER}: 学生IDパターンから修論タイプを推測"
    else
        CURRENT_REPO_TYPE="unknown"
        log_error "Issue #${CURRENT_ISSUE_NUMBER}: リポジトリタイプを判定できませんでした"
        log_debug "リポジトリ名: $CURRENT_REPO_NAME"
        log_debug "学生ID: $CURRENT_STUDENT_ID"
        log_debug "Issue本文（先頭100文字）: ${CURRENT_ISSUE_BODY:0:100}"
        return 2  # 情報抽出エラーとして区別
    fi
    
    log_debug "Issue #${CURRENT_ISSUE_NUMBER}: $CURRENT_REPO_NAME ($CURRENT_REPO_TYPE) - $CURRENT_STUDENT_ID"
    return 0
}

#
# リポジトリ存在確認
#
check_repository_exists() {
    local repo_name="$1"
    
    if gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
        log_debug "リポジトリ存在確認: smkwlab/$repo_name ✓"
        return 0
    else
        log_debug "リポジトリ存在確認: smkwlab/$repo_name ✗"
        return 1
    fi
}

#
# ブランチ保護状態確認
#
check_branch_protection() {
    local repo_name="$1"
    
    if gh api "repos/smkwlab/$repo_name/branches/main/protection" >/dev/null 2>&1; then
        log_debug "ブランチ保護確認: smkwlab/$repo_name ✓"
        return 0
    else
        log_debug "ブランチ保護確認: smkwlab/$repo_name ✗"
        return 1
    fi
}

#
# Issue処理メイン
#
fetch_and_process_issues() {
    # Issue取得
    local issues_json
    if ! issues_json=$(fetch_pending_issues); then
        log_error "fetch_pending_issues が失敗しました"
        return 1
    fi
    
    log_debug "取得したJSON: ${issues_json:0:100}..."
    
    # Issue数の確認（空の場合を考慮）
    local issue_count_check
    issue_count_check=$(echo "$issues_json" | jq length 2>/dev/null || echo "0")
    
    log_debug "Issue数チェック結果: '$issue_count_check'"
    
    if [ -z "$issue_count_check" ] || [ "$issue_count_check" = "null" ]; then
        TOTAL_ISSUES=0
    else
        TOTAL_ISSUES="$issue_count_check"
    fi
    
    log_debug "最終的なTOTAL_ISSUES: $TOTAL_ISSUES"
    
    if [ "$TOTAL_ISSUES" -eq 0 ]; then
        log_info "未処理のIssueは見つかりませんでした"
        return 0
    fi
    
    log_info "見つかったIssue: ${TOTAL_ISSUES}件"
    
    if [ "$INTERACTIVE_MODE" = true ]; then
        process_issues_interactive "$issues_json"
    else
        process_issues_automatic "$issues_json"
    fi
    
    return $?
}

#
# 自動処理モード
#
process_issues_automatic() {
    local issues_json="$1"
    
    log_info "自動処理モードで実行中..."
    
    for i in $(seq 0 $((TOTAL_ISSUES - 1))); do
        local issue=$(echo "$issues_json" | jq ".[$i]")
        
        if ! extract_issue_info "$issue"; then
            local extract_exit_code=$?
            if [ "$extract_exit_code" = "2" ]; then
                log_warn "Issue #${CURRENT_ISSUE_NUMBER}: 情報抽出エラー、エラーカウントに追加"
                ((EXTRACTION_ERROR_COUNT++))
                EXTRACTION_ERROR_ISSUES+=("$CURRENT_ISSUE_NUMBER")
            else
                log_warn "Issue #${CURRENT_ISSUE_NUMBER}: 一般的な抽出失敗、スキップします"
                ((SKIPPED_COUNT++))
            fi
            continue
        fi
        
        log_info "処理中 ($((i + 1))/$TOTAL_ISSUES): Issue #${CURRENT_ISSUE_NUMBER} - $CURRENT_REPO_NAME"
        
        if ! check_repository_exists "$CURRENT_REPO_NAME"; then
            log_warn "Issue #${CURRENT_ISSUE_NUMBER}: リポジトリが見つかりません: $CURRENT_REPO_NAME"
            add_issue_comment "$CURRENT_ISSUE_NUMBER" "⚠️ リポジトリが見つかりません: smkwlab/$CURRENT_REPO_NAME"
            ((SKIPPED_COUNT++))
            continue
        fi
        
        if process_single_issue; then
            ((PROCESSED_COUNT++))
            log_success "Issue #${CURRENT_ISSUE_NUMBER}: 処理完了"
        else
            ((FAILED_COUNT++))
            FAILED_ISSUES+=("$CURRENT_ISSUE_NUMBER")
            log_error "Issue #${CURRENT_ISSUE_NUMBER}: 処理失敗"
        fi
    done
    
    return 0
}

#
# インタラクティブ処理モード
#
process_issues_interactive() {
    local issues_json="$1"
    
    echo
    echo "=== インタラクティブモード ==="
    echo
    
    if [ "$BATCH_CONFIRM_MODE" = true ]; then
        show_batch_confirm_summary "$issues_json"
        return $?
    fi
    
    # 各Issueを順番に処理
    for i in $(seq 0 $((TOTAL_ISSUES - 1))); do
        local issue=$(echo "$issues_json" | jq ".[$i]")
        
        if ! extract_issue_info "$issue"; then
            local extract_exit_code=$?
            if [ "$extract_exit_code" = "2" ]; then
                log_warn "Issue #${CURRENT_ISSUE_NUMBER}: 情報抽出エラー、エラーカウントに追加"
                ((EXTRACTION_ERROR_COUNT++))
                EXTRACTION_ERROR_ISSUES+=("$CURRENT_ISSUE_NUMBER")
            else
                log_warn "Issue #${CURRENT_ISSUE_NUMBER}: 一般的な抽出失敗、スキップします"
                ((SKIPPED_COUNT++))
            fi
            continue
        fi
        
        process_issue_interactive $((i + 1))
        local result=$?
        
        case $result in
            0) # 処理成功
                ((PROCESSED_COUNT++))
                ;;
            1) # 処理失敗
                ((FAILED_COUNT++))
                FAILED_ISSUES+=("$CURRENT_ISSUE_NUMBER")
                ;;
            2) # ユーザーが終了を選択
                log_info "ユーザーによる処理終了"
                break
                ;;
            3) # スキップ
                ((SKIPPED_COUNT++))
                ;;
        esac
    done
    
    show_interactive_summary
    return 0
}

#
# バッチ確認モード
#
show_batch_confirm_summary() {
    local issues_json="$1"
    
    echo "以下の${TOTAL_ISSUES}件のIssueが見つかりました:"
    echo
    
    for i in $(seq 0 $((TOTAL_ISSUES - 1))); do
        local issue=$(echo "$issues_json" | jq ".[$i]")
        
        if extract_issue_info "$issue"; then
            echo "  $((i + 1)). Issue #${CURRENT_ISSUE_NUMBER}: $CURRENT_REPO_NAME ($CURRENT_REPO_TYPE)"
            
            if ! check_repository_exists "$CURRENT_REPO_NAME"; then
                echo "     ⚠️  リポジトリが見つかりません"
            else
                echo "     ✅ リポジトリ確認済み"
                if [ "$CURRENT_REPO_TYPE" != "wr" ]; then
                    if check_branch_protection "$CURRENT_REPO_NAME"; then
                        echo "     🔒 ブランチ保護設定済み"
                    else
                        echo "     🔓 ブランチ保護未設定"
                    fi
                fi
            fi
        else
            echo "  $((i + 1)). Issue #${CURRENT_ISSUE_NUMBER}: 情報抽出失敗"
        fi
        echo
    done
    
    echo -n "全てのIssueを処理しますか? [y/N]: "
    read -r batch_confirm
    
    if [[ "$batch_confirm" =~ ^[Yy]$ ]]; then
        log_info "バッチ処理を開始します..."
        process_issues_automatic "$issues_json"
        return $?
    else
        log_info "処理をキャンセルしました"
        return 0
    fi
}

#
# 個別Issue処理（インタラクティブ）
#
process_issue_interactive() {
    local current="$1"
    
    while true; do
        clear
        show_issue_summary "$current"
        
        echo "  処理方法を選択してください:"
        echo "  [p] 処理実行   [c] Issueクローズ   [d] Issue削除   [s] スキップ   [v] 詳細表示   [q] 終了"
        echo -n "  選択: "
        read -r choice
        
        case "$choice" in
            p|P)
                echo
                return execute_issue_processing
                ;;
            c|C)
                echo
                return execute_issue_close_only
                ;;
            d|D)
                echo
                return execute_issue_delete
                ;;
            s|S)
                echo
                log_info "Issue #${CURRENT_ISSUE_NUMBER} をスキップしました"
                echo "続行するには Enter を押してください..."
                read -r
                return 3  # スキップシグナル
                ;;
            v|V)
                show_issue_details
                echo
                echo "処理方法を選択してください:"
                echo "[p] 処理実行   [c] Issueクローズ   [d] Issue削除   [s] スキップ   [b] 戻る   [q] 終了"
                echo -n "選択: "
                read -r detail_choice
                
                case "$detail_choice" in
                    p|P)
                        echo
                        execute_issue_processing
                        return $?
                        ;;
                    c|C)
                        echo
                        execute_issue_close_only
                        return $?
                        ;;
                    d|D)
                        echo
                        execute_issue_delete
                        return $?
                        ;;
                    s|S)
                        echo
                        log_info "Issue #${CURRENT_ISSUE_NUMBER} をスキップしました"
                        echo "続行するには Enter を押してください..."
                        read -r
                        return 3  # スキップシグナル
                        ;;
                    b|B)
                        continue
                        ;;
                    q|Q)
                        return 2  # 終了シグナル
                        ;;
                    *)
                        echo "無効な選択です。"
                        sleep 1
                        continue
                        ;;
                esac
                ;;
            q|Q)
                return 2  # 終了シグナル
                ;;
            *)
                echo "無効な選択です。再度選択してください。"
                sleep 1
                continue
                ;;
        esac
    done
}

#
# Issue情報表示
#
show_issue_summary() {
    local current="$1"
    
    echo "Issue #${CURRENT_ISSUE_NUMBER} (${current}/${TOTAL_ISSUES}): ${CURRENT_ISSUE_TITLE}"
    echo
    
    # リポジトリタイプ表示
    case "$CURRENT_REPO_TYPE" in
        wr)
            echo "  種別: 週報リポジトリ"
            ;;
        sotsuron)
            echo "  種別: 論文リポジトリ（卒業論文）"
            ;;
        thesis)
            echo "  種別: 論文リポジトリ（修士論文）"
            ;;
        *)
            echo "  種別: 不明 (${CURRENT_REPO_TYPE})"
            ;;
    esac
    
    echo "  発行者: ${CURRENT_ISSUE_AUTHOR:-'不明'}"
    echo "  学生ID: ${CURRENT_STUDENT_ID:-'不明'}"
    echo "  リポジトリ: smkwlab/${CURRENT_REPO_NAME}"
    
    # リポジトリ存在確認
    if check_repository_exists "$CURRENT_REPO_NAME"; then
        echo "  リポジトリ状態: ✅ 存在確認済み"
        
        # ブランチ保護状態確認（論文リポジトリのみ）
        if [ "$CURRENT_REPO_TYPE" != "wr" ]; then
            if check_branch_protection "$CURRENT_REPO_NAME"; then
                echo "  ブランチ保護状態: ✅ 設定済み"
            else
                echo "  ブランチ保護状態: ❌ 未設定"
            fi
        fi
    else
        echo "  リポジトリ状態: ❌ 見つかりません"
    fi
    
    echo
}

#
# Issue詳細情報表示
#
show_issue_details() {
    clear
    echo "=== Issue #${CURRENT_ISSUE_NUMBER} 詳細情報 ==="
    echo
    echo "タイトル: $CURRENT_ISSUE_TITLE"
    echo "URL: $CURRENT_ISSUE_URL"
    echo "作成日: $(echo "$CURRENT_ISSUE_CREATED" | sed 's/T/ /' | sed 's/Z/ UTC/')"
    echo
    echo "本文:"
    echo "$CURRENT_ISSUE_BODY" | head -20 | sed 's/^/  /'
    if [ $(echo "$CURRENT_ISSUE_BODY" | wc -l) -gt 20 ]; then
        echo "  ... (省略)"
    fi
    echo
    
    echo "実行される処理:"
    if [ "$CURRENT_REPO_TYPE" = "wr" ]; then
        echo "  1. thesis-student-registry への登録"
        echo "  2. active.txt への追加"
        echo "  3. Issue クローズ"
    else
        echo "  1. ブランチ保護設定 (main, review-branch)"
        echo "  2. thesis-student-registry への登録"
        echo "  3. active.txt への追加"
        echo "  4. Issue クローズ"
    fi
    echo
}

#
# 処理実行とフィードバック
#
execute_issue_processing() {
    echo "処理を実行中..."
    echo
    
    # リポジトリ存在確認
    if ! check_repository_exists "$CURRENT_REPO_NAME"; then
        echo "❌ リポジトリが見つかりません: smkwlab/$CURRENT_REPO_NAME"
        add_issue_comment "$CURRENT_ISSUE_NUMBER" "⚠️ リポジトリが見つかりません: smkwlab/$CURRENT_REPO_NAME"
        echo
        echo "続行するには Enter を押してください..."
        read -r
        return 3  # スキップとして扱う
    fi
    
    if [ "$CURRENT_REPO_TYPE" = "wr" ]; then
        echo "→ 週報リポジトリの登録処理を実行中..."
        if process_weekly_report_with_feedback; then
            echo "✅ 処理が完了しました"
        else
            echo "❌ 処理に失敗しました"
            echo
            echo "続行するには Enter を押してください..."
            read -r
            return 1
        fi
    else
        echo "→ 論文リポジトリの処理を実行中..."
        if process_thesis_with_feedback; then
            echo "✅ 処理が完了しました"
        else
            echo "❌ 処理に失敗しました"
            echo
            echo "続行するには Enter を押してください..."
            read -r
            return 1
        fi
    fi
    
    echo
    echo -n "続行しますか? [Enter] で次へ、[q] で終了: "
    read -r continue_choice
    if [ "$continue_choice" = "q" ] || [ "$continue_choice" = "Q" ]; then
        return 2  # 終了シグナル
    fi
    
    return 0
}

#
# Issueクローズのみ実行
#
execute_issue_close_only() {
    echo "Issueをクローズ中..."
    echo
    
    if close_issue_with_comment "$CURRENT_ISSUE_NUMBER" "✅ Issue手動クローズ

Issue #${CURRENT_ISSUE_NUMBER} を手動でクローズしました。
リポジトリ登録やブランチ保護設定は実行されていません。

必要に応じて個別に処理を実行してください。"; then
        echo "✅ Issue #${CURRENT_ISSUE_NUMBER} をクローズしました"
    else
        echo "❌ Issue クローズに失敗しました"
        echo
        echo "続行するには Enter を押してください..."
        read -r
        return 1
    fi
    
    echo
    echo -n "続行しますか? [Enter] で次へ、[q] で終了: "
    read -r continue_choice
    if [ "$continue_choice" = "q" ] || [ "$continue_choice" = "Q" ]; then
        return 2  # 終了シグナル
    fi
    
    return 0
}

#
# Issue削除実行
#
execute_issue_delete() {
    echo "⚠️  警告: Issue削除は取り消しできません"
    echo "Issue #${CURRENT_ISSUE_NUMBER}: ${CURRENT_ISSUE_TITLE}"
    echo
    echo -n "本当に削除しますか? [yes/NO]: "
    read -r confirm_delete
    
    if [ "$confirm_delete" = "yes" ]; then
        echo "Issue削除中..."
        echo
        
        # GitHub CLIでIssue削除（要管理者権限）
        if gh issue delete "$CURRENT_ISSUE_NUMBER" --repo "$REPO" --confirm >/dev/null 2>&1; then
            echo "✅ Issue #${CURRENT_ISSUE_NUMBER} を削除しました"
        else
            echo "❌ Issue削除に失敗しました"
            echo "  削除には管理者権限が必要です"
            echo
            echo "続行するには Enter を押してください..."
            read -r
            return 1
        fi
    else
        echo "Issue削除をキャンセルしました"
    fi
    
    echo
    echo -n "続行しますか? [Enter] で次へ、[q] で終了: "
    read -r continue_choice
    if [ "$continue_choice" = "q" ] || [ "$continue_choice" = "Q" ]; then
        return 2  # 終了シグナル
    fi
    
    return 0
}

#
# 週報リポジトリ処理（詳細フィードバック付き）
#
process_weekly_report_with_feedback() {
    echo "  📝 週報リポジトリの処理を開始..."
    
    # 1. thesis-student-registry 更新
    echo "  thesis-student-registry への登録中..."
    if update_thesis_student_registry "$CURRENT_REPO_NAME" "$CURRENT_STUDENT_ID" "wr" "completed"; then
        echo "  ✅ thesis-student-registry への登録完了"
    else
        echo "  ❌ thesis-student-registry への登録失敗"
        return 1
    fi
    
    # 2. active.txt 更新
    echo "  active.txt への追加中..."
    if add_to_active_repos "$CURRENT_REPO_NAME"; then
        echo "  ✅ active.txt への追加完了"
    else
        echo "  ❌ active.txt への追加失敗"
        return 1
    fi
    
    # 3. Issue クローズ
    echo "  Issue クローズ中..."
    if close_issue_with_comment "$CURRENT_ISSUE_NUMBER" "✅ 週報リポジトリの登録が完了しました

## 登録内容
- **リポジトリ**: smkwlab/$CURRENT_REPO_NAME
- **学生ID**: $CURRENT_STUDENT_ID
- **登録日時**: $(date '+%Y-%m-%d %H:%M:%S JST')

週報リポジトリは登録のみで管理されます。ブランチ保護設定は不要です。"; then
        echo "  ✅ Issue #${CURRENT_ISSUE_NUMBER} をクローズしました"
    else
        echo "  ❌ Issue クローズに失敗しました"
        return 1
    fi
    
    return 0
}

#
# 論文リポジトリ処理（詳細フィードバック付き）
#
process_thesis_with_feedback() {
    echo "  📚 論文リポジトリの処理を開始..."
    echo ""
    
    # 1. ブランチ保護設定
    echo "  ブランチ保護設定を適用中..."
    if setup_branch_protection_for_issue "$CURRENT_REPO_NAME"; then
        echo "  ✅ ブランチ保護設定完了"
    else
        echo "  ❌ ブランチ保護設定失敗"
        return 1
    fi
    
    # 2. thesis-student-registry 更新
    echo "  thesis-student-registry への登録中..."
    if update_thesis_student_registry "$CURRENT_REPO_NAME" "$CURRENT_STUDENT_ID" "$CURRENT_REPO_TYPE" "completed"; then
        echo "  ✅ thesis-student-registry への登録完了"
    else
        echo "  ❌ thesis-student-registry への登録失敗"
        return 1
    fi
    
    # 3. active.txt 更新
    echo "  active.txt への追加中..."
    if add_to_active_repos "$CURRENT_REPO_NAME"; then
        echo "  ✅ active.txt への追加完了"
    else
        echo "  ❌ active.txt への追加失敗"
        return 1
    fi
    
    # 4. completed-protection.txt 更新
    echo "  protection status への追加中..."
    if add_to_completed_protection "$CURRENT_REPO_NAME" "$CURRENT_STUDENT_ID"; then
        echo "  ✅ protection status への追加完了"
    else
        echo "  ❌ protection status への追加失敗"
        return 1
    fi
    
    # 5. Issue クローズ
    echo "  Issue クローズ中..."
    if close_issue_with_comment "$CURRENT_ISSUE_NUMBER" "✅ 論文リポジトリの設定が完了しました

## 設定内容
- **リポジトリ**: smkwlab/$CURRENT_REPO_NAME
- **学生ID**: $CURRENT_STUDENT_ID
- **設定日時**: $(date '+%Y-%m-%d %H:%M:%S JST')

## ブランチ保護設定
- **main ブランチ**: 1つ以上の承認レビューが必要
- **review-branch**: 存在する場合は同様に保護
- **新しいコミット時**: 古いレビューを無効化
- **フォースプッシュ**: 禁止
- **ブランチ削除**: 禁止

## 確認
リポジトリ設定: https://github.com/smkwlab/$CURRENT_REPO_NAME/settings/branches"; then
        echo "  ✅ Issue #${CURRENT_ISSUE_NUMBER} をクローズしました"
    else
        echo "  ❌ Issue クローズに失敗しました"
        return 1
    fi
    
    echo ""
    echo "📋 実行された操作:"
    echo "  • ブランチ保護設定 (main, review-branch)"
    echo "  • thesis-student-registry への登録"
    echo "  • active.txt への追加"
    echo "  • protection status への追加"
    echo "  • Issue #$CURRENT_ISSUE_NUMBER のクローズ"
    echo ""
    
    return 0
}

#
# インタラクティブモード サマリー表示
#
show_interactive_summary() {
    echo
    echo "=== インタラクティブ処理完了 ==="
    echo "処理済み: ${PROCESSED_COUNT}件"
    echo "スキップ: ${SKIPPED_COUNT}件"
    echo "失敗: ${FAILED_COUNT}件"
    echo "情報抽出エラー: ${EXTRACTION_ERROR_COUNT}件"
    
    if [ ${FAILED_COUNT} -gt 0 ]; then
        echo
        echo "失敗したIssue:"
        for failed_issue in "${FAILED_ISSUES[@]}"; do
            echo "  - Issue #${failed_issue}"
        done
    fi
    
    if [ ${EXTRACTION_ERROR_COUNT} -gt 0 ]; then
        echo
        echo "情報抽出エラーのIssue（データ形式確認が必要）:"
        for error_issue in "${EXTRACTION_ERROR_ISSUES[@]}"; do
            echo "  - Issue #${error_issue}"
        done
    fi
}

#
# 単一Issue処理
#
process_single_issue() {
    case "$CURRENT_REPO_TYPE" in
        wr)
            process_weekly_report_issue
            ;;
        sotsuron|thesis)
            process_thesis_issue
            ;;
        *)
            log_error "不明なリポジトリタイプ: $CURRENT_REPO_TYPE"
            return 1
            ;;
    esac
}

#
# 週報リポジトリ処理
#
process_weekly_report_issue() {
    log_info "週報リポジトリ処理: $CURRENT_REPO_NAME"
    
    # 1. thesis-student-registry への登録
    if ! update_thesis_student_registry "$CURRENT_REPO_NAME" "$CURRENT_STUDENT_ID" "wr" "completed"; then
        log_error "thesis-student-registry への登録に失敗: $CURRENT_REPO_NAME"
        return 1
    fi
    
    # 2. active.txt への追加
    if ! add_to_active_repos "$CURRENT_REPO_NAME"; then
        log_error "active.txt への追加に失敗: $CURRENT_REPO_NAME"
        return 1
    fi
    
    # 3. Issue クローズ
    if ! close_issue_with_comment "$CURRENT_ISSUE_NUMBER" "✅ 週報リポジトリの登録が完了しました

## 登録内容
- **リポジトリ**: smkwlab/$CURRENT_REPO_NAME
- **学生ID**: $CURRENT_STUDENT_ID
- **登録日時**: $(date '+%Y-%m-%d %H:%M:%S JST')

週報リポジトリは登録のみで管理されます。ブランチ保護設定は不要です。

論文執筆は以下のガイドを参照してください：
https://github.com/smkwlab/$CURRENT_REPO_NAME/blob/main/WRITING-GUIDE.md"; then
        log_error "Issue クローズに失敗: #$CURRENT_ISSUE_NUMBER"
        return 1
    fi
    
    log_success "週報リポジトリ処理完了: $CURRENT_REPO_NAME"
    return 0
}

#
# 論文リポジトリ処理
#
process_thesis_issue() {
    log_info "論文リポジトリ処理: $CURRENT_REPO_NAME"
    
    # 1. ブランチ保護設定
    if ! setup_branch_protection_for_issue "$CURRENT_REPO_NAME"; then
        log_error "ブランチ保護設定に失敗: $CURRENT_REPO_NAME"
        return 1
    fi
    
    # 2. thesis-student-registry への登録
    if ! update_thesis_student_registry "$CURRENT_REPO_NAME" "$CURRENT_STUDENT_ID" "$CURRENT_REPO_TYPE" "completed"; then
        log_error "thesis-student-registry への登録に失敗: $CURRENT_REPO_NAME"
        return 1
    fi
    
    # 3. active.txt への追加
    if ! add_to_active_repos "$CURRENT_REPO_NAME"; then
        log_error "active.txt への追加に失敗: $CURRENT_REPO_NAME"
        return 1
    fi
    
    # 4. completed-protection.txt への追加
    if ! add_to_completed_protection "$CURRENT_REPO_NAME" "$CURRENT_STUDENT_ID"; then
        log_error "completed-protection.txt への追加に失敗: $CURRENT_REPO_NAME"
        return 1
    fi
    
    # 5. Issue クローズ
    if ! close_issue_with_comment "$CURRENT_ISSUE_NUMBER" "✅ 論文リポジトリの設定が完了しました

## 設定内容
- **リポジトリ**: smkwlab/$CURRENT_REPO_NAME
- **学生ID**: $CURRENT_STUDENT_ID
- **設定日時**: $(date '+%Y-%m-%d %H:%M:%S JST')

## ブランチ保護設定
- **main ブランチ**: 1つ以上の承認レビューが必要
- **review-branch**: 存在する場合は同様に保護
- **新しいコミット時**: 古いレビューを無効化
- **フォースプッシュ**: 禁止
- **ブランチ削除**: 禁止

## 確認
リポジトリ設定: https://github.com/smkwlab/$CURRENT_REPO_NAME/settings/branches

論文執筆は以下のガイドを参照してください：
https://github.com/smkwlab/$CURRENT_REPO_NAME/blob/main/WRITING-GUIDE.md"; then
        log_error "Issue クローズに失敗: #$CURRENT_ISSUE_NUMBER"
        return 1
    fi
    
    log_success "論文リポジトリ処理完了: $CURRENT_REPO_NAME"
    return 0
}

#
# Issueコメント追加
#
add_issue_comment() {
    local issue_number="$1"
    local comment="$2"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] Issue #${issue_number} にコメント追加: $comment"
        return 0
    fi
    
    if gh issue comment "$issue_number" --repo "$REPO" --body "$comment" >/dev/null 2>&1; then
        log_debug "Issue #${issue_number} にコメントを追加しました"
        return 0
    else
        log_warn "Issue #${issue_number} へのコメント追加に失敗しました"
        return 1
    fi
}

#
# thesis-student-registry 更新（GitHub API経由）
#
update_thesis_student_registry() {
    local repo_name="$1"
    local student_id="$2"
    local repo_type="$3"
    local status="$4"
    
    log_debug "thesis-student-registry 更新: $repo_name ($repo_type) - $student_id"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] thesis-student-registry 更新: $repo_name"
        return 0
    fi
    
    # 現在のrepositories.jsonを取得
    local current_json
    if ! current_json=$(gh api repos/smkwlab/thesis-student-registry/contents/data/repositories.json --jq '.content' | base64 -d 2>/dev/null); then
        log_error "repositories.json の取得に失敗: $repo_name"
        log_error "考えられる原因:"
        log_error "  - GitHub APIアクセス権限不足"
        log_error "  - ネットワーク接続問題"
        log_error "  - thesis-student-registry リポジトリへのアクセス権限不足"
        return 1
    fi
    
    # 新しいエントリを作成
    local updated_at=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    local new_entry=$(cat <<EOF
{
  "student_id": "$student_id",
  "repository_type": "$repo_type",
  "status": "$status",
  "stage": "$repo_type",
  "updated_at": "$updated_at"
}
EOF
)
    
    # JSONを更新（既存エントリを明示的に削除してから新規追加）
    local updated_json
    if ! updated_json=$(echo "$current_json" | jq --arg repo_name "$repo_name" --argjson new_entry "$new_entry" 'del(.[$repo_name]) | . + {($repo_name): $new_entry}'); then
        log_error "JSON更新処理に失敗: $repo_name"
        return 1
    fi
    
    # GitHub APIで更新
    local sha
    if ! sha=$(gh api repos/smkwlab/thesis-student-registry/contents/data/repositories.json --jq '.sha'); then
        log_error "SHA取得に失敗: $repo_name"
        log_error "考えられる原因:"
        log_error "  - GitHub APIアクセス権限不足"
        log_error "  - repositories.json ファイルが存在しない"
        log_error "  - リポジトリアクセス権限不足"
        return 1
    fi
    
    # 個人情報保護のため学生IDをマスク化
    local masked_student_id="${student_id:0:3}***${student_id: -2}"
    local commit_message="Add/update repository: $repo_name

Repository: $repo_name
Student ID: $masked_student_id
Type: $repo_type
Status: $status
Updated: $updated_at

Processed via automated issue processor."
    
    # base64エンコードしてGitHub APIで更新
    local encoded_content
    if ! encoded_content=$(echo "$updated_json" | base64); then
        log_error "base64エンコードに失敗: $repo_name"
        log_error "考えられる原因:"
        log_error "  - JSON形式エラー"
        log_error "  - base64コマンドの問題"
        log_error "  - メモリ不足"
        return 1
    fi
    
    if gh api repos/smkwlab/thesis-student-registry/contents/data/repositories.json \
        --method PUT \
        --field message="$commit_message" \
        --field content="$encoded_content" \
        --field sha="$sha" >/dev/null 2>&1; then
        log_debug "thesis-student-registry 更新成功: $repo_name"
        return 0
    else
        log_error "GitHub API更新に失敗: $repo_name"
        log_error "考えられる原因:"
        log_error "  - GitHub APIレート制限"
        log_error "  - ファイル書き込み権限不足"
        log_error "  - SHA値の不一致（同時更新による競合）"
        log_error "  - ネットワーク接続問題"
        log_error "  - API認証期限切れ"
        return 1
    fi
}

#
# active.txt への追加
#
add_to_active_repos() {
    local repo_name="$1"
    
    log_debug "active.txt への追加: $repo_name"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] active.txt への追加: $repo_name"
        return 0
    fi
    
    local active_file="$PROJECT_ROOT/data/repositories/active.txt"
    
    # 重複チェック
    if [ -f "$active_file" ] && grep -q "^$repo_name$" "$active_file" 2>/dev/null; then
        log_debug "active.txt に既に存在: $repo_name"
        return 0
    fi
    
    # 追加
    if echo "$repo_name" >> "$active_file"; then
        log_debug "active.txt に追加完了: $repo_name"
        
        # ソート（重複排除込み）- エラーが発生しても処理を継続
        if ! sort -u "$active_file" -o "$active_file" 2>/dev/null; then
            log_warn "active.txt ソートに失敗しましたが、処理を続行します"
        else
            log_debug "active.txt ソート完了"
        fi
        
        return 0
    else
        log_error "active.txt への書き込みに失敗: $repo_name"
        return 1
    fi
}

#
# ブランチ保護設定（Issue処理用）
#
setup_branch_protection_for_issue() {
    local repo_name="$1"
    
    log_debug "ブランチ保護設定開始: $repo_name"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] ブランチ保護設定: $repo_name"
        return 0
    fi
    
    # ブランチ保護設定（将来的に外部ファイル化を検討）
    local protection_config
    protection_config=$(cat <<'EOF'
{
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
}
EOF
)
    
    # ブランチ存在確認とリスト作成
    local branches_to_protect=("main")
    
    if ! gh api "repos/smkwlab/$repo_name/branches/main" >/dev/null 2>&1; then
        log_error "main ブランチが見つかりません: smkwlab/$repo_name"
        return 1
    fi
    
    # review-branchの存在確認
    if gh api "repos/smkwlab/$repo_name/branches/review-branch" >/dev/null 2>&1; then
        branches_to_protect+=("review-branch")
        log_debug "review-branchが見つかりました: $repo_name"
    fi
    
    # 各ブランチに保護設定を適用
    local success_count=0
    local total_branches=${#branches_to_protect[@]}
    
    for branch in "${branches_to_protect[@]}"; do
        log_debug "ブランチ保護設定適用中: $branch"
        
        # 既存の保護設定確認（冪等性保証）
        if gh api "repos/smkwlab/$repo_name/branches/$branch/protection" >/dev/null 2>&1; then
            log_debug "ブランチ '$branch' は既に保護設定済み: $repo_name"
            success_count=$((success_count + 1))
            continue
        fi
        
        # 保護設定適用
        if echo "$protection_config" | gh api "repos/smkwlab/$repo_name/branches/$branch/protection" \
            --method PUT \
            --input - >/dev/null 2>&1; then
            log_debug "ブランチ保護設定成功: $branch ($repo_name)"
            success_count=$((success_count + 1))
        else
            log_error "ブランチ保護設定失敗: $branch ($repo_name)"
        fi
    done
    
    if [ "$success_count" -eq "$total_branches" ]; then
        log_debug "すべてのブランチ保護設定完了: $repo_name"
        return 0
    else
        log_error "一部のブランチ保護設定に失敗: $repo_name ($success_count/$total_branches)"
        return 1
    fi
}

#
# completed-protection.txt への追加
#
add_to_completed_protection() {
    local repo_name="$1"
    local student_id="$2"
    
    log_debug "completed-protection.txt への追加: $repo_name"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] completed-protection.txt への追加: $repo_name"
        return 0
    fi
    
    local completed_file="$PROJECT_ROOT/data/protection-status/completed-protection.txt"
    
    # ディレクトリ作成
    local protection_dir="$(dirname "$completed_file")"
    if [ ! -d "$protection_dir" ]; then
        mkdir -p "$protection_dir"
        log_debug "ディレクトリを作成: $protection_dir"
    fi
    
    # 重複チェック
    if [ -f "$completed_file" ] && grep -q "^$repo_name " "$completed_file" 2>/dev/null; then
        log_debug "completed-protection.txt に既に存在: $repo_name"
        return 0
    fi
    
    # 追加
    if echo "$repo_name # Completed: $(date +%Y-%m-%d) Student: $student_id" >> "$completed_file"; then
        log_debug "completed-protection.txt に追加完了: $repo_name"
        return 0
    else
        log_error "completed-protection.txt への書き込みに失敗: $repo_name"
        return 1
    fi
}

#
# Issueクローズ
#
close_issue_with_comment() {
    local issue_number="$1"
    local comment="$2"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        log_info "[DRY-RUN] Issue #${issue_number} をクローズ: $comment"
        return 0
    fi
    
    # コメント追加
    if ! add_issue_comment "$issue_number" "$comment"; then
        log_warn "Issue #${issue_number}: コメント追加に失敗しましたが、クローズを続行します"
    fi
    
    # Issue クローズ
    if gh issue close "$issue_number" --repo "$REPO" --reason completed >/dev/null 2>&1; then
        log_debug "Issue #${issue_number} をクローズしました"
        return 0
    else
        log_error "Issue #${issue_number} のクローズに失敗しました"
        return 1
    fi
}

#
# メイン関数
#
main() {
    echo "=== 未処理Issue一括処理スクリプト ==="
    echo "実行時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "ログファイル: $LOG_FILE"

    if [ "$DRY_RUN_MODE" = true ]; then
        echo -e "${YELLOW}[DRY-RUN モード] 実際の変更は行いません${NC}"
    fi

    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${CYAN}[DEBUG モード] 詳細ログを出力します${NC}"
    fi

    echo

    # 前提条件チェック
    if ! check_prerequisites; then
        log_error "前提条件チェックに失敗しました"
        exit 1
    fi

    # バックアップ作成
    if ! create_backup; then
        log_error "バックアップ作成に失敗しました"
        exit 1
    fi

    # thesis-student-registry 準備
    if ! prepare_registry; then
        log_error "thesis-student-registry の準備に失敗しました"
        exit 1
    fi

    # Issue取得・処理
    if ! fetch_and_process_issues; then
        log_error "Issue処理に失敗しました"
        exit 1
    fi

    log_success "スクリプト実行完了"
    echo
    echo "実行結果:"
    echo "  処理済み: ${PROCESSED_COUNT}件"
    echo "  スキップ: ${SKIPPED_COUNT}件"
    echo "  失敗: ${FAILED_COUNT}件"
    echo "  情報抽出エラー: ${EXTRACTION_ERROR_COUNT}件"
    echo "  ログファイル: $LOG_FILE"
    
    if [ ${EXTRACTION_ERROR_COUNT} -gt 0 ]; then
        echo
        echo "情報抽出エラーのIssue（確認推奨）:"
        for error_issue in "${EXTRACTION_ERROR_ISSUES[@]}"; do
            echo "  - Issue #${error_issue}"
        done
    fi
}

# オプション解析
parse_options "$@"

# メイン処理実行
main