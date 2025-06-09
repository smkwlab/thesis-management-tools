#!/bin/bash
# 論文リポジトリ作成ワンライナー
# 使用例: curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh | bash -s k21rs001

set -e

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

echo "🎓 論文リポジトリ セットアップ"
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

# Docker実行前にブラウザを開く準備
echo ""
echo "🌐 GitHub認証ページを開いています..."

# デバッグ情報
echo "デバッグ: OSTYPE=$OSTYPE, PATH=$PATH"
echo "デバッグ: which open=$(which open 2>/dev/null || echo 'not found')"
echo "デバッグ: /usr/bin/open exists=$([[ -x /usr/bin/open ]] && echo 'yes' || echo 'no')"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - 絶対パスで実行
    echo "macOSでブラウザを開いています..."
    if /usr/bin/open "https://github.com/login/device" 2>/dev/null; then
        echo "✅ ブラウザを開きました"
    else
        echo "❌ ブラウザ起動に失敗しました。手動で https://github.com/login/device を開いてください"
    fi
elif command -v cmd.exe &> /dev/null; then
    # WSL
    echo "WSLでブラウザを開いています..."
    cmd.exe /c start "https://github.com/login/device" && echo "✅ ブラウザを開きました" || echo "❌ ブラウザ起動に失敗"
elif command -v wslview &> /dev/null; then
    # WSL2 with wslu
    echo "WSL2でブラウザを開いています..."
    wslview "https://github.com/login/device" && echo "✅ ブラウザを開きました" || echo "❌ ブラウザ起動に失敗"
elif command -v xdg-open &> /dev/null; then
    # Linux
    echo "Linuxでブラウザを開いています..."
    xdg-open "https://github.com/login/device" && echo "✅ ブラウザを開きました" || echo "❌ ブラウザ起動に失敗"
else
    echo "⚠️ ブラウザを自動で開けませんでした。手動で https://github.com/login/device を開いてください"
fi

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
