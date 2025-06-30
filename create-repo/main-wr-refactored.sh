#!/bin/bash
# 週報リポジトリセットアップスクリプト（リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

echo "📝 週報リポジトリセットアップツール"
echo "=============================================="

# GitHub認証（Docker内用）
check_github_auth_docker || exit 1

# 動作モードの判定
OPERATION_MODE=$(determine_operation_mode)
INDIVIDUAL_MODE=false
if [ "$OPERATION_MODE" = "individual" ]; then
    INDIVIDUAL_MODE=true
    echo -e "${BLUE}   - ブランチ保護: 無効（デフォルト）${NC}"
    echo -e "${BLUE}   - Registry登録: 無効${NC}"
else
    echo -e "${GREEN}   - ブランチ保護: 無効（デフォルト）${NC}"
    echo -e "${GREEN}   - Registry登録: 有効${NC}"
fi

# 組織/ユーザーの設定
if [ -n "$TARGET_ORG" ]; then
    ORGANIZATION="$TARGET_ORG"
    echo -e "${GREEN}✓ 指定された組織: $ORGANIZATION${NC}"
elif [ -n "$GITHUB_REPOSITORY" ]; then
    ORGANIZATION=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
    echo -e "${GREEN}✓ 自動検出された組織: $ORGANIZATION${NC}"
else
    ORGANIZATION="smkwlab"
    echo -e "${YELLOW}✓ デフォルト組織を使用: $ORGANIZATION${NC}"
fi

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/wr-template"
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

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# リポジトリ名の生成
REPO_NAME="${STUDENT_ID}-wr"

# 現在のユーザーアカウントを取得
if ! CURRENT_USER=$(gh api user --jq .login 2>/dev/null); then
    echo -e "${RED}❌ GitHub APIアクセスに失敗しました${NC}"
    echo "認証トークンを更新してください："
    echo "  gh auth refresh"
    exit 1
fi

# 組織へのアクセス権限確認（共通関数使用）
if [ "$INDIVIDUAL_MODE" = false ]; then
    check_organization_membership "$ORGANIZATION" "$CURRENT_USER" || exit 1
fi

# リポジトリの存在確認
if [ "$INDIVIDUAL_MODE" = false ]; then
    REPO_PATH="${ORGANIZATION}/${REPO_NAME}"
else
    REPO_PATH="${CURRENT_USER}/${REPO_NAME}"
fi

if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}❌ リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認（共通関数使用）
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成
echo ""
echo "📁 リポジトリを作成中..."

# テンプレートからリポジトリを作成
if [ "$INDIVIDUAL_MODE" = false ]; then
    # 組織の場合
    if gh repo create "${ORGANIZATION}/${REPO_NAME}" --public --template="$TEMPLATE_REPOSITORY" --clone; then
        echo -e "${GREEN}✓ リポジトリを作成しました: https://github.com/${ORGANIZATION}/${REPO_NAME}${NC}"
    else
        echo -e "${RED}エラー: リポジトリの作成に失敗しました${NC}"
        echo "- 既に同名のリポジトリが存在する可能性があります"
        echo "- 組織への権限が不足している可能性があります"
        exit 1
    fi
else
    # 個人の場合
    if gh repo create "${REPO_NAME}" --public --template="$TEMPLATE_REPOSITORY" --clone; then
        echo -e "${GREEN}✓ リポジトリを作成しました: https://github.com/${CURRENT_USER}/${REPO_NAME}${NC}"
    else
        echo -e "${RED}エラー: リポジトリの作成に失敗しました${NC}"
        echo "- 既に同名のリポジトリが存在する可能性があります"
        exit 1
    fi
fi

# リポジトリディレクトリに移動
cd "$REPO_NAME"

# README.mdのカスタマイズ
echo "📝 README.mdをカスタマイズ中..."

# 新しいREADME.mdを生成
cat > README.md << EOF
# ${STUDENT_ID} 週報

九州産業大学 理工学部 情報科学科  
学籍番号: ${STUDENT_ID}

## 📅 週報一覧

### $(date +%Y)年度

| 週 | 期間 | タイトル | リンク |
|----|------|----------|--------|
| 第1週 | MM/DD - MM/DD | タイトルを入力 | [week01.md](reports/week01.md) |
| 第2週 | MM/DD - MM/DD | タイトルを入力 | [week02.md](reports/week02.md) |

## 🚀 使い方

### 1. 新しい週報の作成
1. \`reports/\` ディレクトリ内の \`weekXX.md\` をコピー
2. 週番号に応じてファイル名を変更（例: \`week03.md\`）
3. テンプレートに従って内容を記入

### 2. 週報の記入方法
- 各セクションに具体的な内容を記入
- Markdownフォーマットで記述
- 画像は \`images/\` ディレクトリに配置

### 3. 提出
1. 変更をコミット
2. GitHubにプッシュ
3. 担当教員に報告

## 📂 ディレクトリ構成

\`\`\`
${STUDENT_ID}-wr/
├── README.md           # このファイル
├── reports/           # 週報ファイル
│   ├── week01.md
│   ├── week02.md
│   └── ...
└── images/            # 画像ファイル
    └── ...
\`\`\`

## 📝 週報テンプレート

各週報は以下の構成で記述してください：

1. **今週の活動内容**
   - 具体的な作業内容
   - 達成した成果

2. **来週の予定**
   - 計画している作業
   - 目標

3. **課題・質問**
   - 困っていること
   - 相談したいこと

## 🔗 関連リンク

- [下川研究室](https://shimokawa-lab.kyusan-u.ac.jp/)
- [九州産業大学](https://www.kyusan-u.ac.jp/)

---
最終更新: $(date '+%Y-%m-%d')
EOF

echo -e "${GREEN}✓ README.mdをカスタマイズしました${NC}"

# Git認証設定（共通関数使用）
setup_git_auth || exit 1

# Gitユーザー設定（共通関数使用）
setup_git_user "setup-wr@smkwlab.github.io" "Weekly Report Setup Tool"

# 変更をコミットしてプッシュ
echo "📤 変更をコミット中..."

git add .
git commit -m "Customize README for ${STUDENT_ID}

- Set student ID: ${STUDENT_ID}
- Update repository structure
- Add weekly report template information
"

if git push origin main; then
    echo -e "${GREEN}✓ 変更をプッシュしました${NC}"
else
    echo -e "${RED}エラー: プッシュに失敗しました${NC}"
    exit 1
fi

# Registry Manager連携（組織ユーザーのみ）
if [ "$INDIVIDUAL_MODE" = false ]; then
    echo "📊 Registry Managerに登録中..."
    
    # thesis-student-registryリポジトリの存在確認
    if gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
        # リポジトリ登録依頼Issueの作成（共通関数使用）
        create_repository_issue "$REPO_NAME" "$STUDENT_ID" "wr" "$ORGANIZATION"
    else
        echo -e "${YELLOW}⚠️ thesis-student-registryリポジトリが見つかりません${NC}"
    fi
fi

# 完了メッセージ
echo ""
echo "==============================================" 
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "リポジトリ: https://github.com/$REPO_PATH"
echo "ローカル: ./${REPO_NAME}"
echo ""
echo "次のステップ:"
echo "1. reports/week01.md を編集して最初の週報を作成"
echo "2. git add, commit, pushで変更を保存"
echo "3. 毎週新しい週報ファイルを追加"
echo ""
echo "ブランチ保護: 無効（mainブランチで直接作業可能）"
echo "=============================================="