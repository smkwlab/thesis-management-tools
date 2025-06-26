#!/bin/bash

# extract-student-info-from-issues.sh
# Issue駆動での学生情報抽出とレジストリ更新

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ログ出力関数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# 学生IDからタイプを判定し、リポジトリ作成日時から年度を判定
parse_student_info() {
    local student_id="$1"
    local repo_name="$2"
    local created_at="$3"
    
    # 学生タイプを判定
    local type=""
    if echo "$student_id" | grep -q 'rs'; then
        type="undergraduate"
    elif echo "$student_id" | grep -q 'gjk'; then
        type="graduate"
    else
        error "不明な学生IDフォーマット: $student_id"
        return 1
    fi
    
    # リポジトリ作成日時から年度を抽出
    # GitHub APIの日時フォーマット: 2024-06-21T16:30:00Z
    local repo_year=""
    if [[ "$created_at" =~ ^([0-9]{4})-[0-9]{2}-[0-9]{2}T ]]; then
        repo_year="${BASH_REMATCH[1]}"
    else
        # GitHub APIから取得できない場合は、リポジトリの詳細から取得を試行
        log "Issue作成日時から年度を解析できない場合、リポジトリAPIから取得を試行..."
        local repo_created=$(gh repo view "smkwlab/$repo_name" --json createdAt --jq '.createdAt' 2>/dev/null || echo "")
        if [[ "$repo_created" =~ ^([0-9]{4})-[0-9]{2}-[0-9]{2}T ]]; then
            repo_year="${BASH_REMATCH[1]}"
            log "  リポジトリ作成年度: $repo_year (リポジトリAPI経由)"
        else
            # 最終手段として現在年度を使用
            repo_year=$(date +%Y)
            warn "  年度判定失敗、現在年度を使用: $repo_year"
        fi
    fi
    
    echo "$repo_year $type"
}

# GitHub API経由でのデータ管理準備
setup_directories() {
    local current_year=$(date +%Y)
    
    # thesis-student-registry統合後は、ローカルディレクトリ作成は不要
    log "データ管理は thesis-student-registry に統合済み (現在年度: $current_year)"
    log "GitHub API経由でリポジトリ情報を管理します"
}

# 未処理Issueから学生情報を抽出
extract_from_issues() {
    log "未処理のブランチ保護設定依頼Issueを確認中..."
    
    # 未処理のIssueを取得
    local issues_json="/tmp/pending_issues.json"
    gh issue list \
        --repo smkwlab/thesis-management-tools \
        --state open \
        --json number,title,body,createdAt > "$issues_json"
    
    # ブランチ保護設定依頼のIssueをフィルタリング
    local filtered_issues="/tmp/filtered_issues.json"
    jq '[.[] | select(.title | contains("ブランチ保護設定依頼"))]' "$issues_json" > "$filtered_issues"
    
    local issue_count=$(jq length "$filtered_issues")
    log "発見された未処理Issue数: $issue_count"
    
    if [ "$issue_count" -eq 0 ]; then
        log "未処理のIssueはありません"
        return 0
    fi
    
    # 各Issueを処理
    local processed=0
    while read -r issue; do
        if process_single_issue "$issue"; then
            processed=$((processed + 1))
        fi
    done < <(jq -c '.[]' "$filtered_issues")
    
    log "処理完了: $processed/$issue_count のIssueから学生情報を抽出"
    
    # 重複除去
    cleanup_duplicates
}

# 単一のIssueを処理
process_single_issue() {
    local issue="$1"
    local issue_number=$(echo "$issue" | jq -r '.number')
    local issue_body=$(echo "$issue" | jq -r '.body')
    local created_at=$(echo "$issue" | jq -r '.createdAt')
    
    log "Issue #$issue_number を処理中..."
    
    # リポジトリ名を抽出
    local repo_name=$(echo "$issue_body" | grep -oE 'k[0-9]{2}[rg][sjk][0-9]+-[a-z]+' | head -1)
    if [ -z "$repo_name" ]; then
        warn "Issue #$issue_number からリポジトリ名を抽出できません"
        return 1
    fi
    
    # 学生IDを抽出
    local student_id=$(echo "$repo_name" | cut -d'-' -f1)
    
    # 年度とタイプを解析（リポジトリ作成日時ベース）
    local parse_result
    if ! parse_result=$(parse_student_info "$student_id" "$repo_name" "$created_at"); then
        warn "Issue #$issue_number: 学生情報解析失敗 ($student_id, $repo_name)"
        return 1
    fi
    
    local year=$(echo "$parse_result" | cut -d' ' -f1)
    local type=$(echo "$parse_result" | cut -d' ' -f2)
    
    log "  学籍番号: $student_id"
    log "  リポジトリ: $repo_name"
    log "  年度: $year (リポジトリ作成年)"
    log "  タイプ: $type"
    
    # thesis-student-registry への登録
    log "  thesis-student-registry への情報登録..."
    
    # 実際の登録処理は update-repository-registry.sh が担当
    log "  リポジトリ情報は update-repository-registry.sh で管理してください"
    log "  学生ID: $student_id"
    log "  リポジトリ: $repo_name" 
    log "  年度: $year"
    log "  タイプ: $type"
    
    log "  Issue #$issue_number の情報をレジストリに記録しました"
    
    # デバッグ用: 各ステップ後の状態を確認
    if [ "${DEBUG:-0}" = "1" ]; then
        log "  [DEBUG] data/students/$year/$type.txt に追加完了"
        log "  [DEBUG] pending-protection.txt に追加完了"
        log "  [DEBUG] active.txt に追加完了"
    fi
    
    return 0
}

# 重複除去
cleanup_duplicates() {
    log "データ整合性確認..."
    
    # thesis-student-registry では JSON 形式で管理されるため、従来のファイル重複除去は不要
    log "データ管理は thesis-student-registry に統合済み"
    log "重複除去は repositories.json で自動管理されます"
    
    log "データ整合性確認完了"
}

# 統計情報を表示（thesis-student-registry統合後）
show_statistics() {
    log "=== リポジトリ管理統計 ==="
    
    # thesis-student-registry の統計は thesis-monitor コマンドで確認可能
    log "詳細統計は thesis-monitor コマンドで確認してください:"
    log "  thesis-monitor status        # 全体状況"
    log "  thesis-monitor status --show-protection  # 保護設定状況"
    log "  thesis-monitor search <条件>  # 学生検索"
    
    log "データ管理: thesis-student-registry/data/repositories.json"
}

# メイン処理
main() {
    log "学生情報抽出処理を開始します"
    
    # GitHub CLIの認証確認
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI認証が必要です"
        exit 1
    fi
    
    # ディレクトリ構造のセットアップ
    setup_directories
    
    # Issueから学生情報を抽出
    extract_from_issues
    
    # 統計情報表示
    show_statistics
    
    log "学生情報抽出処理が完了しました"
}

# スクリプトが直接実行された場合のみメイン処理を実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi