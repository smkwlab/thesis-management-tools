#!/bin/bash
# 情報科学演習レポートリポジトリセットアップスクリプト

set -e

# スクリプトディレクトリを保存（templates/ 参照用）
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリの読み込み
source "${SCRIPT_DIR}/common-lib.sh"

# 共通初期化
init_script_common "情報科学演習レポートリポジトリセットアップツール" "📝"

# 組織設定
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/ise-report-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力
STUDENT_ID=$(read_student_id "$1")

# 学籍番号の正規化と検証
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# ISE レポート番号の決定とリポジトリ存在チェック（日時ベース）
determine_ise_report_number() {
    local student_id="$1"
    local report_num
    
    # 環境変数による手動制御をチェック
    if [ -n "$ISE_REPORT_NUM" ] && [ "$ISE_REPORT_NUM" != "auto" ]; then
        if [ "$ISE_REPORT_NUM" = "1" ] || [ "$ISE_REPORT_NUM" = "2" ]; then
            # 手動指定の場合は指定されたリポジトリのみチェック（1回のAPI呼び出し）
            # GitHubのリダイレクトに対応するため、実際のリポジトリ名も確認
            local target_repo="${ORGANIZATION}/${student_id}-ise-report${ISE_REPORT_NUM}"
            local api_result=$(gh api "repos/${target_repo}" --jq .name 2>&1)
            local api_status=$?
            
            if [ $api_status -eq 0 ]; then
                # API呼び出し成功
                if [ "$api_result" = "${student_id}-ise-report${ISE_REPORT_NUM}" ]; then
                    echo -e "${RED}❌ リポジトリ ${ORGANIZATION}/${student_id}-ise-report${ISE_REPORT_NUM} は既に存在します${NC}" >&2
                    echo "   https://github.com/${ORGANIZATION}/${student_id}-ise-report${ISE_REPORT_NUM}" >&2
                    exit 1
                fi
                # リネームされている場合は作成可能
            elif echo "$api_result" | grep -q "HTTP 404" 2>/dev/null; then
                # リポジトリが存在しない（正常）
                :
            else
                # その他のAPIエラー
                echo -e "${YELLOW}⚠️ GitHub APIへのアクセスに問題が発生しました${NC}" >&2
                echo "   詳細: $api_result" >&2
                echo "   しばらく待ってから再実行するか、ネットワーク接続を確認してください" >&2
                exit 1
            fi
            echo -e "${BLUE}🔧 手動指定: ISE_REPORT_NUM=$ISE_REPORT_NUM${NC}" >&2
            echo "$ISE_REPORT_NUM"
            return
        else
            echo -e "${RED}❌ ISE_REPORT_NUM は 1 または 2 を指定してください (現在: $ISE_REPORT_NUM)${NC}" >&2
            exit 1
        fi
    fi
    
    # 学期定数の定義
    local EARLY_TERM_START_MONTH=4
    local EARLY_TERM_END_MONTH=9
    
    # 現在の月から前期/後期を判定
    local current_month=$(date +%m)
    local preferred_num fallback_num
    
    if (( current_month >= EARLY_TERM_START_MONTH && current_month <= EARLY_TERM_END_MONTH )); then
        # 4月〜9月: 前期 → ise-report1を優先
        preferred_num=1
        fallback_num=2
        echo -e "${BLUE}📅 前期期間 (${current_month}月): ise-report1 を優先${NC}" >&2
    else
        # 10月〜3月: 後期 → ise-report2を優先
        preferred_num=2
        fallback_num=1
        echo -e "${BLUE}📅 後期期間 (${current_month}月): ise-report2 を優先${NC}" >&2
    fi
    
    # 優先リポジトリを最初にチェック（最適化: 利用可能なら1回で完了）
    # GitHubのリダイレクトに対応するため、実際のリポジトリ名も確認
    local preferred_repo="${ORGANIZATION}/${student_id}-ise-report${preferred_num}"
    local api_result=$(gh api "repos/${preferred_repo}" --jq .name 2>&1)
    local api_status=$?
    
    if [ $api_status -ne 0 ]; then
        if echo "$api_result" | grep -q "HTTP 404" 2>/dev/null; then
            # リポジトリが存在しない（正常）
            report_num=$preferred_num
            echo -e "${GREEN}✓ ${student_id}-ise-report${preferred_num} は利用可能${NC}" >&2
        else
            # APIエラー
            echo -e "${YELLOW}⚠️ GitHub APIへのアクセスに問題が発生しました${NC}" >&2
            echo "   詳細: $api_result" >&2
            echo "   しばらく待ってから再実行するか、ネットワーク接続を確認してください" >&2
            exit 1
        fi
    elif [ "$api_result" != "${student_id}-ise-report${preferred_num}" ]; then
        # リネームされている
        report_num=$preferred_num
        echo -e "${GREEN}✓ ${student_id}-ise-report${preferred_num} は利用可能${NC}" >&2
    else
        # 優先リポジトリが存在する場合のみフォールバックをチェック
        local fallback_repo="${ORGANIZATION}/${student_id}-ise-report${fallback_num}"
        local fallback_result=$(gh api "repos/${fallback_repo}" --jq .name 2>&1)
        local fallback_status=$?
        
        if [ $fallback_status -ne 0 ]; then
            if echo "$fallback_result" | grep -q "HTTP 404" 2>/dev/null; then
                # フォールバックリポジトリが存在しない
                report_num=$fallback_num
                echo -e "${YELLOW}⚠️ ${student_id}-ise-report${preferred_num} は既存、${student_id}-ise-report${fallback_num} を使用${NC}" >&2
            else
                # APIエラー
                echo -e "${YELLOW}⚠️ GitHub APIへのアクセスに問題が発生しました${NC}" >&2
                echo "   詳細: $fallback_result" >&2
                echo "   しばらく待ってから再実行するか、ネットワーク接続を確認してください" >&2
                exit 1
            fi
        elif [ "$fallback_result" != "${student_id}-ise-report${fallback_num}" ]; then
            # フォールバックリポジトリがリネームされている
            report_num=$fallback_num
            echo -e "${YELLOW}⚠️ ${student_id}-ise-report${preferred_num} は既存、${student_id}-ise-report${fallback_num} を使用${NC}" >&2
        else
            echo -e "${RED}❌ 情報科学演習レポートは最大2つまでです${NC}" >&2
            echo "   前期用: https://github.com/${ORGANIZATION}/${student_id}-ise-report1" >&2
            echo "   後期用: https://github.com/${ORGANIZATION}/${student_id}-ise-report2" >&2
            echo "" >&2
            echo "削除が必要な場合は、担当教員にご相談ください。" >&2
            echo "または環境変数で手動指定: ISE_REPORT_NUM=1 または ISE_REPORT_NUM=2" >&2
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

# 組織アクセス確認
check_organization_access "$ORGANIZATION"

# 作成確認
confirm_creation "${ORGANIZATION}/${REPO_NAME}" || exit 0

# リポジトリ作成（共通関数使用・カスタムdescription付き）
echo ""
echo "📁 リポジトリを作成中..."

echo "📋 ISEレポートリポジトリ作成開始..."
echo "   学籍番号: $STUDENT_ID"
echo "   リポジトリ名: $REPO_NAME"
echo "   レポート番号: $ISE_REPORT_NUM"

create_repository "${ORGANIZATION}/${REPO_NAME}" "$TEMPLATE_REPOSITORY" "private" "true" || exit 1

cd "$REPO_NAME"

# Git設定
setup_git_auth || exit 1
setup_git_user "setup-ise@smkwlab.github.io" "ISE Setup Tool"

# STEP 1: main ブランチでファイルをセットアップ
echo "テンプレートファイルを整理中..."
rm -f CLAUDE.md 2>/dev/null || true
rm -rf docs/ 2>/dev/null || true

# smkwlab 組織メンバーの場合は auto-assign 設定を追加
setup_auto_assign_for_organization_members

# main ブランチでの初期セットアップコミット
git add -u
git add .github/ 2>/dev/null || true
git commit -m "Initial setup for ISE Report #${ISE_REPORT_NUM}" >/dev/null 2>&1 || true

if git push origin main >/dev/null 2>&1; then
    echo -e "${GREEN}✓ main ブランチセットアップ完了${NC}"
else
    echo -e "${RED}❌ main ブランチのプッシュに失敗しました${NC}"
    exit 1
fi

# ドラフトブランチを作成
setup_review_workflow "0th-draft" || exit 1

# 初期ドラフトをコミット・プッシュ
echo "📤 初期ドラフトをコミット中..."
commit_and_push "Initial setup for ISE Report #${ISE_REPORT_NUM}" "0th-draft" || exit 1

# Registry Manager連携（組織ユーザーのみ）
if [ "$INDIVIDUAL_MODE" = false ] && gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
    if ! create_repository_issue "$REPO_NAME" "$STUDENT_ID" "ise" "$ORGANIZATION"; then
        echo -e "${YELLOW}⚠️ Registry Manager登録でエラーが発生しました。手動で登録が必要な場合があります。${NC}"
    fi
fi

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
