#!/bin/bash
# 論文リポジトリセットアップスクリプト（最終リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "論文リポジトリセットアップツール" "🎓"

# 機能設定情報は内部処理のみ（表示不要）

# 組織設定（共通関数使用）
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/sotsuron-template}"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力（共通関数使用）
STUDENT_ID=$(read_student_id "$1" "卒業論文の例: k21rs001, 修士論文の例: k21gjk01")

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1

# 論文タイプの判定
determine_thesis_type() {
    local student_id="$1"
    
    # kxxの次の文字がgの場合は修士論文、それ以外は卒業論文
    if echo "$student_id" | grep -qE '^k[0-9]{2}g'; then
        echo "shuuron"
    else
        echo "sotsuron"
    fi
}

THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID") || exit 1

# リポジトリ名の決定
if [ "$THESIS_TYPE" = "shuuron" ]; then
    REPO_NAME="${STUDENT_ID}-master"
else
    REPO_NAME="${STUDENT_ID}-sotsuron"
fi

echo -e "${GREEN}✓ GitHubユーザー: $CURRENT_USER${NC}"
[ "$THESIS_TYPE" = "sotsuron" ] && echo -e "${GREEN}✓ 卒業論文リポジトリとして設定します${NC}" || echo -e "${GREEN}✓ 修士論文リポジトリとして設定します${NC}"

# 組織アクセス確認（共通関数使用）
check_organization_access "$ORGANIZATION"

# リポジトリパス決定（共通関数使用）
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}エラー: リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認（共通関数使用）
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成（共通関数使用）
echo ""
echo "リポジトリ ${REPO_PATH} を作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "private" "true" || exit 1

cd "$REPO_NAME"

# Git設定（共通関数使用）
setup_git_auth || exit 1
setup_git_user "thesis-setup@smkwlab.github.io" "Thesis Setup Tool"

# テンプレート整理
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true

# LaTeX環境のセットアップ（共通関数使用）
setup_latex_environment

# STEP 1: main ブランチで充実したコンテンツを作成・コミット
echo "📝 main ブランチでセットアップファイルを作成中..."

# README.md を学生用にカスタマイズ
cat > README.md << EOF
# ${STUDENT_ID} - ${THESIS_TYPE}論文

## 📋 基本情報

- **学籍番号**: ${STUDENT_ID}
- **論文種別**: ${THESIS_TYPE}
- **作成日**: $(date '+%Y-%m-%d')

## 📖 執筆ワークフロー

### 1. ブランチ構成
- **main**: 最終版・公開用ブランチ
- **initial**: 空の比較用ベースブランチ  
- **review-branch**: 添削・レビュー用ブランチ
- **0th-draft**, **1st-draft**, **2nd-draft**: 各段階の執筆用ブランチ

### 2. 執筆の流れ
1. **ドラフトブランチ作成**: \`0th-draft\` から開始
2. **LaTeX執筆**: \`thesis.tex\` または \`sotsuron.tex\` を編集
3. **Pull Request提出**: review-branch へのPRを作成
4. **フィードバック対応**: 指摘に基づいて次のドラフトで修正
5. **最終版完成**: 承認後 main へマージ

### 3. ファイル構成
\`\`\`
${REPO_NAME}/
├── thesis.tex          # 修士論文メインファイル
├── sotsuron.tex         # 卒業論文メインファイル
├── abstract.tex         # 要旨
├── gaiyou.tex          # 概要
├── README.md           # このファイル
├── WRITING-GUIDE.md    # 執筆ガイド
└── docs/               # 参考資料
\`\`\`

## 🔗 関連リンク

- [執筆ガイド](WRITING-GUIDE.md)
- [下川研究室](https://shimokawa-lab.kyusan-u.ac.jp/)

---
**セットアップ**: $(date '+%Y-%m-%d %H:%M:%S') JST
EOF

# BRANCH_WORKFLOW.md を作成（レビューブランチ説明）
cat > BRANCH_WORKFLOW.md << 'EOF'
# ブランチワークフロー説明

## ブランチ構成の目的

この論文リポジトリは**Pull Request ベースの添削システム**を使用します。

### ブランチの役割

#### main ブランチ
- **最終版・公開用**ブランチ
- 完成した論文がここに保存される
- 直接編集はせず、PRを通してのみ更新

#### initial ブランチ  
- **空の比較用ベース**ブランチ
- 変更差分を明確にするための基準点
- 学生は直接操作しない

#### review-branch ブランチ
- **添削・レビュー用**ブランチ
- Pull Request の受け入れ先
- 教員・先輩によるレビューのベース

#### ドラフトブランチ（0th-draft, 1st-draft等）
- **執筆用作業**ブランチ
- 各段階での論文執筆を行う
- review-branch に対して PR を作成

## Pull Request 学習の流れ

1. **ドラフトブランチで執筆**
2. **Pull Request 作成** → review-branch へ
3. **レビュー・フィードバック受領**
4. **新しいドラフトブランチで修正**
5. **反復改善で論文品質向上**

このワークフローにより、**段階的な論文改善**と**協働執筆スキル**の両方を習得できます。
EOF

# main ブランチでセットアップファイルをコミット・プッシュ
git add README.md BRANCH_WORKFLOW.md >/dev/null 2>&1
git commit -m "Initial setup for ${THESIS_TYPE} thesis

- Setup Pull Request-based review environment  
- Create structured branch workflow
- Student: ${STUDENT_ID}
- Thesis type: ${THESIS_TYPE}" >/dev/null 2>&1

if git push origin main >/dev/null 2>&1; then
    echo -e "${GREEN}✓ main ブランチセットアップ完了${NC}"
else
    echo -e "${RED}❌ main ブランチのプッシュに失敗しました${NC}"
    exit 1
fi

# STEP 2: 0th-draft ブランチの作成（main から分岐）
echo "📝 0th-draft ブランチを作成中..."
git checkout -b 0th-draft >/dev/null 2>&1

# STEP 3&4: orphan branch ワークフロー全体をセットアップ（共通関数使用）
setup_orphan_branch_workflow ".tex_placeholder" "*.tex *.cls *.sty" "thesis" "0th-draft" || exit 1

# Issue作成（組織モードのみ）
if [ "$INDIVIDUAL_MODE" = false ]; then
    if ! create_repository_issue "$REPO_NAME" "$STUDENT_ID" "$THESIS_TYPE" "$ORGANIZATION"; then
        echo -e "${YELLOW}⚠️ Registry Manager登録でエラーが発生しました。手動で登録が必要な場合があります。${NC}"
    fi
fi

# review-branch のブランチ保護設定
echo "🔒 review-branch のブランチ保護を設定中..."
if [ "$INDIVIDUAL_MODE" = false ]; then
    # 組織リポジトリの場合はreview-branchも保護
    # 保護設定をJSONファイルから読み込み
    local protection_config_file="${SCRIPT_DIR}/protection-config.json"
    if [ ! -f "$protection_config_file" ]; then
        echo -e "${YELLOW}⚠️ 保護設定ファイルが見つかりません: $protection_config_file${NC}"
        echo -e "${YELLOW}   review-branch のブランチ保護設定をスキップします${NC}"
    else
        local protection_config=$(cat "$protection_config_file")
        
        if echo "$protection_config" | gh api "repos/${ORGANIZATION}/${REPO_NAME}/branches/review-branch/protection" \
            --method PUT \
            --input - >/dev/null 2>&1; then
            echo -e "${GREEN}✓ review-branch のブランチ保護設定完了${NC}"
        else
            echo -e "${YELLOW}⚠️ review-branch のブランチ保護設定に失敗しました${NC}"
            echo -e "${YELLOW}   後で手動設定が必要な場合があります${NC}"
        fi
    fi
else
    echo -e "${BLUE}   個人リポジトリのため、review-branch 保護はスキップ${NC}"
fi

# 完了メッセージ
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL:"
echo "  https://github.com/$REPO_PATH"
echo ""
echo "論文執筆の開始方法:"
echo "  https://github.com/$REPO_PATH/blob/main/WRITING-GUIDE.md"