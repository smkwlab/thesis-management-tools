#!/bin/bash
# 情報科学演習レポートリポジトリセットアップスクリプト（超リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

echo "📝 情報科学演習レポートリポジトリセットアップツール"
echo "=============================================="

# GitHub認証（Docker内用）
check_github_auth_docker || exit 1

# 動作モードの判定
OPERATION_MODE=$(determine_operation_mode)
INDIVIDUAL_MODE=false
if [ "$OPERATION_MODE" = "individual" ]; then
    INDIVIDUAL_MODE=true
    echo -e "${BLUE}   - ISEレポートは組織での作成を推奨${NC}"
fi

# 組織設定（共通関数使用）
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/ise-report-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力（共通関数使用）
STUDENT_ID=$(read_student_id "$1")

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
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
            echo "削除が必要な場合は、担当教員にご相談ください。" >&2
            exit 1
        fi
    fi
    
    echo "$report_num"
}

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

# 組織へのアクセス権限確認（共通関数使用）
check_organization_membership "$ORGANIZATION" "$CURRENT_USER" || exit 1

# 作成確認（共通関数使用）
confirm_creation "${ORGANIZATION}/${REPO_NAME}" || exit 0

# リポジトリ作成（共通関数使用）
echo ""
echo "📁 リポジトリを作成中..."

echo "📋 ISEレポートリポジトリ作成開始..."
echo "   学籍番号: $STUDENT_ID"
echo "   リポジトリ名: $REPO_NAME"
echo "   レポート番号: $ISE_REPORT_NUM"

# 特殊なリポジトリ作成（ISEはcloneしない）
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

# Git認証設定（共通関数使用）
setup_git_auth || exit 1

# Gitユーザー設定（共通関数使用）
setup_git_user "setup-ise@smkwlab.github.io" "ISE Setup Tool"

# リポジトリをクローン（共通関数使用）
clone_repository "https://github.com/$ORGANIZATION/$REPO_NAME.git" "$REPO_NAME" || exit 1

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
git checkout review-branch
git checkout -b 0th-draft

# README.md をカスタマイズ
echo "📝 README.md をカスタマイズ中..."
REPORT_TITLE="情報科学演習 レポート #${ISE_REPORT_NUM}"
if [ "$ISE_REPORT_NUM" = "1" ]; then
    REPORT_PERIOD="前期"
else
    REPORT_PERIOD="後期"
fi

# README更新（簡略化）
cat > README.md << EOF
# ${STUDENT_ID} - ${REPORT_TITLE}

${REPORT_PERIOD}の情報科学演習レポート（Pull Request学習用）

## 📋 基本情報

- **学籍番号**: ${STUDENT_ID}
- **レポート**: ${REPORT_TITLE} (${REPORT_PERIOD})
- **作成日**: $(date '+%Y年%m月%d日')

## 🚀 作業の流れ

### 1. 作業用ブランチの作成
\`\`\`bash
git checkout review-branch
git checkout -b 1st-draft
\`\`\`

### 2. レポート作成
- \`index.html\` を編集
- 必要に応じて画像や資料を追加

### 3. Pull Request作成
1. 変更をコミット・プッシュ
2. GitHub上でPull Requestを作成
3. レビューを待つ

### 4. レビュー対応
- フィードバックに基づいて修正
- 必要に応じて新しいドラフトブランチで再提出

## 📁 ファイル構成

\`\`\`
${STUDENT_ID}-ise-report${ISE_REPORT_NUM}/
├── index.html          # メインレポート
├── README.md           # このファイル
├── REVIEW_BRANCH.md    # レビューブランチ説明
└── assets/             # 画像・資料
\`\`\`

## 🔗 関連リンク

- [レポートページ](index.html)
- [下川研究室](https://shimokawa-lab.kyusan-u.ac.jp/)

---
**セットアップ**: $(date '+%Y-%m-%d %H:%M:%S') JST
EOF

echo -e "${GREEN}✓ README.md カスタマイズ完了${NC}"

# 初期ドラフトをコミット・プッシュ（共通関数使用）
echo "📤 初期ドラフトをコミット中..."
commit_and_push "Initial setup for ISE Report #${ISE_REPORT_NUM}

- Setup Pull Request learning environment
- Create review-branch and 0th-draft
- Customize README for ${STUDENT_ID}
- Report: ${REPORT_TITLE} (${REPORT_PERIOD})
" "0th-draft" || exit 1

# review-branchに戻る
git checkout review-branch

echo ""
echo "=============================================="
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL:"
echo "  https://github.com/$ORGANIZATION/$REPO_NAME"
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