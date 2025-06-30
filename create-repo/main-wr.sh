#!/bin/bash
# 週報リポジトリセットアップスクリプト（最終リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "週報リポジトリセットアップツール" "📝"

# 機能設定情報は内部処理のみ（表示不要）

# 組織設定（共通関数使用）
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/wr-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力（共通関数使用）
STUDENT_ID=$(read_student_id "$1")

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# リポジトリ名の生成
REPO_NAME="${STUDENT_ID}-wr"

# 組織アクセス確認（共通関数使用）
check_organization_access "$ORGANIZATION"

# リポジトリパス決定（共通関数使用）
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}❌ リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認（共通関数使用）
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成（共通関数使用）
echo ""
echo "📁 リポジトリを作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "public" "true" || exit 1

cd "$REPO_NAME"

# README.mdのカスタマイズ
echo "📝 README.mdをカスタマイズ中..."

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

# Git設定（共通関数使用）
setup_git_auth || exit 1
setup_git_user "setup-wr@smkwlab.github.io" "Weekly Report Setup Tool"

# 変更をコミットしてプッシュ（共通関数使用）
echo "📤 変更をコミット中..."
commit_and_push "Customize README for ${STUDENT_ID}

- Set student ID: ${STUDENT_ID}
- Update repository structure
- Add weekly report template information
" || exit 1

# Registry Manager連携（組織ユーザーのみ）
[ "$INDIVIDUAL_MODE" = false ] && gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null && create_repository_issue "$REPO_NAME" "$STUDENT_ID" "wr" "$ORGANIZATION"

# 完了メッセージ
echo ""
echo "===============================================" 
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