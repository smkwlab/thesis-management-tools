#!/bin/bash
# 情報科学演習レポートリポジトリセットアップスクリプト

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "情報科学演習レポートリポジトリセットアップツール" "📝"

# 設定
ORGANIZATION=$(determine_organization)
TEMPLATE_REPOSITORY="${ORGANIZATION}/ise-report-template"
VISIBILITY="private"

log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# INDIVIDUAL_MODEの場合は学籍番号をスキップ
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    log_debug "個人モード: 学籍番号の入力をスキップします"
    STUDENT_ID=""
else
    # 学籍番号の入力と検証
    STUDENT_ID=$(read_student_id "$1")
    STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
    log_info "学籍番号: $STUDENT_ID"
fi

# ISE レポート番号の決定とリポジトリ存在チェック（日時ベース）
# この関数は ISE 固有のロジックのため、ここに残す
determine_ise_report_number() {
    local student_id="$1"
    local report_num

    # 環境変数による手動制御をチェック
    if [ -n "$ISE_REPORT_NUM" ] && [ "$ISE_REPORT_NUM" != "auto" ]; then
        if [ "$ISE_REPORT_NUM" = "1" ] || [ "$ISE_REPORT_NUM" = "2" ]; then
            local target_repo="${ORGANIZATION}/${student_id}-ise-report${ISE_REPORT_NUM}"
            local api_result=$(gh api "repos/${target_repo}" --jq .name 2>&1)
            local api_status=$?

            if [ $api_status -eq 0 ]; then
                if [ "$api_result" = "${student_id}-ise-report${ISE_REPORT_NUM}" ]; then
                    log_error "リポジトリ ${target_repo} は既に存在します"
                    echo "   https://github.com/${target_repo}" >&2
                    exit 1
                fi
            elif ! echo "$api_result" | grep -q "HTTP 404" 2>/dev/null; then
                log_warn "GitHub APIへのアクセスに問題が発生しました"
                echo "   詳細: $api_result" >&2
                exit 1
            fi
            log_debug "手動指定: ISE_REPORT_NUM=$ISE_REPORT_NUM"
            echo "$ISE_REPORT_NUM"
            return
        else
            die "ISE_REPORT_NUM は 1 または 2 を指定してください (現在: $ISE_REPORT_NUM)"
        fi
    fi

    # 学期判定
    local current_month=$(date +%m)
    local preferred_num fallback_num

    if (( current_month >= 4 && current_month <= 9 )); then
        preferred_num=1
        fallback_num=2
        log_debug "前期期間 (${current_month}月): ise-report1 を優先"
    else
        preferred_num=2
        fallback_num=1
        log_debug "後期期間 (${current_month}月): ise-report2 を優先"
    fi

    # 優先リポジトリをチェック
    local preferred_repo="${ORGANIZATION}/${student_id}-ise-report${preferred_num}"
    local api_result=$(gh api "repos/${preferred_repo}" --jq .name 2>&1)
    local api_status=$?

    if [ $api_status -ne 0 ]; then
        if echo "$api_result" | grep -q "HTTP 404" 2>/dev/null; then
            report_num=$preferred_num
            log_info "${student_id}-ise-report${preferred_num} は利用可能"
        else
            log_warn "GitHub APIへのアクセスに問題が発生しました"
            echo "   詳細: $api_result" >&2
            exit 1
        fi
    elif [ "$api_result" != "${student_id}-ise-report${preferred_num}" ]; then
        report_num=$preferred_num
        log_info "${student_id}-ise-report${preferred_num} は利用可能"
    else
        # フォールバックをチェック
        local fallback_repo="${ORGANIZATION}/${student_id}-ise-report${fallback_num}"
        local fallback_result=$(gh api "repos/${fallback_repo}" --jq .name 2>&1)
        local fallback_status=$?

        if [ $fallback_status -ne 0 ]; then
            if echo "$fallback_result" | grep -q "HTTP 404" 2>/dev/null; then
                report_num=$fallback_num
                log_warn "${student_id}-ise-report${preferred_num} は既存、${student_id}-ise-report${fallback_num} を使用"
            else
                log_warn "GitHub APIへのアクセスに問題が発生しました"
                echo "   詳細: $fallback_result" >&2
                exit 1
            fi
        elif [ "$fallback_result" != "${student_id}-ise-report${fallback_num}" ]; then
            report_num=$fallback_num
            log_warn "${student_id}-ise-report${preferred_num} は既存、${student_id}-ise-report${fallback_num} を使用"
        else
            log_error "情報科学演習レポートは最大2つまでです"
            echo "   前期用: https://github.com/${ORGANIZATION}/${student_id}-ise-report1" >&2
            echo "   後期用: https://github.com/${ORGANIZATION}/${student_id}-ise-report2" >&2
            echo "" >&2
            echo "削除が必要な場合は、担当教員にご相談ください。" >&2
            exit 1
        fi
    fi

    echo "$report_num"
}

# リポジトリ名の決定
if [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    ISE_REPORT_NUM="1"
    REPO_NAME="ise-report"
    log_info "個人モード: ISEレポートリポジトリとして設定します"
else
    echo "📋 既存ISEレポートリポジトリの確認中..."
    ISE_REPORT_NUM=$(determine_ise_report_number "$STUDENT_ID")
    REPO_NAME="${STUDENT_ID}-ise-report${ISE_REPORT_NUM}"

    if [ "$ISE_REPORT_NUM" = "1" ]; then
        log_info "作成対象: ${REPO_NAME} (初回のISEレポート)"
    else
        log_info "${STUDENT_ID}-ise-report1 が存在"
        log_info "作成対象: ${REPO_NAME} (2回目のISEレポート)"
    fi
fi

# 標準セットアップフロー
run_standard_setup "ise"

# smkwlab 組織メンバーの場合は auto-assign 設定を追加
setup_auto_assign_for_organization_members

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# main ブランチでの初期セットアップコミット
git add -u
git add .github/ 2>/dev/null || true
git add .devcontainer/ 2>/dev/null || true
git commit -m "Initial setup for ISE Report #${ISE_REPORT_NUM}" >/dev/null 2>&1 || true

if git push origin main >/dev/null 2>&1; then
    log_info "main ブランチセットアップ完了"
else
    die "main ブランチのプッシュに失敗しました"
fi

# ドラフトブランチを作成
setup_review_workflow "0th-draft" || exit 1

# 初期ドラフトをコミット・プッシュ
commit_and_push "Initial setup for ISE Report #${ISE_REPORT_NUM}" "0th-draft" || exit 1

# Registry Manager連携（INDIVIDUAL_MODEでない場合のみ）
if ! [[ "$INDIVIDUAL_MODE" =~ ^(true|TRUE|1|yes|YES)$ ]]; then
    run_registry_integration "ise"
fi

# 完了メッセージ
print_completion_message "📝 Pull Request学習を開始してください：
  1. GitHub Desktop または VS Code でリポジトリを開く
  2. 作業用ブランチ（1st-draft など）を作成
  3. index.html を編集してレポート作成
  4. 変更をコミット・プッシュ
  5. Pull Request を作成して提出
  6. レビューフィードバックを確認・対応

📖 詳細な手順: リポジトリの README.md をご確認ください"
