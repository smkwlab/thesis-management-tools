#!/bin/bash
#
# Test Issue Auto-Close Function
# Issue #35の最適化確認用テストスクリプト
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Issue自動クローズ機能最適化テスト ===${NC}"
echo

# 関数をsource
source "$SCRIPT_DIR/scripts/setup-branch-protection.sh"

# テスト1: デバッグ情報出力確認
echo -e "${YELLOW}Test 1: デバッグ情報出力確認${NC}"
echo "DEBUG=1 で実行します..."
DEBUG=1 close_related_issue "k99rs999-sotsuron"
echo

# テスト2: APIレート制限チェック
echo -e "${YELLOW}Test 2: APIレート制限チェック${NC}"
check_rate_limit
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ APIレート制限は問題ありません${NC}"
else
    echo -e "${RED}✗ APIレート制限に接近しています${NC}"
fi
echo

# テスト3: 冪等性確認（既存の保護設定があるリポジトリ）
echo -e "${YELLOW}Test 3: 冪等性確認${NC}"
echo "既に保護設定がある場合の動作確認..."
# 実際のテストリポジトリがある場合はここで実行
echo

echo -e "${BLUE}=== テスト完了 ===${NC}"