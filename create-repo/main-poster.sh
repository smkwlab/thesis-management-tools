#!/bin/bash
# 学会ポスターリポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "学会ポスターリポジトリセットアップツール" "📊"

# ブランチ保護設定の確認（環境変数でオプトイン）
ENABLE_PROTECTION="${ENABLE_PROTECTION:-false}"
[ "$ENABLE_PROTECTION" = "true" ] && echo -e "${YELLOW}⚠️ ブランチ保護が有効化されています${NC}"

# 組織設定
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定（常にsmkwlab/poster-templateを使用）
TEMPLATE_REPOSITORY="smkwlab/poster-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# INDIVIDUAL_MODEの場合は学籍番号をスキップ（柔軟な値判定）
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    echo -e "${BLUE}📝 個人モード: 学籍番号の入力をスキップします${NC}"
    STUDENT_ID=""
else
    # 学籍番号の入力
    STUDENT_ID=$(read_student_id "$1")

    # 学籍番号の正規化と検証
    STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
    echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"
fi

# ポスター名の入力
read_poster_name() {
    if [ -n "$POSTER_NAME" ]; then
        echo -e "${GREEN}✓ ポスター名: $POSTER_NAME（環境変数指定）${NC}"
        return 0
    fi

    if [ -n "$DOCUMENT_NAME" ]; then
        POSTER_NAME="$DOCUMENT_NAME"
        echo -e "${GREEN}✓ ポスター名: $POSTER_NAME（環境変数指定）${NC}"
        return 0
    fi

    echo ""
    echo "📊 ポスター名を入力してください (デフォルト: poster):"
    echo "   例: jxiv2025-poster, conference2024, symposium-poster"
    read -r -p "> " POSTER_NAME

    POSTER_NAME="${POSTER_NAME:-poster}"

    if ! [[ "$POSTER_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}❌ ポスター名は英数字、ハイフン、アンダースコアのみ使用可能です${NC}"
        POSTER_NAME=""
        read_poster_name
    fi
}

read_poster_name

# リポジトリ名の決定（柔軟な値判定）
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    REPO_NAME="${POSTER_NAME}"
else
    REPO_NAME="${STUDENT_ID}-${POSTER_NAME}"
fi

# 組織アクセス確認
check_organization_access "$ORGANIZATION"

# リポジトリパス決定
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}❌ リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成
echo ""
echo "📁 リポジトリを作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "public" "true" || exit 1
cd "$REPO_NAME"

# LaTeX環境のセットアップ
setup_latex_environment

# STEP 1: main ブランチでファイルをセットアップ
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true
rm -rf docs/ 2>/dev/null || true
find . -name '*-aldc' -exec rm -rf {} + 2>/dev/null || true
git add -u

# Git設定
setup_git_auth || exit 1
setup_git_user "setup-poster@smkwlab.github.io" "Poster Setup Tool"

# ブランチ保護設定メッセージ（オプトイン）
if [ "$ENABLE_PROTECTION" != "true" ]; then
    echo -e "${BLUE}📝 ポスターテンプレートのため、ブランチ保護は設定しません${NC}"
    echo -e "${BLUE}   mainブランチで直接作業できます${NC}"
fi

# 変更をコミットしてプッシュ
echo "📤 変更をコミット中..."
commit_and_push "Initial setup for ${POSTER_NAME}

- Configure LaTeX environment
- Remove template documentation files
- Prepare for poster development" || exit 1

# Registry Manager連携（組織ユーザーのみ、かつ学籍番号がある場合）
# 条件: 個人モードが無効 AND 学籍番号が存在 AND Registryリポジトリがアクセス可能
# INDIVIDUAL_MODEが有効でない場合のみRegistry Manager連携
if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]] && [ -n "$STUDENT_ID" ]; then
    if gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
        if ! create_repository_issue "$REPO_NAME" "$STUDENT_ID" "poster" "$ORGANIZATION" &>/dev/null; then
            echo -e "${YELLOW}⚠️ Registry Manager登録でエラーが発生しました。手動で登録が必要な場合があります。${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Registry Managerリポジトリが見つかりません。Registry連携をスキップします。${NC}"
    fi
fi

# 完了メッセージ
echo ""
echo "=============================================="
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "リポジトリ: https://github.com/${REPO_PATH}"
echo ""
echo "次のステップ:"
echo "1. a0poster.texを編集してポスターを作成"
echo "2. git add, commit, pushで変更を保存"
echo "3. GitHub Actionsで自動的にPDFが生成されます"
echo ""
echo "ポスターテンプレートの特徴:"
echo "- A0サイズ学会ポスター用"
echo "- tikzposterによる柔軟なレイアウト"
echo "- LuaLaTeXで日本語完全対応"
echo "- 複数のテーマとスタイルから選択可能"
echo ""
echo "=============================================="
