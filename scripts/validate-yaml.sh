#!/bin/bash

# validate-yaml.sh
# YAML workflow validation script

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# ツールの存在確認
check_tools() {
    local missing_tools=0
    
    if ! command -v yamllint >/dev/null 2>&1; then
        error "yamllint not found. Install with: pip install yamllint"
        missing_tools=$((missing_tools + 1))
    fi
    
    if ! command -v actionlint >/dev/null 2>&1; then
        error "actionlint not found. Install with: brew install actionlint"
        missing_tools=$((missing_tools + 1))
    fi
    
    if [ $missing_tools -gt 0 ]; then
        error "$missing_tools tools are missing. Please install them first."
        return 1
    fi
    
    success "All required tools are available"
}

# yamllint実行
run_yamllint() {
    log "Running yamllint validation..."
    
    if yamllint -c .yamllint.yml . 2>&1; then
        success "yamllint validation passed"
        return 0
    else
        error "yamllint validation failed"
        return 1
    fi
}

# actionlint実行
run_actionlint() {
    log "Running actionlint validation..."
    
    if actionlint -config-file .actionlint.yml 2>&1; then
        success "actionlint validation passed"
        return 0
    else
        error "actionlint validation failed"
        return 1
    fi
}

# 対象ファイル一覧表示
show_target_files() {
    info "Target YAML files:"
    find . -name "*.yml" -o -name "*.yaml" | grep -v node_modules | while read -r file; do
        echo "  - $file"
    done
}

# メイン処理
main() {
    log "YAML Workflow Validation Script"
    echo
    
    # 対象ファイル表示
    show_target_files
    echo
    
    # ツール確認
    if ! check_tools; then
        exit 1
    fi
    echo
    
    local errors=0
    
    # yamllint実行
    if ! run_yamllint; then
        errors=$((errors + 1))
    fi
    echo
    
    # actionlint実行
    if ! run_actionlint; then
        errors=$((errors + 1))
    fi
    echo
    
    # 結果表示
    if [ $errors -eq 0 ]; then
        success "🎉 All YAML validation checks passed!"
        exit 0
    else
        error "❌ $errors validation check(s) failed"
        exit 1
    fi
}

# スクリプトが直接実行された場合のみメイン処理を実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi