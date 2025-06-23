#!/bin/bash

# sync-students-from-repos.sh
# GitHubリポジトリから学生情報を同期して学年別リストを更新

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# リポジトリから学生情報を解析
parse_student_from_repo() {
    local repo_name="$1"
    local created_at="$2"
    
    # 学生IDを抽出
    local student_id=$(echo "$repo_name" | grep -oE '^k[0-9]{2}[rg][sjk][0-9]+' || echo "")
    
    if [ -z "$student_id" ]; then
        return 1
    fi
    
    # 学生タイプを判定
    local type=""
    if echo "$student_id" | grep -q 'rs'; then
        type="undergraduate"
    elif echo "$student_id" | grep -q 'gjk'; then
        type="graduate"
    else
        return 1
    fi
    
    # 作成年度を抽出
    local year=""
    if [[ "$created_at" =~ ^([0-9]{4})-[0-9]{2}-[0-9]{2}T ]]; then
        year="${BASH_REMATCH[1]}"
    else
        year=$(date +%Y)
    fi
    
    echo "$student_id $type $year"
}

# メイン処理
main() {
    log "GitHubリポジトリから学生情報を同期中..."
    
    # 一時ファイルの準備
    local temp_all_students=$(mktemp)
    local temp_active_repos=$(mktemp)
    
    # クリーンアップ
    trap "rm -f $temp_all_students $temp_active_repos" EXIT
    
    # すべての学生リポジトリを取得
    log "学生リポジトリ情報を取得中..."
    gh repo list smkwlab --limit 1000 --json name,createdAt,isArchived | \
        jq -r '.[] | select(.name | test("^k[0-9]{2}[rg][sjk][0-9]+-(sotsuron|thesis)$")) | "\(.name) \(.createdAt) \(.isArchived)"' | \
        sort > "$temp_all_students"
    
    local total_count=$(wc -l < "$temp_all_students")
    log "見つかったリポジトリ数: $total_count"
    
    # 学年別カウンター
    declare -A year_counts
    declare -A type_counts
    
    # 学生情報を処理
    while IFS=' ' read -r repo_name created_at is_archived; do
        if [ -z "$repo_name" ]; then
            continue
        fi
        
        # アーカイブされていないリポジトリのみアクティブリストに追加
        if [ "$is_archived" = "false" ]; then
            echo "$repo_name" >> "$temp_active_repos"
        fi
        
        # 学生情報を解析
        local parse_result
        if parse_result=$(parse_student_from_repo "$repo_name" "$created_at"); then
            local student_id=$(echo "$parse_result" | cut -d' ' -f1)
            local type=$(echo "$parse_result" | cut -d' ' -f2)
            local year=$(echo "$parse_result" | cut -d' ' -f3)
            
            # 年度ディレクトリを作成
            mkdir -p "data/students/$year"
            
            # 学生IDを年度別ファイルに追加（重複なし）
            local year_file="data/students/$year/$type.txt"
            if ! grep -q "^$student_id$" "$year_file" 2>/dev/null; then
                echo "$student_id" >> "$year_file"
                ((year_counts[$year]++))
                ((type_counts[$type]++))
            fi
        fi
    done < "$temp_all_students"
    
    # すべての学年ファイルをソート
    log "学生リストをソート中..."
    find data/students -name "*.txt" -type f | while read -r file; do
        if [ -s "$file" ]; then
            sort -u "$file" -o "$file"
        fi
    done
    
    # アクティブリポジトリリストを更新
    if [ -s "$temp_active_repos" ]; then
        sort -u "$temp_active_repos" > "data/repositories/active.txt"
        log "アクティブリポジトリリストを更新しました"
    fi
    
    # 統計情報を表示
    log "同期完了！"
    info "=== 統計情報 ==="
    
    # 年度別統計
    for year in $(find data/students -mindepth 1 -maxdepth 1 -type d -name "[0-9]*" | sort); do
        year_name=$(basename "$year")
        local undergrad_count=$(wc -l < "$year/undergraduate.txt" 2>/dev/null || echo 0)
        local grad_count=$(wc -l < "$year/graduate.txt" 2>/dev/null || echo 0)
        info "${year_name}年度: 学部生 ${undergrad_count}名, 大学院生 ${grad_count}名"
    done
    
    # 総計
    local total_undergrad=$(find data/students -name "undergraduate.txt" -exec cat {} \; | sort -u | wc -l)
    local total_grad=$(find data/students -name "graduate.txt" -exec cat {} \; | sort -u | wc -l)
    info "総計: 学部生 ${total_undergrad}名, 大学院生 ${total_grad}名"
}

# エントリーポイント
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi