#!/bin/bash

# test-extract-issues.sh
# extract-student-info-from-issues.sh のテスト用スクリプト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Testing extract-student-info-from-issues.sh..."
echo

# テスト実行
if [ -f "$SCRIPT_DIR/extract-student-info-from-issues.sh" ]; then
    echo "📊 実際のIssueから学生情報を抽出中..."
    "$SCRIPT_DIR/extract-student-info-from-issues.sh"
    
    echo
    echo "📁 生成されたファイル一覧:"
    find data -type f -name "*.txt" 2>/dev/null | sort || echo "データファイルが見つかりません"
    
    echo
    echo "📊 統計情報:"
    if [ -f "data/protection-status/pending-protection.txt" ]; then
        echo "  ブランチ保護待ち: $(wc -l < data/protection-status/pending-protection.txt) 件"
    fi
    
    if [ -f "data/repositories/active.txt" ]; then
        echo "  アクティブリポジトリ: $(wc -l < data/repositories/active.txt) 件"
    fi
    
    echo
    echo "📋 年度別学生数:"
    for year_dir in data/students/*/; do
        if [ -d "$year_dir" ]; then
            year=$(basename "$year_dir")
            if [[ "$year" =~ ^[0-9]{4}$ ]]; then
                undergrad=0
                grad=0
                [ -f "$year_dir/undergraduate.txt" ] && undergrad=$(wc -l < "$year_dir/undergraduate.txt" 2>/dev/null || echo 0)
                [ -f "$year_dir/graduate.txt" ] && grad=$(wc -l < "$year_dir/graduate.txt" 2>/dev/null || echo 0)
                if [ "$undergrad" -gt 0 ] || [ "$grad" -gt 0 ]; then
                    echo "  $year年度: 学部生 ${undergrad}名, 大学院生 ${grad}名"
                fi
            fi
        fi
    done
    
else
    echo "❌ extract-student-info-from-issues.sh が見つかりません"
    exit 1
fi

echo
echo "✅ テスト完了"