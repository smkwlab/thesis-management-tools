#!/bin/bash
# 週間報告リポジトリ作成スクリプト
# 使用例: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-wr.sh)"

set -e

# デバッグモード（環境変数 DEBUG=1 で有効化）
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "🔍 デバッグモード有効"
fi

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

# 一時ディレクトリ変数（グローバルスコープ）
TEMP_DIR=""

# クリーンアップ関数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "🧹 クリーンアップ中..."
        rm -rf "$TEMP_DIR"
    fi
    # Dockerイメージも削除
    docker rmi wr-setup-temp 2>/dev/null || true
}

# 終了時・エラー時・割り込み時にクリーンアップ
trap cleanup EXIT ERR INT TERM

echo "📝 週間報告リポジトリ セットアップ"
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
BRANCH="${WR_BRANCH:-main}"
if ! git checkout "$BRANCH" 2>/dev/null; then
    echo "⚠️ ブランチ $BRANCH が見つかりません。mainブランチを使用します。"
    git checkout main 2>/dev/null || true
fi

cd create-repo

echo "🔨 Dockerイメージをビルド中..."
if [ "${DEBUG:-0}" = "1" ]; then
    # デバッグモードでは出力を表示
    docker build -t wr-setup-temp .
else
    # 通常モードではエラー時のみ詳細表示
    if ! docker build -t wr-setup-temp . 2>/dev/null; then
        echo "❌ Dockerイメージのビルドに失敗しました"
        echo "詳細エラー情報:"
        docker build -t wr-setup-temp .
        exit 1
    fi
fi

echo "🚀 セットアップ実行中..."

# 元のディレクトリに戻って実行
cd "$ORIGINAL_DIR"

# ブラウザを開く
echo ""
echo "🌐 認証ページを開いています..."

BROWSER_OPENED=false

if [[ "$OSTYPE" == "darwin"* ]]; then
    if /usr/bin/open "https://github.com/login/device" 2>/dev/null; then
        BROWSER_OPENED=true
    fi
elif command -v cmd.exe &> /dev/null; then
    if cmd.exe /c start "https://github.com/login/device" 2>/dev/null; then
        BROWSER_OPENED=true
    fi
elif command -v wslview &> /dev/null; then
    if wslview "https://github.com/login/device" 2>/dev/null; then
        BROWSER_OPENED=true
    fi
elif command -v xdg-open &> /dev/null; then
    if xdg-open "https://github.com/login/device" 2>/dev/null; then
        BROWSER_OPENED=true
    fi
fi

if [ "$BROWSER_OPENED" = "false" ]; then
    echo ""
    echo "⚠️ ブラウザを自動で開けませんでした"
    echo "手動で以下のURLを開いてください："
    echo "https://github.com/login/device"
    echo ""
fi

# Docker実行（TTY対応）- 週報用のスクリプトを実行
if [ -n "$STUDENT_ID" ]; then
    docker run --rm -it wr-setup-temp bash main-wr.sh "$STUDENT_ID"
else
    docker run --rm -it wr-setup-temp bash main-wr.sh
fi

# 成功メッセージ（クリーンアップは trap で自動実行）
echo "🎉 セットアップ完了！"