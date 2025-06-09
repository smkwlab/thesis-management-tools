#!/bin/bash
# 論文リポジトリ作成ワンライナー
# 使用例: curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh | bash -s k21rs001

set -e

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

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

# 一時ディレクトリでリポジトリをクローン
TEMP_DIR=$(mktemp -d)
ORIGINAL_DIR=$(pwd)
echo "📥 リポジトリを取得中..."

if ! git clone https://github.com/smkwlab/thesis-management-tools.git "$TEMP_DIR" 2>/dev/null; then
    echo "❌ リポジトリのクローンに失敗しました"
    exit 1
fi

cd "$TEMP_DIR"

# ブランチ指定がある場合は切り替え
BRANCH="${THESIS_BRANCH:-feature/docker-oneliner-setup}"
if ! git checkout "$BRANCH" 2>/dev/null; then
    echo "⚠️ ブランチ $BRANCH が見つかりません。mainブランチを使用します。"
    git checkout main 2>/dev/null || true
fi

cd student-setup

echo "🔨 Dockerイメージをビルド中..."
if ! docker build -t thesis-setup-temp . 2>/dev/null; then
    echo "❌ Dockerイメージのビルドに失敗しました"
    echo "詳細:"
    docker build -t thesis-setup-temp .
    exit 1
fi

echo "🚀 セットアップ実行中..."

# 元のディレクトリに戻って実行
cd "$ORIGINAL_DIR"

# Docker実行（TTY対応）
if [ -n "$STUDENT_ID" ]; then
    docker run --rm -it thesis-setup-temp "$STUDENT_ID"
else
    docker run --rm -it thesis-setup-temp
fi

# クリーンアップ
echo "🧹 クリーンアップ中..."
rm -rf "$TEMP_DIR"
docker rmi thesis-setup-temp 2>/dev/null || true

echo "🎉 セットアップ完了！"