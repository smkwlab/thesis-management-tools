#!/bin/bash
# 学生リポジトリセットアップスクリプト（統合版）
#
# 5 種類の文書タイプ（thesis / wr / latex / ise / poster）のリポジトリ作成を
# 1 本で担う。タイプは環境変数 DOC_TYPE で選択する（setup.sh が
# docker run -e DOC_TYPE=... で注入。位置引数 $1 は従来どおり学籍番号）。
#
# 設計基準（Issue #516）:
# - タイプ固有処理は「タイプ設定 case」「テンプレート決定 case」と、タイプ名で
#   明示的に分岐する case / if のみで表現する。eval や "func_$DOC_TYPE" 式の
#   動的関数名解決は使わない。
# - grep -n 'DOC_TYPE' main.sh でタイプ固有処理を全列挙できる。
# - 各ブロックは旧 main-<type>.sh からの逐語移設であり、対話プロンプト・
#   コミットメッセージ・完了メッセージ・ログ文言を変えないこと。
# - タイプ固有関数は REPO_NAME / COMMIT_MESSAGE 等の決められた変数の設定のみを
#   行い、共通フローの順序に依存する副作用を持たない。タイプ固有処理の追加は
#   case か DOC_TYPE ガードで行うこと（線形フローへの無秩序な if 増殖を避ける）。

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# ================================
# 文書タイプの検証
# ================================
# setup.sh 側の case でも whitelist 済みだが、コンテナを setup.sh 経由せず
# 直接実行するデバッグ経路でも安全にするため二重に検証する
# （AUTO_ASSIGN_REVIEWER の二重検証と同じ既存流儀）。
DOC_TYPE="${DOC_TYPE:?DOC_TYPE を指定してください (thesis|wr|latex|ise|poster)}"

# ================================
# タイプ設定（静的コンフィグ）
# ================================
# SCRIPT_TITLE / SCRIPT_EMOJI: init_script_common の引数
# STUDENT_ID_EXAMPLES: 学籍番号プロンプトの例示（空なら read_student_id の既定）
# RUN_ALDC: aldc による LaTeX 環境セットアップを行うか（ise は HTML ベースのため行わない）
# SETUP_AUTO_ASSIGN: 組織メンバー向け auto-assign 設定を追加するか（thesis / ise）
# USE_DRAFT_FLOW: main + 0th-draft のドラフトレビューワークフローを使うか（thesis / ise）
case "$DOC_TYPE" in
    thesis)
        SCRIPT_TITLE="論文リポジトリセットアップツール"
        SCRIPT_EMOJI="🎓"
        STUDENT_ID_EXAMPLES="卒業論文の例: k21rs001, 修士論文の例: k21gjk01"
        RUN_ALDC=true
        SETUP_AUTO_ASSIGN=true
        USE_DRAFT_FLOW=true
        ;;
    wr)
        SCRIPT_TITLE="週報リポジトリセットアップツール"
        SCRIPT_EMOJI="📝"
        STUDENT_ID_EXAMPLES=""
        RUN_ALDC=true
        SETUP_AUTO_ASSIGN=false
        USE_DRAFT_FLOW=false
        ;;
    latex)
        SCRIPT_TITLE="汎用LaTeXリポジトリセットアップツール"
        SCRIPT_EMOJI="📝"
        STUDENT_ID_EXAMPLES=""
        RUN_ALDC=true
        SETUP_AUTO_ASSIGN=false
        USE_DRAFT_FLOW=false
        ;;
    ise)
        SCRIPT_TITLE="情報科学演習レポートリポジトリセットアップツール"
        SCRIPT_EMOJI="📝"
        STUDENT_ID_EXAMPLES=""
        RUN_ALDC=false
        SETUP_AUTO_ASSIGN=true
        USE_DRAFT_FLOW=true
        ;;
    poster)
        SCRIPT_TITLE="学会ポスターリポジトリセットアップツール"
        SCRIPT_EMOJI="📊"
        STUDENT_ID_EXAMPLES=""
        RUN_ALDC=true
        SETUP_AUTO_ASSIGN=false
        USE_DRAFT_FLOW=false
        ;;
    *)
        die "サポートされていない文書タイプ: $DOC_TYPE (thesis|wr|latex|ise|poster)"
        ;;
esac

# 共通初期化
init_script_common "$SCRIPT_TITLE" "$SCRIPT_EMOJI"

# ================================
# 設定
# ================================
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの決定。全タイプで TEMPLATE_REPO による上書きに対応する
# （setup.sh はタイプ非依存で TEMPLATE_REPO をコンテナへ転送する）。既定値のみ
# タイプごとにポリシーが異なり、「既定値の由来」で 2 グループに分かれる（この分類は
# 下の case の並び順とは独立。case はファイル全体で統一している標準順
# thesis→wr→latex→ise→poster を維持しているため、latex はグループ間に挟まって見える）:
# - org 追従（${ORGANIZATION}/<template>） … thesis / wr / ise
# - smkwlab 固定 … latex / poster（個人ユーザー = ORGANIZATION が個人アカウントでも
#   利用する共有テンプレのため、org 追従にせず既定を smkwlab に固定する）
# いずれのグループも、他 org で独自テンプレを使う場合は TEMPLATE_REPO で上書きする。
# 注意: TEMPLATE_REPO 未設定時の既定は従来と同一（挙動不変）。以前は wr / ise のみ
# TEMPLATE_REPO を無視していた（silent ignore）が、Issue #517 で全タイプ上書き可に統一。
case "$DOC_TYPE" in
    thesis) TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/sotsuron-template}" ;;
    wr)     TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/wr-template}" ;;
    latex)  TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-smkwlab/latex-template}" ;;
    ise)    TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-${ORGANIZATION}/ise-report-template}" ;;
    poster) TEMPLATE_REPOSITORY="${TEMPLATE_REPO:-smkwlab/poster-template}" ;;
esac
VISIBILITY="private"

log_info "テンプレートリポジトリ: $TEMPLATE_REPOSITORY"

# 学籍番号の取得（INDIVIDUAL_MODE のときはスキップして空文字）
STUDENT_ID=$(read_student_id_if_needed "$1" "$STUDENT_ID_EXAMPLES") || exit 1

# ================================
# タイプ固有関数群（旧 main-<type>.sh から逐語移設）
# ================================

# --- thesis: 論文タイプの判定（旧 main-thesis.sh） ---
determine_thesis_type() {
    local student_id="$1"
    # kxxの次の文字がgの場合は修士論文、それ以外は卒業論文
    if echo "$student_id" | grep -qE '^k[0-9]{2}g'; then
        echo "shuuron"
    else
        echo "sotsuron"
    fi
}

# --- latex: ドキュメント名の入力（旧 main-latex.sh） ---
read_document_name() {
    if [ -n "$DOCUMENT_NAME" ]; then
        log_info "ドキュメント名: $DOCUMENT_NAME（環境変数指定）"
        return 0
    fi

    echo ""
    echo "📝 ドキュメント名を入力してください (デフォルト: latex):"
    echo "   例: research-note, report2024, experiment-log"
    read -r -p "> " DOCUMENT_NAME

    DOCUMENT_NAME="${DOCUMENT_NAME:-latex}"

    if ! [[ "$DOCUMENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "ドキュメント名は英数字、ハイフン、アンダースコアのみ使用可能です"
        DOCUMENT_NAME=""
        read_document_name
    fi
}

# --- poster: ポスター名の入力（旧 main-poster.sh） ---
read_poster_name() {
    if [ -n "$POSTER_NAME" ]; then
        log_info "ポスター名: $POSTER_NAME（環境変数指定）"
        return 0
    fi

    if [ -n "$DOCUMENT_NAME" ]; then
        POSTER_NAME="$DOCUMENT_NAME"
        log_info "ポスター名: $POSTER_NAME（環境変数指定）"
        return 0
    fi

    echo ""
    echo "📊 ポスター名を入力してください (デフォルト: poster):"
    echo "   例: jxiv2025-poster, conference2024, symposium-poster"
    read -r -p "> " POSTER_NAME

    POSTER_NAME="${POSTER_NAME:-poster}"

    if ! [[ "$POSTER_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "ポスター名は英数字、ハイフン、アンダースコアのみ使用可能です"
        POSTER_NAME=""
        read_poster_name
    fi
}

# --- ise: ISE レポート番号の決定とリポジトリ存在チェック（日時ベース） ---
# 実装メモ（Issue #520 で修正）:
# - 学期判定は日本の学期基準のため JST で行う（`TZ='JST-9'`）。Alpine busybox の date は
#   tzdata 無しでも POSIX offset 形式 `JST-9`（UTC+9・DST なし）を解釈できる。
# - `date +%m` はゼロ埋め（08/09）で、算術文脈 `(( ))` では 8 進数と解釈されエラーに
#   なるため、比較は `10#` で 10 進を強制する。
# - `local var=$(cmd)` は local 自体の終了コード（常に 0）で `$?` を潰す（SC2155）。
#   API エラー分岐を機能させるため、宣言と代入を分離して `$?` が gh の終了コードを
#   拾うようにしている。
determine_ise_report_number() {
    local student_id="$1"
    local report_num

    # 環境変数による手動制御をチェック
    if [ -n "$ISE_REPORT_NUM" ] && [ "$ISE_REPORT_NUM" != "auto" ]; then
        if [ "$ISE_REPORT_NUM" = "1" ] || [ "$ISE_REPORT_NUM" = "2" ]; then
            local target_repo="${ORGANIZATION}/${student_id}-ise-report${ISE_REPORT_NUM}"
            local api_result
            api_result=$(gh api "repos/${target_repo}" --jq .name 2>&1)
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

    # 学期判定（日本の学期基準のため JST。busybox は tzdata 無しでも JST-9 を解釈する）
    # SC2155 回避のため宣言と代入を分離する（他の gh api 呼び出しと同じ流儀）
    local current_month
    current_month=$(TZ='JST-9' date +%m)
    # date 失敗で空になると後段の `(( 10#$current_month ... ))` が算術構文エラーになるため、
    # 空でないことを保証する（現実にはまず失敗しないが防御的に）
    [ -n "$current_month" ] || die "学期判定の日付取得に失敗しました"
    local preferred_num fallback_num

    # 10# でゼロ埋め月（08/09）の 8 進誤解釈を防ぐ
    if (( 10#$current_month >= 4 && 10#$current_month <= 9 )); then
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
    local api_result
    api_result=$(gh api "repos/${preferred_repo}" --jq .name 2>&1)
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
        local fallback_result
        fallback_result=$(gh api "repos/${fallback_repo}" --jq .name 2>&1)
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

# --- リポジトリ名の決定（全タイプ。旧 main-<type>.sh の該当ブロックを逐語移設） ---
# 設定される変数: REPO_NAME、および thesis: THESIS_TYPE / ise: ISE_REPORT_NUM /
# latex: DOCUMENT_NAME / poster: POSTER_NAME
# 注意: bare call で呼ぶこと（`decide_repo_name || ...` にしない）。ise 分岐の
# `ISE_REPORT_NUM=$(determine_ise_report_number ...)` は、determine_ise_report_number
# が異常時に呼ぶ `exit 1` がコマンド置換のサブシェルのみを終了させるため、失敗した
# 代入を set -e が拾って親スクリプトを中断することに依存している（旧 main-ise.sh
# L123 のトップレベル代入と同じ挙動）。`|| ...` 文脈で呼ぶと関数内の set -e が
# 無効化され、ISE_REPORT_NUM 空のまま続行してしまう。
decide_repo_name() {
    case "$DOC_TYPE" in
        wr)
            if is_individual_mode; then
                REPO_NAME="weekly-report"
            else
                REPO_NAME="${STUDENT_ID}-wr"
            fi
            ;;
        latex)
            read_document_name
            if is_individual_mode; then
                REPO_NAME="${DOCUMENT_NAME}"
            else
                REPO_NAME="${STUDENT_ID}-${DOCUMENT_NAME}"
            fi
            ;;
        poster)
            read_poster_name
            if is_individual_mode; then
                REPO_NAME="${POSTER_NAME}"
            else
                REPO_NAME="${STUDENT_ID}-${POSTER_NAME}"
            fi
            ;;
        thesis)
            if is_individual_mode; then
                THESIS_TYPE="sotsuron"
                REPO_NAME="thesis"
                log_info "個人モード: 卒業論文リポジトリとして設定します"
            else
                THESIS_TYPE=$(determine_thesis_type "$STUDENT_ID")
                if [ "$THESIS_TYPE" = "shuuron" ]; then
                    REPO_NAME="${STUDENT_ID}-master"
                    log_info "修士論文リポジトリとして設定します"
                else
                    REPO_NAME="${STUDENT_ID}-sotsuron"
                    log_info "卒業論文リポジトリとして設定します"
                fi
            fi
            ;;
        ise)
            if is_individual_mode; then
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
            ;;
        *)
            # 冒頭の case で不正値は die 済みだが、単体テストや将来のタイプ追加時に
            # REPO_NAME 未設定のまま後続へ進むのを防ぐ（内部整合の防御）
            die "内部エラー: decide_repo_name が未知の DOC_TYPE を受け取りました: $DOC_TYPE"
            ;;
    esac
}

# --- thesis: 論文タイプに応じて不要なファイルを削除（旧 main-thesis.sh） ---
remove_unused_thesis_files() {
    if [ "$THESIS_TYPE" = "shuuron" ]; then
        rm -f sotsuron.tex gaiyou.tex example.tex example-gaiyou.tex 2>/dev/null || true
        log_debug "修士論文用: sotsuron.tex, gaiyou.tex, example.tex, example-gaiyou.tex を削除しました"
    else
        rm -f thesis.tex abstract.tex 2>/dev/null || true
        log_debug "卒業論文用: thesis.tex, abstract.tex を削除しました"
    fi
}

# --- コミットメッセージの決定（全タイプ。旧 main-<type>.sh から逐語移設） ---
# 学生リポジトリの初期履歴に残る文字列のため、文言・空行・改行を 1 文字も
# 変えないこと。設定される変数: COMMIT_MESSAGE
build_commit_message() {
    case "$DOC_TYPE" in
        wr)
            if is_individual_mode; then
                COMMIT_MESSAGE="Initialize weekly report repository

- Setup LaTeX environment for weekly reports
"
            else
                COMMIT_MESSAGE="Initialize weekly report repository for ${STUDENT_ID}

- Setup LaTeX environment for weekly reports
"
            fi
            ;;
        latex)
            COMMIT_MESSAGE="Initial customization for ${DOCUMENT_NAME}

