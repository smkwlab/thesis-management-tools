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

# 学生IDから年度とタイプを解析
parse_student_id() {
    local student_id="$1"
    local year_suffix=$(echo "$student_id" | grep -oE '[0-9]{2}' | head -1)
    local full_year="20$year_suffix"
    local type=""
    
    if echo "$student_id" | grep -q 'rs'; then
        type="undergraduate"
    elif echo "$student_id" | grep -q 'gjk'; then
        type="graduate"
    else
        error "不明な学生IDフォーマット: $student_id"
        return 1
    fi
    
    echo "$full_year $type"
}

# ディレクトリ構造を作成
setup_directories() {
    local current_year=$(date +%Y)
    
    # 必要なディレクトリを作成
    mkdir -p "data/students"
    mkdir -p "data/protection-status"
    mkdir -p "data/repositories"
    
    # 現在年度を記録
    echo "$current_year" > "data/students/current-year.txt"
    
    log "ディレクトリ構造を初期化しました (現在年度: $current_year)"
}

# 未処理Issueから学生情報を抽出
extract_from_issues() {
    log "未処理のブランチ保護設定依頼Issueを確認中..."
    
    # 未処理のIssueを取得
    local issues_json="/tmp/pending_issues.json"
    gh issue list \
        --repo smkwlab/thesis-management-tools \
        --state open \
        --json number,title,body,createdAt \
        --jq '.[] | select(.title | contains("ブランチ保護設定依頼"))' > "$issues_json"
    
    local issue_count=$(jq length "$issues_json")
    log "発見された未処理Issue数: $issue_count"
    
    if [ "$issue_count" -eq 0 ]; then
        log "未処理のIssueはありません"
        return 0
    fi
    
    # 各Issueを処理
    local processed=0
    while read -r issue; do
        if process_single_issue "$issue"; then
            ((processed++))
        fi
    done < <(jq -c '.[]' "$issues_json")
    
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
    
    # 年度とタイプを解析
    local parse_result
    if ! parse_result=$(parse_student_id "$student_id"); then
        warn "Issue #$issue_number: 学生ID解析失敗 ($student_id)"
        return 1
    fi
    
    local year=$(echo "$parse_result" | cut -d' ' -f1)
    local type=$(echo "$parse_result" | cut -d' ' -f2)
    
    log "  学籍番号: $student_id"
    log "  リポジトリ: $repo_name"
    log "  年度: $year"
    log "  タイプ: $type"
    
    # 年度ディレクトリを作成
    mkdir -p "data/students/$year"
    
    # 学生レジストリに追加
    echo "$student_id" >> "data/students/$year/$type.txt"
    
    # ブランチ保護待ちリストに追加
    echo "$repo_name" >> "data/protection-status/pending-protection.txt"
    
    # アクティブリポジトリリストに追加
    echo "$repo_name" >> "data/repositories/active.txt"
    
    log "  Issue #$issue_number の情報をレジストリに記録しました"
    return 0
}

# 重複除去
cleanup_duplicates() {
    log "重複除去を実行中..."
    
    # 各ファイルの重複を除去
    find data/students -name "*.txt" -type f | while read -r file; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            sort -u "$file" -o "$file"
        fi
    done
    
    # protection-statusファイルの重複除去
    for file in data/protection-status/*.txt; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            sort -u "$file" -o "$file"
        fi
    done
    
    # repositoriesファイルの重複除去
    for file in data/repositories/*.txt; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            sort -u "$file" -o "$file"
        fi
    done
    
    log "重複除去完了"
}

# 統計情報を表示
show_statistics() {
    log "=== 学生レジストリ統計 ==="
    
    # 年度別統計
    if [ -d "data/students" ]; then
        for year_dir in data/students/*/; do
            if [ -d "$year_dir" ]; then
                local year=$(basename "$year_dir")
                if [[ "$year" =~ ^[0-9]{4}$ ]]; then
                    local undergrad_count=0
                    local grad_count=0
                    
                    [ -f "$year_dir/undergraduate.txt" ] && undergrad_count=$(wc -l < "$year_dir/undergraduate.txt" 2>/dev/null || echo 0)
                    [ -f "$year_dir/graduate.txt" ] && grad_count=$(wc -l < "$year_dir/graduate.txt" 2>/dev/null || echo 0)
                    
                    if [ "$undergrad_count" -gt 0 ] || [ "$grad_count" -gt 0 ]; then
                        log "$year年度: 学部生 $undergrad_count名, 大学院生 $grad_count名"
                    fi
                fi
            fi
        done
    fi
    
    # 保護設定統計
    local pending=$(wc -l < data/protection-status/pending-protection.txt 2>/dev/null || echo 0)
    local completed=$(wc -l < data/protection-status/completed-protection.txt 2>/dev/null || echo 0)
    local failed=$(wc -l < data/protection-status/failed-protection.txt 2>/dev/null || echo 0)
    
    log "ブランチ保護設定: 待ち ${pending}件, 完了 ${completed}件, 失敗 ${failed}件"
    
    # アクティブリポジトリ統計
    local active=$(wc -l < data/repositories/active.txt 2>/dev/null || echo 0)
    log "アクティブリポジトリ: ${active}件"
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