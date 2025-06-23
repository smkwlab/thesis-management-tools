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
            ((processed++))
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
    
    # 年度ディレクトリを作成
    if ! mkdir -p "data/students/$year"; then
        error "年度ディレクトリ作成失敗: data/students/$year"
        return 1
    fi
    
    # 学生レジストリに追加
    if ! echo "$student_id" >> "data/students/$year/$type.txt"; then
        error "学生レジストリ書き込み失敗: data/students/$year/$type.txt"
        return 1
    fi
    
    # ブランチ保護待ちリストに追加
    if ! echo "$repo_name" >> "data/protection-status/pending-protection.txt"; then
        error "ブランチ保護リスト書き込み失敗: data/protection-status/pending-protection.txt"
        return 1
    fi
    
    # アクティブリポジトリリストに追加
    if ! echo "$repo_name" >> "data/repositories/active.txt"; then
        error "アクティブリポジトリリスト書き込み失敗: data/repositories/active.txt"
        return 1
    fi
    
    log "  Issue #$issue_number の情報をレジストリに記録しました"
    return 0
}

# 重複除去
cleanup_duplicates() {
    log "重複除去を実行中..."
    
    # 各ファイルの重複を除去
    while IFS= read -r -d '' file; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            if ! sort -u "$file" -o "$file"; then
                warn "重複除去失敗: $file"
            fi
        fi
    done < <(find data/students -name "*.txt" -type f -print0)
    
    # protection-statusファイルの重複除去
    for file in data/protection-status/*.txt; do
        if [ -f "$file" ] && [ -e "$file" ] && [ -s "$file" ]; then
            if ! sort -u "$file" -o "$file"; then
                warn "重複除去失敗: $file"
            fi
        fi
    done
    
    # repositoriesファイルの重複除去
    for file in data/repositories/*.txt; do
        if [ -f "$file" ] && [ -e "$file" ] && [ -s "$file" ]; then
            if ! sort -u "$file" -o "$file"; then
                warn "重複除去失敗: $file"
            fi
        fi
    done
    
    log "重複除去完了"
}

# 統計情報を表示
show_statistics() {
    log "=== 学生レジストリ統計 ==="
    
    # 年度別統計
    if [ -d "data/students" ]; then
        # 年度ディレクトリのみを対象とする（2020-2030年の範囲）
        for year in 2020 2021 2022 2023 2024 2025 2026 2027 2028 2029 2030; do
            local year_dir="data/students/$year"
            if [ -d "$year_dir" ]; then
                local undergrad_count=0
                local grad_count=0
                
                [ -f "$year_dir/undergraduate.txt" ] && undergrad_count=$(wc -l < "$year_dir/undergraduate.txt" 2>/dev/null || echo 0)
                [ -f "$year_dir/graduate.txt" ] && grad_count=$(wc -l < "$year_dir/graduate.txt" 2>/dev/null || echo 0)
                
                if [ "$undergrad_count" -gt 0 ] || [ "$grad_count" -gt 0 ]; then
                    log "${year}年度: 学部生 ${undergrad_count}名, 大学院生 ${grad_count}名"
                fi
            fi
        done
    fi
    
    # 保護設定統計
    local pending=0
    local completed=0
    local failed=0
    
    [ -f "data/protection-status/pending-protection.txt" ] && pending=$(wc -l < data/protection-status/pending-protection.txt 2>/dev/null || echo 0)
    [ -f "data/protection-status/completed-protection.txt" ] && completed=$(wc -l < data/protection-status/completed-protection.txt 2>/dev/null || echo 0)
    [ -f "data/protection-status/failed-protection.txt" ] && failed=$(wc -l < data/protection-status/failed-protection.txt 2>/dev/null || echo 0)
    
    log "ブランチ保護設定: 待ち ${pending}件, 完了 ${completed}件, 失敗 ${failed}件"
    
    # アクティブリポジトリ統計
    local active=0
    [ -f "data/repositories/active.txt" ] && active=$(wc -l < data/repositories/active.txt 2>/dev/null || echo 0)
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