- Setup LaTeX environment
"
            ;;
        poster)
            COMMIT_MESSAGE="Initial setup for ${POSTER_NAME}

- Configure LaTeX environment
- Remove template documentation files
- Prepare for poster development"
            ;;
        thesis)
            COMMIT_MESSAGE="Initial setup for ${THESIS_TYPE}"
            ;;
        ise)
            COMMIT_MESSAGE="Initial setup for ISE Report #${ISE_REPORT_NUM}"
            ;;
        *)
            die "内部エラー: build_commit_message が未知の DOC_TYPE を受け取りました: $DOC_TYPE"
            ;;
    esac
}

# --- 完了メッセージ（全タイプ。旧 main-<type>.sh から逐語移設） ---
print_next_steps() {
    case "$DOC_TYPE" in
        wr)
            print_completion_message "次のステップ:
1. テンプレートファイル (20yy-mm-dd.tex) をコピーして、日付に基づいたファイル名 (例: 2024-04-01.tex) に変更後、編集
2. git add, commit, pushで変更を保存
3. 毎週新しい週報ファイルを追加"
            ;;
        latex)
            print_completion_message "次のステップ:
1. main.texを編集して文書を作成
2. git add, commit, pushで変更を保存
3. GitHub Actionsで自動的にPDFが生成されます"
            ;;
        poster)
            print_completion_message "次のステップ:
