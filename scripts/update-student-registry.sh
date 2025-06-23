#!/bin/bash

# update-student-registry.sh  
# 学生レジストリの更新と保守

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
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# レジストリの整合性チェック
validate_registry() {
    log "レジストリの整合性チェックを実行中..."
    
    local errors=0
    
    # 必要なディレクトリの存在確認
    for dir in "data/students" "data/protection-status" "data/repositories"; do
        if [ ! -d "$dir" ]; then
            error "必要なディレクトリが存在しません: $dir"
            errors=$((errors + 1))
        fi
    done
    
    # 年度ディレクトリの検証
    if [ -d "data/students" ]; then
        find data/students -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]" | while read -r year_dir; do
            local year=$(basename "$year_dir")
            
            # 学生IDフォーマットの検証（年度は関係なし）
            for type in "undergraduate" "graduate"; do
                local file="$year_dir/$type.txt"
                if [ -f "$file" ]; then
                    local invalid_ids=0
                    while read -r student_id; do
                        if [ -n "$student_id" ]; then
                            # 年度に関係なく、学生IDの形式のみを検証
                            if [[ "$type" == "undergraduate" ]]; then
                                if ! echo "$student_id" | grep -qE "^k[0-9]{2}(rs|jk)[0-9]{3}$"; then
                                    warn "不正な学部生ID形式: $student_id (expected: k??rs???)"
                                    invalid_ids=$((invalid_ids + 1))
                                fi
                            elif [[ "$type" == "graduate" ]]; then
                                if ! echo "$student_id" | grep -qE "^k[0-9]{2}gjk[0-9]{2}$"; then
                                    warn "不正な大学院生ID形式: $student_id (expected: k??gjk??)"
                                    invalid_ids=$((invalid_ids + 1))
                                fi
                            fi
                        fi
                    done < "$file"
                    
                    if [ "$invalid_ids" -gt 0 ]; then
                        warn "$file に不正なIDが ${invalid_ids}件 含まれています"
                    fi
                fi
            done
        done
    fi
    
    if [ "$errors" -eq 0 ]; then
        log "レジストリの整合性チェック完了: 問題なし"
    else
        error "レジストリに $errors 件のエラーが発見されました"
        return 1
    fi
}

# 孤立したエントリのクリーンアップ
cleanup_orphaned_entries() {
    log "孤立したエントリのクリーンアップを実行中..."
    
    local cleaned=0
    
    # pending-protection.txt の各エントリが有効なリポジトリかチェック
    if [ -f "data/protection-status/pending-protection.txt" ]; then
        local temp_file=$(mktemp)
        while read -r repo_name; do
            if [ -n "$repo_name" ]; then
                # リポジトリの存在確認
                if gh repo view "smkwlab/$repo_name" >/dev/null 2>&1; then
                    echo "$repo_name" >> "$temp_file"
                else
                    warn "存在しないリポジトリを pending から削除: $repo_name"
                    cleaned=$((cleaned + 1))
                fi
            fi
        done < "data/protection-status/pending-protection.txt"
        
        if [ -f "$temp_file" ]; then
            mv "$temp_file" "data/protection-status/pending-protection.txt"
        else
            > "data/protection-status/pending-protection.txt"
        fi
    fi
    
    log "孤立エントリのクリーンアップ完了: ${cleaned}件削除"
}

# リポジトリ状態の同期
sync_repository_status() {
    log "リポジトリ状態の同期を実行中..."
    
    # アクティブリポジトリリストの更新
    if [ -f "data/repositories/active.txt" ]; then
        local temp_active=$(mktemp)
        local active_count=0
        local archived_count=0
        
        while read -r repo_name; do
            if [ -n "$repo_name" ]; then
                # リポジトリの状態確認
                local repo_status=$(gh repo view "smkwlab/$repo_name" --json isArchived --jq '.isArchived' 2>/dev/null || echo "null")
                
                if [ "$repo_status" = "true" ]; then
                    # アーカイブ済みリポジトリをarchivedリストに移動
                    echo "$repo_name" >> "data/repositories/archived.txt"
                    archived_count=$((archived_count + 1))
                elif [ "$repo_status" = "false" ]; then
                    # アクティブリポジトリを維持
                    echo "$repo_name" >> "$temp_active"
                    active_count=$((active_count + 1))
                else
                    warn "リポジトリ状態を確認できません: $repo_name"
                fi
            fi
        done < "data/repositories/active.txt"
        
        mv "$temp_active" "data/repositories/active.txt"
        
        # archived.txtの重複除去
        if [ -f "data/repositories/archived.txt" ]; then
            sort -u "data/repositories/archived.txt" -o "data/repositories/archived.txt"
        fi
        
        log "リポジトリ状態同期完了: アクティブ ${active_count}件, アーカイブ ${archived_count}件"
    fi
}

