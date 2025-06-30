#!/bin/bash
# ISEレポートリポジトリセットアップスクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BRIGHT_WHITE='\033[1;37m'
NC='\033[0m'

echo "📝 情報科学演習レポートリポジトリセットアップツール"
echo "=============================================="

# GitHub認証
echo "GitHub認証を確認中..."

# セキュアファイルからトークンを読み取り（フォールバック：環境変数）
if [ -f "/tmp/gh_token" ]; then
    echo -e "${GREEN}✓ ホストからセキュアトークンを取得しました${NC}"
    export GH_TOKEN=$(cat /tmp/gh_token)
    
    # トークンの有効性を確認
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓ GitHub認証済み（セキュアファイル認証）${NC}"
    else
        echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
        exit 1
    fi
elif [ -n "$GH_TOKEN" ]; then
    echo -e "${GREEN}✓ ホストから認証トークンを取得しました（環境変数）${NC}"
    export GH_TOKEN
    
    # トークンの有効性を確認
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓ GitHub認証済み（トークン認証）${NC}"
    else
        echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
        exit 1
    fi
elif ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}GitHub認証が必要です${NC}"
    echo ""
    echo "=== ブラウザ認証手順 ==="
    echo "1. ブラウザで https://github.com/login/device が開いているはずです"
    echo -e "2. ${GREEN}Continue${NC} ボタンをクリック"
    echo -e "3. 下から2行目の以下のような行の ${YELLOW}XXXX-XXXX${NC} をコピーしてブラウザに入力:"
    echo -e "   ${YELLOW}!${NC} First copy your one-time code: ${BRIGHT_WHITE}XXXX-XXXX${NC}"
    echo -e "4. ${GREEN}Authorize github${NC} ボタンをクリックする"
    echo ""

    if echo -e "Y\\n" | gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --scopes "repo,workflow,read:org,gist"; then
        echo -e "${GREEN}✓ GitHub認証完了${NC}"
    else
        echo -e "${RED}エラー: GitHub認証に失敗しました${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ GitHub認証済み${NC}"
fi

# 動作モードの判定（setup-ise.shから渡された環境変数）
USER_TYPE="${USER_TYPE:-organization_member}"
INDIVIDUAL_MODE=false

if [ "$USER_TYPE" = "individual_user" ]; then
    INDIVIDUAL_MODE=true
    echo -e "${BLUE}👤 個人ユーザーモード有効${NC}"
    echo -e "${BLUE}   - ISEレポートは組織での作成を推奨${NC}"
else
    echo -e "${GREEN}🏢 組織ユーザーモード${NC}"
    echo -e "${GREEN}   - Pull Request学習環境を設定${NC}"
fi

# 組織/ユーザーの設定
if [ -n "$TARGET_ORG" ]; then
    # 環境変数で明示的に指定された場合
    ORGANIZATION="$TARGET_ORG"
    echo -e "${GREEN}✓ 指定された組織: $ORGANIZATION${NC}"
elif [ -n "$GITHUB_REPOSITORY" ]; then
    # GitHub Actions等で実行されている場合、リポジトリから組織を取得
    ORGANIZATION=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
    echo -e "${GREEN}✓ 自動検出された組織: $ORGANIZATION${NC}"
else
    # デフォルトは smkwlab
    ORGANIZATION="smkwlab"
    echo -e "${YELLOW}✓ デフォルト組織を使用: $ORGANIZATION${NC}"
fi

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/ise-report-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力または引数から取得
if [ -n "$1" ]; then
    STUDENT_ID="$1"
else
    echo ""
    echo "学籍番号を入力してください"
    echo "  例: k21rs001, k21gjk01"
    echo ""
    read -p "学籍番号: " STUDENT_ID
fi

# 学籍番号の正規化（小文字化）
STUDENT_ID=$(echo "$STUDENT_ID" | tr '[:upper:]' '[:lower:]')

# 学籍番号の検証
if [ -z "$STUDENT_ID" ]; then
    echo -e "${RED}エラー: 学籍番号が指定されていません${NC}"
    exit 1
fi

# 学籍番号形式の検証
if ! echo "$STUDENT_ID" | grep -qE '^k[0-9]{2}(rs|jk|gjk)[0-9]+$'; then
    echo -e "${RED}❌ 学籍番号の形式が正しくありません: $STUDENT_ID${NC}"
    echo "   正しい形式: k21rs001, k22gjk01 など"
    exit 1
fi

echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# ISE レポート番号の決定とリポジトリ存在チェック
determine_ise_report_number() {
    local student_id="$1"
    local report_num=1
    
    # 1回目のリポジトリが存在するかチェック
    if gh repo view "${ORGANIZATION}/${student_id}-ise-report1" >/dev/null 2>&1; then
        report_num=2
        
        # 2回目のリポジトリが存在するかチェック
        if gh repo view "${ORGANIZATION}/${student_id}-ise-report2" >/dev/null 2>&1; then
            echo -e "${RED}❌ 情報科学演習レポートは最大2つまでです${NC}" >&2
            echo "   前期用: https://github.com/${ORGANIZATION}/${student_id}-ise-report1" >&2
            echo "   後期用: https://github.com/${ORGANIZATION}/${student_id}-ise-report2" >&2
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
    echo -e "${RED}❌ リポジトリ ${ORGANIZATION}/${REPO_NAME} は既に存在します${NC}"
    echo "   https://github.com/${ORGANIZATION}/${REPO_NAME}"
    exit 1
fi

# 現在のユーザーアカウントを取得
if ! CURRENT_USER=$(gh api user --jq .login 2>/dev/null); then
    echo -e "${RED}❌ GitHub APIアクセスに失敗しました${NC}"
    echo "認証トークンを更新してください："
    echo "  gh auth refresh"
    exit 1
fi

# 組織へのアクセス権限確認
echo "🏢 組織アクセス権限を確認中..."
if ! gh api "orgs/${ORGANIZATION}/members/${CURRENT_USER}" >/dev/null 2>&1; then
    echo -e "${RED}❌ ${ORGANIZATION} 組織のメンバーではありません${NC}"
    echo ""
    echo "以下を確認してください："
    echo "  1. GitHub 組織への招待メールを確認"
    echo "  2. 組織のメンバーシップが有効化されているか確認"
    echo "  3. 正しいGitHubアカウントでログインしているか確認"
    echo ""
    echo "招待が届いていない場合は、担当教員にお問い合わせください。"
    exit 1
fi

echo -e "${GREEN}✅ ${ORGANIZATION} 組織のメンバーシップ確認済み${NC}"

echo ""
echo -e "${BRIGHT_WHITE}🎯 作成予定リポジトリ: ${ORGANIZATION}/${REPO_NAME}${NC}"
echo ""
read -p "続行しますか? [Y/n]: " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo -e "${YELLOW}キャンセルしました${NC}"
    exit 0
fi

# リポジトリ作成
echo ""
echo "📁 リポジトリを作成中..."

echo "📋 ISEレポートリポジトリ作成開始..."
echo "   学籍番号: $STUDENT_ID"
echo "   リポジトリ名: $REPO_NAME"
echo "   レポート番号: $ISE_REPORT_NUM"

# テンプレートからリポジトリ作成
echo "🔄 テンプレートからリポジトリを作成中..."
if gh repo create "$ORGANIZATION/$REPO_NAME" \
    --template "$TEMPLATE_REPOSITORY" \
    --private \
    --description "Information Science Exercise Report #$ISE_REPORT_NUM for $STUDENT_ID - Pull Request Learning"; then
    echo -e "${GREEN}✅ リポジトリ作成完了: https://github.com/$ORGANIZATION/$REPO_NAME${NC}"
else
    echo -e "${RED}エラー: リポジトリの作成に失敗しました${NC}"
    echo "- 既に同名のリポジトリが存在する可能性があります"
    echo "- 組織への権限が不足している可能性があります"
    exit 1
fi

# GitHub CLIの認証情報をgitに設定
echo "Git認証を設定中..."
if ! gh auth setup-git; then
    echo -e "${RED}✗ Git認証設定に失敗しました${NC}"
    echo -e "${RED}GitHub CLIの認証が正しく設定されているか確認してください${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git認証設定完了${NC}"

# Gitユーザー設定（Docker環境用）
git config user.email "setup-ise@smkwlab.github.io"
git config user.name "ISE Setup Tool"

# リポジトリをクローン
git clone "https://github.com/$ORGANIZATION/$REPO_NAME.git"
cd "$REPO_NAME"

echo "🌿 Pull Request学習用ブランチ構成を作成中..."

# review-branch の作成（sotsuron-template風）
git checkout -b review-branch
cat > REVIEW_BRANCH.md << 'EOF'
## Review Branch

このブランチは添削・レビュー用のベースブランチです。

### Pull Request学習の流れ
1. 作業用ブランチ（0th-draft, 1st-draft等）を作成
2. index.html を編集してレポート作成  
3. Pull Request を作成
4. レビューフィードバックを確認・対応
5. 必要に応じて新しいドラフトブランチで再提出

詳細は [README.md](README.md) をご参照ください。
EOF

git add REVIEW_BRANCH.md
git commit -m "Add review branch explanation for ISE learning"
git push origin review-branch

# 初期提出用ブランチ（0th-draft）の作成
# テンプレートが空の場合、mainブランチが存在しないのでreview-branchから作成
git checkout review-branch
git checkout -b 0th-draft

# ISE用のindex.htmlテンプレート更新
cat > index.html << 'EOF'
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

echo -e "${GREEN}📝 ISE学習用初期コンテンツ作成完了${NC}"

# ALDC (Add LaTeX DevContainer) の実行
echo "🔧 DevContainer環境をセットアップ中..."
if command -v npm >/dev/null 2>&1; then
    # ALDCパッケージの存在確認
    if npm view @smkwlab/aldc@latest >/dev/null 2>&1; then
        npm install -g @smkwlab/aldc@latest
        
        # ISE用のDevContainer設定
        echo "ISE用のDevContainer設定を適用中..."
        aldc --html || echo "⚠️ ALDC実行をスキップします"
    else
        echo "ℹ️ ALDCパッケージが利用できないため、スキップします"
    fi
else
    echo "⚠️ npmが利用できないため、ALDCをスキップします"
fi

# mainブランチを作成・設定
git checkout review-branch
git checkout -b main
git push origin main

# GitHubでデフォルトブランチをmainに設定
gh repo edit "$ORGANIZATION/$REPO_NAME" --default-branch main

echo -e "${GREEN}🎯 Pull Request学習用リポジトリ作成完了!${NC}"

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

# 完了メッセージ
echo ""
echo "=============================================="
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "リポジトリ: https://github.com/${ORGANIZATION}/${REPO_NAME}"
echo "ローカル: ./${REPO_NAME}"
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
echo "📖 詳細な手順: リポジトリの README.md をご確認ください"
echo "=============================================="