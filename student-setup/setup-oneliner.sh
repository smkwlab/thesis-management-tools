#!/bin/bash
# 論文リポジトリ作成ワンライナー
# 使用例: curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh | bash -s k21rs001

set -e

STUDENT_ID="$1"

echo "🎓 論文リポジトリ ワンライナーセットアップ"
echo "=============================================="

# Docker の確認
if ! command -v docker &> /dev/null; then
    echo "❌ Docker が見つかりません"
    echo "Docker Desktop をインストールしてください："
    echo "  Windows: https://docs.docker.com/desktop/windows/"
    echo "  macOS: https://docs.docker.com/desktop/mac/"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker が起動していません"
    echo "Docker Desktop を起動してください"
    exit 1
fi

echo "✅ Docker 確認完了"

# GitHub から直接ビルド & 実行
echo "🔧 セットアップ開始..."

if [ -n "$STUDENT_ID" ]; then
    docker run --rm -it \
        -v "$(pwd):/output" \
        $(docker build -q https://github.com/smkwlab/thesis-management-tools.git#main:student-setup) \
        "$STUDENT_ID"
else
    docker run --rm -it \
        -v "$(pwd):/output" \
        $(docker build -q https://github.com/smkwlab/thesis-management-tools.git#main:student-setup)
fi

echo "🎉 セットアップ完了！"