# 統計レポートの生成
generate_statistics_report() {
    local report_file="data/statistics-report.txt"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S JST')
    
    log "統計レポートを生成中..."
    
    cat > "$report_file" << EOF
# 学生リポジトリ管理統計レポート
# 生成日時: $timestamp

## 年度別学生数
EOF
    
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
                        local total=$((undergrad_count + grad_count))
                        echo "$year年度: 学部生 ${undergrad_count}名, 大学院生 ${grad_count}名 (計 ${total}名)" >> "$report_file"
                    fi
                fi
            fi
        done
    fi
    
    # ブランチ保護設定統計
    cat >> "$report_file" << EOF

## ブランチ保護設定状況
EOF
    
    local pending=$(wc -l < data/protection-status/pending-protection.txt 2>/dev/null || echo 0)
    local completed=$(wc -l < data/protection-status/completed-protection.txt 2>/dev/null || echo 0)
    local failed=$(wc -l < data/protection-status/failed-protection.txt 2>/dev/null || echo 0)
    local total=$((pending + completed + failed))
    
    echo "待機中: ${pending}件" >> "$report_file"
    echo "完了: ${completed}件" >> "$report_file"
    echo "失敗: ${failed}件" >> "$report_file"
    echo "合計: ${total}件" >> "$report_file"
    
    # リポジトリ統計
    cat >> "$report_file" << EOF

## リポジトリ状況
EOF
    
    local active=$(wc -l < data/repositories/active.txt 2>/dev/null || echo 0)
    local archived=$(wc -l < data/repositories/archived.txt 2>/dev/null || echo 0)
    local total_repos=$((active + archived))
    
    echo "アクティブ: ${active}件" >> "$report_file"
    echo "アーカイブ済み: ${archived}件" >> "$report_file"
    echo "合計: ${total_repos}件" >> "$report_file"
    
    log "統計レポートを生成しました: $report_file"
}

# バックアップの作成
create_backup() {
    local backup_dir="data/backups/$(date +%Y%m%d_%H%M%S)"
    
    log "レジストリのバックアップを作成中..."
    
    mkdir -p "$backup_dir"
    
    # データディレクトリをバックアップ
    cp -r data/students "$backup_dir/" 2>/dev/null || true
    cp -r data/protection-status "$backup_dir/" 2>/dev/null || true
    cp -r data/repositories "$backup_dir/" 2>/dev/null || true
    
    log "バックアップを作成しました: $backup_dir"
    
    # 古いバックアップを削除（30日以上前）
    find data/backups -type d -name "*_*" -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
}

# メイン処理
main() {
    local skip_validation=false
    local skip_cleanup=false
    local skip_sync=false
    
    # オプション解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --skip-cleanup)
                skip_cleanup=true
                shift
                ;;
            --skip-sync)
                skip_sync=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--skip-validation] [--skip-cleanup] [--skip-sync]"
                echo ""
                echo "Options:"
                echo "  --skip-validation  Skip registry validation"
                echo "  --skip-cleanup     Skip orphaned entry cleanup"
                echo "  --skip-sync        Skip repository status sync"
                echo "  --help             Show this help message"
                exit 0
                ;;
            *)
                warn "不明なオプション: $1"
                shift
                ;;
        esac
    done
    
    log "学生レジストリ更新処理を開始します"
    
    # GitHub CLIの認証確認
    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI認証が必要です"
        exit 1
    fi
    
    # バックアップ作成
    create_backup
    
    # 各処理を実行
    [ "$skip_validation" = false ] && validate_registry
    [ "$skip_cleanup" = false ] && cleanup_orphaned_entries
    [ "$skip_sync" = false ] && sync_repository_status
    
    # 統計レポート生成
    generate_statistics_report
    
    log "学生レジストリ更新処理が完了しました"
}

# スクリプトが直接実行された場合のみメイン処理を実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi