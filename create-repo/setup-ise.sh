#!/bin/bash
# 情報科学演習レポートリポジトリ作成スクリプト
# 使用例: STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-ise.sh)"

set -e

# デバッグモード（環境変数 DEBUG=1 で有効化）
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "🔍 デバッグモード有効"
fi

# 引数または環境変数から学籍番号を取得
STUDENT_ID="${1:-$STUDENT_ID}"

# 一時ディレクトリ・ファイル変数（グローバルスコープ）
TEMP_DIR=""
TOKEN_FILE=""

# クリーンアップ関数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "🧹 クリーンアップ中..."
        rm -rf "$TEMP_DIR"
    fi
    # セキュアなトークンファイルの削除
    if [ -n "$TOKEN_FILE" ] && [ -f "$TOKEN_FILE" ]; then
        rm -f "$TOKEN_FILE"
    fi
    # Dockerイメージも削除
    if docker images -q ise-setup-alpine >/dev/null 2>&1; then
        echo "🗑️  Dockerイメージをクリーンアップ中..."
        docker rmi ise-setup-alpine >/dev/null 2>&1 || true
    fi
}

# 終了時・中断時のクリーンアップ
trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

echo "==============================================="
echo "📝 情報科学演習レポートリポジトリ作成ツール"
echo "🐳 Dockerベース - Pull Request学習用"
echo "==============================================="

# Docker の確認
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Dockerがインストールされていません"
    echo "   https://docs.docker.com/get-docker/ からインストールしてください"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "❌ Dockerデーモンが起動していません"
    echo "   Dockerを起動してから再実行してください"
    exit 1
fi

# GitHub CLI の確認（ホスト側）
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) がインストールされていません"
    echo "   https://cli.github.com/ からインストールしてください"
    exit 1
fi

# GitHub 認証状況を確認
echo "🔐 GitHub 認証状況を確認中..."

if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI にログインしていません"
    echo ""
    echo "以下のコマンドでログインしてください："
    echo "  gh auth login"
    echo ""
    echo "💡 認証方法："
    echo "  - ブラウザ認証（推奨）: Enter → ワンタイムコードを入力"
    echo "  - Personal Access Token: トークンを直接入力"
    echo ""
    echo "🔧 トラブルシューティング："
    echo "  - エラー時: gh auth refresh"
    echo "  - 複数アカウント: gh auth switch --user USERNAME"
    echo ""
    exit 1
fi

# 現在のユーザーアカウントを取得
if ! CURRENT_USER=$(gh api user --jq .login 2>/dev/null); then
    echo "❌ GitHub APIアクセスに失敗しました"
    echo "認証トークンを更新してください："
    echo "  gh auth refresh"
    exit 1
fi

echo "✅ GitHub認証済み (ユーザー: $CURRENT_USER)"

# 学籍番号の検証
if [ -z "$STUDENT_ID" ]; then
    echo "❌ 学籍番号が指定されていません"
    echo ""
    echo "使用方法："
    echo "  STUDENT_ID=k21rs001 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-ise.sh)\""
    echo "  または"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-ise.sh)\" -- k21rs001"
    echo ""
    exit 1
fi

# 学籍番号形式の検証
if ! echo "$STUDENT_ID" | grep -qE '^k[0-9]{2}(rs|jk|gjk)[0-9]+$'; then
    echo "❌ 学籍番号の形式が正しくありません: $STUDENT_ID"
    echo "   正しい形式: k21rs001, k22gjk01 など"
    exit 1
fi

echo "✅ 学籍番号検証済み: $STUDENT_ID"

# ISE レポート番号の決定とリポジトリ存在チェック
ORGANIZATION="smkwlab"
determine_ise_report_number() {
    local student_id="$1"
    local report_num=1
    
    # 1回目のリポジトリが存在するかチェック
    if gh repo view "${ORGANIZATION}/${student_id}-ise-report1" >/dev/null 2>&1; then
        report_num=2
        
        # 2回目のリポジトリが存在するかチェック
        if gh repo view "${ORGANIZATION}/${student_id}-ise-report2" >/dev/null 2>&1; then
            echo "❌ 情報科学演習レポートは最大2つまでです" >&2
            echo "   既存リポジトリ:" >&2
            echo "   - https://github.com/${ORGANIZATION}/${student_id}-ise-report1" >&2
            echo "   - https://github.com/${ORGANIZATION}/${student_id}-ise-report2" >&2
            echo "" >&2
            echo "   新しいレポートが必要な場合は、既存のリポジトリを削除するか、" >&2
            echo "   担当教員にご相談ください。" >&2
            exit 1
        fi
    fi
    
    echo "$report_num"
}

# ISE レポート番号を決定
echo "📋 既存ISEレポートリポジトリの確認中..."
ISE_REPORT_NUM=$(determine_ise_report_number "$STUDENT_ID")
REPO_NAME="${STUDENT_ID}-ise-report${ISE_REPORT_NUM}"

if [ "$ISE_REPORT_NUM" = "1" ]; then
    echo "📝 作成対象: ${REPO_NAME} (初回のISEレポート)"
else
    echo "✅ ${STUDENT_ID}-ise-report1 が存在"
    echo "📝 作成対象: ${REPO_NAME} (2回目のISEレポート)"
fi

# リポジトリが既に存在しないことを最終確認
if gh repo view "${ORGANIZATION}/${REPO_NAME}" >/dev/null 2>&1; then
    echo "❌ リポジトリ ${ORGANIZATION}/${REPO_NAME} は既に存在します"
    echo "   https://github.com/${ORGANIZATION}/${REPO_NAME}"
    exit 1
fi

# 組織へのアクセス権限確認
echo "🏢 組織アクセス権限を確認中..."
if ! gh api "orgs/${ORGANIZATION}/members/${CURRENT_USER}" >/dev/null 2>&1; then
    echo "❌ ${ORGANIZATION} 組織のメンバーではありません"
    echo ""
    echo "以下を確認してください："
    echo "  1. GitHub 組織への招待メールを確認"
    echo "  2. 組織のメンバーシップが有効化されているか確認"
    echo "  3. 正しいGitHubアカウントでログインしているか確認"
    echo ""
    echo "招待が届いていない場合は、担当教員にお問い合わせください。"
    exit 1
fi

echo "✅ ${ORGANIZATION} 組織のメンバーシップ確認済み"

# セキュアな一時ディレクトリ作成
TEMP_DIR=$(mktemp -d)
chmod 700 "$TEMP_DIR"

# GitHub トークンを一時ファイルに保存（Dockerコンテナ内で使用）
TOKEN_FILE="$TEMP_DIR/github_token"
gh auth token > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo "🐳 Dockerコンテナでリポジトリ作成を実行中..."

# Docker コンテナ内でリポジトリ作成を実行
docker run --rm \
    -v "$TEMP_DIR:/workspace" \
    -e STUDENT_ID="$STUDENT_ID" \
    -e REPO_NAME="$REPO_NAME" \
    -e ISE_REPORT_NUM="$ISE_REPORT_NUM" \
    -e ORGANIZATION="$ORGANIZATION" \
    -e CURRENT_USER="$CURRENT_USER" \
    -e DEBUG="${DEBUG:-0}" \
    alpine:latest sh -c '
set -e

# Alpine Linuxの設定
apk add --no-cache git curl jq bash nodejs npm

# GitHub CLI のインストール
apk add --no-cache github-cli

# GitHub CLI 認証設定
export GITHUB_TOKEN=$(cat /workspace/github_token)

echo "📋 ISEレポートリポジトリ作成開始..."
echo "   学籍番号: $STUDENT_ID"
echo "   リポジトリ名: $REPO_NAME"
echo "   レポート番号: $ISE_REPORT_NUM"

# テンプレートからリポジトリ作成
echo "🔄 テンプレートからリポジトリを作成中..."
gh repo create "$ORGANIZATION/$REPO_NAME" \
    --template "$ORGANIZATION/ise-report-template" \
    --private \
    --description "Information Science Exercise Report #$ISE_REPORT_NUM for $STUDENT_ID - Pull Request Learning"

echo "✅ リポジトリ作成完了: https://github.com/$ORGANIZATION/$REPO_NAME"

# リポジトリをクローン
cd /workspace
git clone "https://oauth2:$GITHUB_TOKEN@github.com/$ORGANIZATION/$REPO_NAME.git"
cd "$REPO_NAME"

# Git 設定
git config user.name "$CURRENT_USER"
git config user.email "$CURRENT_USER@users.noreply.github.com"

echo "🌿 Pull Request学習用ブランチ構成を作成中..."

# review-branch の作成（sotsuron-template風）
git checkout -b review-branch
echo "## Review Branch

このブランチは添削・レビュー用のベースブランチです。

### Pull Request学習の流れ
1. 作業用ブランチ（0th-draft, 1st-draft等）を作成
2. index.html を編集してレポート作成  
3. Pull Request を作成
4. レビューフィードバックを確認・対応
5. 必要に応じて新しいドラフトブランチで再提出

詳細は [README.md](README.md) をご参照ください。
" > REVIEW_BRANCH.md
git add REVIEW_BRANCH.md
git commit -m "Add review branch explanation for ISE learning"
git push origin review-branch

# 初期提出用ブランチ（0th-draft）の作成
# テンプレートが空の場合、mainブランチが存在しないのでreview-branchから作成
git checkout review-branch
git checkout -b 0th-draft

# ISE用のindex.htmlテンプレート更新
cat > index.html << "EOF"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>情報科学演習レポート - STUDENT_ID</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header>
        <h1>情報科学演習レポート</h1>
        <p class="author">学籍番号: STUDENT_ID, 氏名: [あなたの名前]</p>
    </header>

    <main>
        <h2>はじめに</h2>
        <p>このレポートでは、情報科学演習で取り組んだ内容について報告する。</p>

        <h2>実施内容</h2>
        <p>ここに演習で実施した内容を記述してください。</p>

        <h3>プログラミング課題</h3>
        <p>プログラミング課題の取り組み内容を記述してください。</p>

        <h3>学習した技術・概念</h3>
        <p>演習を通じて学習した技術や概念について説明してください。</p>

        <h2>考察</h2>
        <p>演習を通じて学んだことや気づいた点について考察してください。</p>

        <h2>まとめ</h2>
        <p>演習全体を振り返り、まとめを記述してください。</p>
    </main>
</body>
</html>
EOF

# 学籍番号をテンプレートに反映
sed -i "s/STUDENT_ID/$STUDENT_ID/g" index.html

git add index.html
git commit -m "Initialize ISE report template for $STUDENT_ID"
git push origin 0th-draft

echo "📝 ISE学習用初期コンテンツ作成完了"

# ALDC (Add LaTeX DevContainer) の実行
echo "🔧 DevContainer環境をセットアップ中..."
if command -v npm >/dev/null 2>&1; then
    npm install -g @smkwlab/aldc@latest
    
    # ISE用のDevContainer設定
    echo "ISE用のDevContainer設定を適用中..."
    aldc --html || echo "⚠️  ALDC実行中にエラーが発生しましたが、継続します"
else
    echo "⚠️  npmが利用できないため、ALDCをスキップします"
fi

# mainブランチを作成・設定
git checkout review-branch
git checkout -b main
git push origin main

# GitHubでデフォルトブランチをmainに設定
gh repo edit "$ORGANIZATION/$REPO_NAME" --default-branch main

echo "🎯 Pull Request学習用リポジトリ作成完了!"
'

# Docker実行完了後のメッセージ
echo ""
echo "🎓 情報科学演習レポートリポジトリ作成完了！"
echo ""
echo "📝 Pull Request学習を開始してください："
echo "  1. GitHub Desktop または VS Code でリポジトリを開く"
echo "  2. 作業用ブランチ（1st-draft など）を作成"
echo "  3. index.html を編集してレポート作成"
echo "  4. 変更をコミット・プッシュ"
echo "  5. Pull Request を作成して提出"
echo "  6. レビューフィードバックを確認・対応"
echo ""
echo "🔗 作成されたリポジトリ:"
echo "   https://github.com/${ORGANIZATION}/${REPO_NAME}"
echo ""
echo "📖 詳細な手順: リポジトリの README.md をご確認ください"
echo ""

# 登録依頼 Issue の作成
echo "📋 リポジトリ登録依頼 Issue を作成中..."

ISSUE_BODY="## リポジトリ登録依頼

**リポジトリ**: \`${ORGANIZATION}/${REPO_NAME}\`
**学生**: ${STUDENT_ID}
**種別**: 情報科学演習レポート${ISE_REPORT_NUM}

### 確認事項
- [x] リポジトリが正常に作成された
- [x] Pull Request学習用ブランチ構成が設定された
- [x] 初期テンプレートが配置された
- [ ] ブランチ保護設定の実施
- [ ] 学生レジストリへの登録

### Pull Request学習の特徴
- **0th-draft**: 初期提出用ブランチ
- **review-branch**: レビューベースブランチ 
- **HTML + textlint**: 品質管理システム
- **DevContainer**: VS Code開発環境

### 次のステップ
1. ブランチ保護設定の実施
2. 学生への利用開始案内
3. レビューワークフローの確認

作成者: ${CURRENT_USER}
作成日時: $(date '+%Y-%m-%d %H:%M:%S')"

gh issue create \
    --repo "${ORGANIZATION}/thesis-management-tools" \
    --title "リポジトリ登録依頼: ${ORGANIZATION}/${REPO_NAME}" \
    --body "$ISSUE_BODY" \
    --label "ise-report,repository-registration" || echo "⚠️  Issue作成に失敗しましたが、リポジトリ作成は完了しています"

echo ""
echo "✅ すべての処理が完了しました！"
echo "   情報科学演習でのPull Request学習をお楽しみください。"