1. a0poster.texを編集してポスターを作成
2. git add, commit, pushで変更を保存
3. GitHub Actionsで自動的にPDFが生成されます

ポスターテンプレートの特徴:
- A0サイズ学会ポスター用
- tikzposterによる柔軟なレイアウト
- LuaLaTeXで日本語完全対応
- 複数のテーマとスタイルから選択可能"
            ;;
        thesis)
            print_completion_message "論文執筆の開始方法:
  https://github.com/$REPO_PATH/blob/main/WRITING-GUIDE.md"
            ;;
        ise)
            print_completion_message "Pull Request学習を開始してください：
  1. GitHub Desktop または VS Code でリポジトリを開く
  2. 作業用ブランチ（1st-draft など）を作成
  3. index.html を編集してレポート作成
  4. 変更をコミット・プッシュ
  5. Pull Request を作成して提出
  6. レビューフィードバックを確認・対応

📖 詳細な手順: リポジトリの README.md をご確認ください"
            ;;
        *)
            die "内部エラー: print_next_steps が未知の DOC_TYPE を受け取りました: $DOC_TYPE"
            ;;
    esac
}

# ================================
# メインフロー
# ================================
# 5 タイプの処理列はすべて thesis の順序（aldc → タイプ固有削除 → auto-assign →
# 組織外ワークフロー削除 → cleanup → コミット → registry）の部分列であり、
# 順序の入れ替えなしにフラグガード付きの単一線形フローで全タイプを表現できる。

# リポジトリ名の決定
decide_repo_name

# 標準セットアップフロー
run_standard_setup "$DOC_TYPE"

# LaTeX環境のセットアップ（ise は HTML ベースのため実行しない）
# 注意: bare call のまま維持すること。set -e 下で aldc 失敗 = スクリプト終了が
# 現行挙動であり、|| true や条件式への組み込みは挙動を変えるため禁止。
if [ "$RUN_ALDC" = true ]; then
    setup_latex_environment
fi

# 論文タイプに応じて不要なファイルを削除
if [ "$DOC_TYPE" = "thesis" ]; then
    remove_unused_thesis_files
fi

# smkwlab 組織メンバーの場合は auto-assign 設定を追加
if [ "$SETUP_AUTO_ASSIGN" = true ]; then
    setup_auto_assign_for_organization_members
fi

# 組織外ユーザーの場合は組織専用ワークフローを削除
remove_org_specific_workflows

# テンプレートファイルの整理（aldc 実行後に行う必要がある: Issue #433）
# ise は aldc 非実行のため *-aldc は無いが、テンプレート由来の CLAUDE.md / docs/
# の削除が必要なのは同じ（Issue #433）
cleanup_template_files

# 変更をコミットしてプッシュ
build_commit_message

if [ "$USE_DRAFT_FLOW" = true ]; then
    # main へのセットアップコミット → 0th-draft 作成 → 初期ドラフト commit/push。
    # 注意: bare call 必須（|| exit 1 を付けると関数内の set -e が無効化される。
    # 詳細は common-lib.sh の finalize_with_draft_flow を参照）
    finalize_with_draft_flow "$COMMIT_MESSAGE"
else
    commit_and_push "$COMMIT_MESSAGE" || exit 1
fi

# Registry Manager連携（INDIVIDUAL_MODEでない場合のみ）
if ! is_individual_mode; then
    if [ "$DOC_TYPE" = "thesis" ]; then
        # registry の正式語彙へ変換（内部値 shuuron はテンプレート整理用、issue #471）
        if [ "$THESIS_TYPE" = "shuuron" ]; then
            run_registry_integration "master"
        else
            run_registry_integration "$THESIS_TYPE"
        fi
    else
        run_registry_integration "$DOC_TYPE"
    fi
fi

# 完了メッセージ
print_next_steps
