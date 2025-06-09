#!/bin/bash

# 下川研論文リポジトリ一括作成スクリプト
# 使用例: 
#   卒業論文: ./create-student-repos.sh k21rs001 k21rs002 k21rs003
#   修士論文: ./create-student-repos.sh k21gjk01 k21gjk02
#   メール送信: ./create-student-repos.sh --send-mail k21rs001 k21rs002
#   カスタムドメイン: ./create-student-repos.sh --send-mail --mail-domain @example.com k21rs001

set -e  # エラー時に終了

# デフォルト設定
SEND_MAIL=false
MAIL_DOMAIN="@st.kyusan-u.ac.jp"
DRY_RUN=false
TEST_MAIL=""
STUDENT_IDS=()

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --send-mail)
            SEND_MAIL=true
            shift
            ;;
        --mail-domain)
            MAIL_DOMAIN="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --mail-test)
            TEST_MAIL="$2"
            shift 2
            ;;
        --help|-h)
            echo "使用方法: $0 [オプション] <学籍番号1> <学籍番号2> ..."
            echo ""
            echo "オプション:"
            echo "  --send-mail                 リポジトリ作成後に学生にメール送信"
            echo "  --mail-domain <ドメイン>    メールドメインを指定 (デフォルト: @st.kyusan-u.ac.jp)"
            echo "  --mail-test <アドレス>      全メールを指定アドレスに送信（動作確認用）"
            echo "  -n, --dry-run               実際に作成せず、実行内容のみ表示"
            echo "  --help, -h                  このヘルプを表示"
            echo ""
            echo "例:"
            echo "  基本使用: $0 k21rs001 k21rs002 k21rs003"
            echo "  メール送信: $0 --send-mail k21rs001 k21rs002"
            echo "  カスタムドメイン: $0 --send-mail --mail-domain @example.com k21rs001"
            echo "  テストメール: $0 --send-mail --mail-test admin@example.com k21rs001"
            echo "  ドライラン: $0 -n k21rs001 k21rs002"
            echo ""
            echo "対応する学籍番号の形式:"
            echo "  卒業論文: k??rs??? (例: k21rs001)"
            echo "  修士論文: k??gjk?? (例: k21gjk01)"
            exit 0
            ;;
        -*)
            echo "エラー: 不明なオプション $1"
            echo "ヘルプ: $0 --help"
            exit 1
            ;;
        *)
            STUDENT_IDS+=("$1")
            shift
            ;;
    esac
done

# 学籍番号チェック
if [ ${#STUDENT_IDS[@]} -eq 0 ]; then
    echo "エラー: 学籍番号が指定されていません"
    echo ""
    echo "使用方法: $0 [オプション] <学籍番号1> <学籍番号2> ..."
    echo "例（卒業論文）: $0 k21rs001 k21rs002 k21rs003"
    echo "例（修士論文）: $0 k21gjk01 k21gjk02"
    echo "例（メール送信）: $0 --send-mail k21rs001 k21rs002"
    echo ""
    echo "対応する学籍番号の形式:"
    echo "  卒業論文: k??rs??? (例: k21rs001)"
    echo "  修士論文: k??gjk?? (例: k21gjk01)"
    echo ""
    echo "詳細: $0 --help"
    exit 1
fi

# 設定
ORGANIZATION="smkwlab"

# --mail-test が --send-mail なしで使われた場合のチェック
if [ -n "$TEST_MAIL" ] && [ "$SEND_MAIL" = false ]; then
    echo "エラー: --mail-test は --send-mail と併用してください"
    echo "例: $0 --send-mail --mail-test admin@example.com k21rs001"
    exit 1
fi

echo "=== 下川研論文リポジトリ作成スクリプト ==="
echo "作成対象: ${#STUDENT_IDS[@]} 個のリポジトリ"
if [ "$DRY_RUN" = true ]; then
    echo "実行モード: ドライラン（実際には作成しません）"
else
    echo "実行モード: 本番実行"
fi
if [ "$SEND_MAIL" = true ]; then
    if [ -n "$TEST_MAIL" ]; then
        echo "メール送信: 有効 (テストモード: $TEST_MAIL へ全て送信)"
    else
        echo "メール送信: 有効 (ドメイン: $MAIL_DOMAIN)"
    fi
else
    echo "メール送信: 無効"
fi
echo ""

# GitHub CLI認証確認（ドライランでは不要）
if [ "$DRY_RUN" = false ] && ! gh auth status >/dev/null 2>&1; then
    echo "エラー: GitHub CLIの認証が必要です"
    echo "以下のコマンドで認証してください:"
    echo "  gh auth login"
    exit 1
fi

# メール送信用前提条件チェック（ドライランでは不要）
if [ "$SEND_MAIL" = true ] && [ "$DRY_RUN" = false ]; then
    # mailコマンドの存在確認
    if ! command -v mail >/dev/null 2>&1; then
        echo "エラー: メール送信には 'mail' コマンドが必要です"
        echo "macOS: brew install mailutils"
        echo "Ubuntu/Debian: sudo apt-get install mailutils"
        echo "CentOS/RHEL: sudo yum install mailx"
        exit 1
    fi
    
    echo "メール送信の準備完了"
elif [ "$SEND_MAIL" = true ] && [ "$DRY_RUN" = true ]; then
    echo "メール送信: ドライランモード（実際には送信しません）"
fi

# 学籍番号のパターン判定と設定取得関数
get_repo_config() {
    local student_id="$1"
    
    if [[ "$student_id" =~ ^k[0-9]{2}rs[0-9]{3}$ ]]; then
        # 卒業論文
        echo "卒業論文"
        echo "sotsuron"
        return 0
    elif [[ "$student_id" =~ ^k[0-9]{2}gjk[0-9]{2}$ ]]; then
        # 修士論文
        echo "修士論文"
        echo "master"
        return 0
    else
        echo "INVALID"
        echo "INVALID"
        return 1
    fi
}

# 学籍番号の形式チェック関数
validate_student_id() {
    local student_id="$1"
    local config=($(get_repo_config "$student_id"))
    
    if [ "${config[0]}" = "INVALID" ]; then
        echo "警告: '$student_id' は対応する学籍番号の形式と一致しません"
        echo "対応形式: k??rs??? (卒業論文) または k??gjk?? (修士論文)"
        return 1
    fi
    return 0
}

# LaTeX devcontainer 追加関数
setup_devcontainer() {
    local student_id="$1"
    local repo_suffix="$2"
    local repo_dir="${student_id}-${repo_suffix}"
    
    # ローカルリポジトリディレクトリが存在するかチェック
    if [ ! -d "$repo_dir" ]; then
        echo "エラー: ローカルリポジトリディレクトリが見つかりません: $repo_dir"
        return 1
    fi
    
    # リポジトリディレクトリに移動
    cd "$repo_dir" || return 1
    
    # aldcを実行してdevcontainerを追加
    echo "aldcスクリプトを実行中..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)"; then
        # aldc実行後の一時ファイルを削除
        echo "一時ファイルを削除中..."
        find . -name "*-aldc" -type f -delete 2>/dev/null || true
        
        # 変更をcommit & push
        if [ -d ".devcontainer" ]; then
            git add .
            git commit -m "Add LaTeX devcontainer using aldc"
            git push origin main
            echo "✓ devcontainer をmainブランチに追加しました"
        else
            echo "警告: .devcontainerディレクトリが作成されませんでした"
            cd ..
            return 1
        fi
    else
        echo "エラー: aldc の実行に失敗しました"
        cd ..
        return 1
    fi
    
    # 元のディレクトリに戻る
    cd ..
    return 0
}

# レビュー用PR初期設定関数
setup_review_pr() {
    local student_id="$1"
    local repo_suffix="$2"
    local repo_dir="${student_id}-${repo_suffix}"
    
    # ローカルリポジトリディレクトリが存在するかチェック
    if [ ! -d "$repo_dir" ]; then
        echo "エラー: ローカルリポジトリディレクトリが見つかりません: $repo_dir"
        return 1
    fi
    
    # リポジトリディレクトリに移動
    cd "$repo_dir" || return 1
    
    # 初期状態を保持するブランチを作成（レビュー用PRのベースとして使用）
    if ! git checkout -b initial-empty; then
        echo "エラー: initial-emptyの作成に失敗"
        cd ..
        return 1
    fi
    
    # initial-emptyをリモートにプッシュ
    if ! git push -u origin initial-empty; then
        echo "エラー: initial-emptyのプッシュに失敗"
        cd ..
        return 1
    fi
    
    # 0th-draft ブランチ作成（目次案用）
    if ! git checkout -b 0th-draft initial-empty; then
        echo "エラー: 0th-draftの作成に失敗"
        cd ..
        return 1
    fi
    
    # 0th-draftをリモートにプッシュ
    if ! git push -u origin 0th-draft; then
        echo "エラー: 0th-draftのプッシュに失敗"
        cd ..
        return 1
    fi
    
    # レビュー用ブランチを初期状態ベースで作成
    if ! git checkout -b review-branch initial-empty; then
        echo "エラー: review-branchの作成に失敗"
        cd ..
        return 1
    fi
    
    # レビュー用ブランチをリモートにプッシュ
    if ! git push -u origin review-branch; then
        echo "エラー: review-branchのプッシュに失敗"
        cd ..
        return 1
    fi
    
    # review-branchに空のコミットを作成（PR作成のため）
    git commit --allow-empty -m "【自動作成】論文全体への添削コメント用ブランチです"
    git push
    
    # レビュー用PR作成（initial-emptyベース）
    if gh pr create \
        --base initial-empty \
        --head review-branch \
        --title "【レビュー用】論文全体へのコメント" \
        --body "$(cat <<EOF
## 📋 このPRについて

この Pull Request は **論文全体への添削コメント用** です。
システムが自動的に作成・管理しています。

## 👨‍🎓 学生の皆さんへ

### 🚫 重要な注意事項
⚠️ **このPRは絶対にマージしないでください** ⚠️
- このPRは添削専用で、最終提出まで開いたままにしておきます
- 教員からのコメントを確認するためのものです

### 📝 PRの役割の違い
| PRの種類 | 用途 | あなたがすること |
|---------|-----|----------------|
| **各稿のPR** (1st-draft等) | 前回からの変更点への指摘 | PR作成→添削確認→自分でクローズ |
| **このPR** | 論文全体・構成への指摘 | 添削内容を確認のみ |

### 🔄 作業の流れ
1. あなたが**各稿のPR**を作成（例：1st-draft PR）
2. **次稿の執筆開始**（添削完了を待たずに並行作業可能）
3. 教員が添削（各稿PR + このレビューPR）
4. あなたが添削を確認
5. **各稿のPRのみ**を自分でクローズ（「Close pull request」ボタン）
6. **このレビューPRは最後まで開いたまま**（絶対にクローズしない）

### 💡 Suggestion機能の使い方
教員からSuggestion（修正提案）があった場合：
1. 「Apply suggestion」ボタンで修正を適用
2. 「Re-request review」で教員に確認依頼
3. 教員確認後、上記の手順5と同様に**各稿のPRのみ**をクローズ

## 👨‍🏫 教員の皆さんへ

### 📌 コメントの使い分け
- **各稿のPR**: 直前版からの変更点・新規追加部分
- **このPR**: 論文全体の構成・以前の部分への追加指摘

### 🔄 自動更新
学生がPRを作成するたびに、GitHub Actionsが自動的にこのPRを最新版に更新します。

---

📖 **詳細なガイド**: [WRITING-GUIDE.md](https://github.com/smkwlab/sotsuron-template/blob/main/WRITING-GUIDE.md)
EOF
)"; then
        echo "✓ レビュー用PR作成成功"
    else
        echo "⚠ レビュー用PRの作成に失敗（手動作成が必要）"
    fi
    
    # PR番号を取得してラベルを設定
    local pr_number
    pr_number=$(gh pr list --head review-branch --json number --jq '.[0].number')
    
    if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
        # do-not-mergeラベルを作成（存在しない場合）
        gh label create "do-not-merge" --color "d73a4a" --description "このPRはマージしないでください" 2>/dev/null || true
        
        # ラベルを設定
        gh pr edit "$pr_number" --add-label "do-not-merge"
    fi
    
    # 学生が作業しやすいように0th-draftに戻しておく
    git checkout 0th-draft
    echo "✓ 学生用に0th-draftブランチに戻しました"
    
    # 元のディレクトリに戻る
    cd ..
    
    return 0
}

# 論文タイプ別不要ファイル削除関数
cleanup_template_files() {
    local student_id="$1"
    local repo_suffix="$2"
    local repo_dir="${student_id}-${repo_suffix}"
    
    # ローカルリポジトリディレクトリが存在するかチェック
    if [ ! -d "$repo_dir" ]; then
        echo "エラー: ローカルリポジトリディレクトリが見つかりません: $repo_dir"
        return 1
    fi
    
    # リポジトリディレクトリに移動
    cd "$repo_dir" || return 1
    
    # mainブランチに切り替え（念のため）
    git checkout main >/dev/null 2>&1
    
    if [ "$repo_suffix" = "sotsuron" ]; then
        # 卒業論文: 修士論文用ファイルを削除
        echo "卒業論文用に設定中: 修士論文ファイルを削除..."
        rm -f thesis.tex abstract.tex
        echo "✓ thesis.tex, abstract.tex を削除"
    elif [ "$repo_suffix" = "master" ]; then
        # 修士論文: 卒業論文用ファイルを削除  
        echo "修士論文用に設定中: 卒業論文ファイルを削除..."
        rm -f sotsuron.tex gaiyou.tex example.tex example-gaiyou.tex
        echo "✓ sotsuron.tex, gaiyou.tex, example.tex, example-gaiyou.tex を削除"
    fi
    
    # 変更をcommit
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "Setup ${repo_suffix} thesis template"
        git push origin main
        echo "✓ 不要ファイル削除をcommit & push完了"
    else
        echo "削除対象ファイルが見つかりませんでした"
    fi
    
    # 元のディレクトリに戻る
    cd ..
    return 0
}

# メール送信関数
send_notification_email() {
    local student_id="$1"
    local thesis_type="$2"
    local repo_name="$3"
    local repo_url="https://github.com/$repo_name"
    
    # 実際の送信先アドレスを決定
    local email_address
    local original_address="${student_id}${MAIL_DOMAIN}"
    
    if [ -n "$TEST_MAIL" ]; then
        email_address="$TEST_MAIL"
        # テストモードではsubjectに元の宛先を明記
        local subject="【論文指導】GitHubリポジトリを作成しました - ${student_id} (本来の宛先: ${original_address})"
    else
        email_address="$original_address"
        local subject="【論文指導】GitHubリポジトリを作成しました - ${student_id}"
    fi
    
    # メール本文を作成
    local email_body
    if [ -n "$TEST_MAIL" ]; then
        email_body=$(cat <<EOF
【テストメール】
本来の宛先: ${original_address}
実際の送信先: ${email_address}

---

${student_id} さん

下川研究室論文指導システムです。

${thesis_type}用のGitHubリポジトリを作成しました。
EOF
)
    else
        email_body=$(cat <<EOF
${student_id} さん

下川研究室論文指導システムです。

${thesis_type}用のGitHubリポジトリを作成しました。
EOF
)
    fi
    
    # 共通の本文を追加
    email_body="${email_body}$(cat <<EOF

## リポジトリ情報
- 学籍番号: ${student_id}
- 論文種別: ${thesis_type}
- リポジトリURL: ${repo_url}

## 次のステップ

1. **GitHub Desktop のインストール**
   https://desktop.github.com/ からダウンロード・インストール

2. **リポジトリのクローン**
   - 上記URLにアクセス
   - 「Code」→「Open with GitHub Desktop」をクリック
   - 適切な場所にクローン

3. **VS Code での編集開始**
   - GitHub Desktop で「Open in Visual Studio Code」をクリック
   - 自動的に LaTeX 環境が構築されます

4. **論文執筆の開始**
   - 0th-draft ブランチで目次案を作成
   - コミット・プッシュ後、Pull Request を作成
   - 添削を受けて次の稿へ進む

## 重要な注意事項

- **PRはマージしません**: 添削専用です。対応完了後は自分でクローズしてください
- **並行作業可能**: 前の稿の添削を待たずに次の稿を開始できます
- **定期的なバックアップ**: こまめにコミット・プッシュを行ってください

## 詳細なガイド

詳しい使用方法は以下をご確認ください：
https://github.com/smkwlab/sotsuron-template/blob/main/WRITING-GUIDE.md

質問がある場合は、smkwlabML または担当教員まで連絡してください。

---
下川研究室論文指導システム
自動送信メール
EOF
)"
    
    echo "メール送信中: $email_address"
    
    # メール送信実行
    if echo "$email_body" | mail -s "$subject" "$email_address"; then
        echo "✓ メール送信成功: $email_address"
        return 0
    else
        echo "✗ メール送信失敗: $email_address"
        return 1
    fi
}

# 各学生のリポジトリ作成
success_count=0
error_count=0
created_repos=()

for student_id in "${STUDENT_IDS[@]}"; do
    echo "--- 処理中: $student_id ---"
    
    # 学籍番号形式チェック
    if ! validate_student_id "$student_id"; then
        echo "スキップします"
        ((error_count++))
        continue
    fi
    
    # 設定取得
    config=($(get_repo_config "$student_id"))
    thesis_type="${config[0]}"
    repo_suffix="${config[1]}"
    template_repo="smkwlab/sotsuron-template"
    
    repo_name="${ORGANIZATION}/${student_id}-${repo_suffix}"
    
    echo "論文種別: $thesis_type"
    
    # リポジトリ存在チェック（ドライランでは実際にチェックしない）
    if [ "$DRY_RUN" = false ] && gh repo view "$repo_name" >/dev/null 2>&1; then
        echo "警告: リポジトリ '$repo_name' は既に存在します"
        echo "スキップします"
        ((error_count++))
        continue
    fi
    
    # リポジトリ作成
    echo "リポジトリを作成中: $repo_name"
    if [ "$DRY_RUN" = true ]; then
        echo "[ドライラン] 実行コマンド: gh repo create $repo_name --template $template_repo --private --clone --description '${student_id}の${thesis_type}'"
        echo "✓ [ドライラン] 作成成功: https://github.com/$repo_name"
        repo_creation_success=true
    elif gh repo create "$repo_name" \
        --template "$template_repo" \
        --private \
        --clone \
        --description "${student_id}の${thesis_type}"; then
        echo "✓ 作成成功: https://github.com/$repo_name"
        repo_creation_success=true
    else
        echo "✗ 作成失敗: $repo_name"
        repo_creation_success=false
    fi
    
    if [ "$repo_creation_success" = true ]; then
        # 不要なテンプレートファイルを削除
        echo "論文タイプ別ファイル調整中..."
        if [ "$DRY_RUN" = true ]; then
            echo "[ドライラン] 不要ファイル削除処理をスキップ"
            echo "✓ [ドライラン] 不要ファイル削除完了"
        elif cleanup_template_files "$student_id" "$repo_suffix"; then
            echo "✓ 不要ファイル削除完了"
        else
            echo "⚠ ファイル削除に失敗（手動削除が必要）"
        fi
        
        # LaTeX devcontainer の追加
        echo "LaTeX devcontainer を追加中..."
        if [ "$DRY_RUN" = true ]; then
            echo "[ドライラン] devcontainer 追加処理をスキップ"
            echo "✓ [ドライラン] devcontainer 追加完了"
        elif setup_devcontainer "$student_id" "$repo_suffix"; then
            echo "✓ devcontainer 追加完了"
        else
            echo "⚠ devcontainer 追加に失敗（手動設定が必要）"
        fi
        
        # レビュー用PRの初期設定
        echo "レビュー用PRを設定中..."
        if [ "$DRY_RUN" = true ]; then
            echo "[ドライラン] レビュー用PR設定処理をスキップ"
            echo "✓ [ドライラン] レビュー用PR設定完了"
        elif setup_review_pr "$student_id" "$repo_suffix"; then
            echo "✓ レビュー用PR設定完了"
        else
            echo "⚠ レビュー用PR設定に失敗（手動設定が必要）"
        fi
        
        # メール送信（オプションが有効な場合）
        if [ "$SEND_MAIL" = true ]; then
            echo "学生への通知メール送信中..."
            if [ "$DRY_RUN" = true ]; then
                if [ -n "$TEST_MAIL" ]; then
                    email_address="$TEST_MAIL"
                    original_address="${student_id}${MAIL_DOMAIN}"
                    echo "[ドライラン] メール送信先: $email_address (本来: $original_address)"
                    echo "[ドライラン] 件名: 【論文指導】GitHubリポジトリを作成しました - ${student_id} (本来の宛先: ${original_address})"
                else
                    email_address="${student_id}${MAIL_DOMAIN}"
                    echo "[ドライラン] メール送信先: $email_address"
                    echo "[ドライラン] 件名: 【論文指導】GitHubリポジトリを作成しました - ${student_id}"
                fi
                echo "✓ [ドライラン] 通知メール送信完了"
            elif send_notification_email "$student_id" "$thesis_type" "$repo_name"; then
                echo "✓ 通知メール送信完了"
            else
                echo "⚠ 通知メール送信に失敗（手動連絡が必要）"
            fi
        fi
        
        created_repos+=("$repo_name")
        ((success_count++))
    else
        ((error_count++))
    fi
    
    echo ""
done

# 結果サマリー
echo "=== 作成結果 ==="
echo "成功: $success_count 個"
echo "失敗/スキップ: $error_count 個"
echo ""

if [ ${#created_repos[@]} -gt 0 ]; then
    echo "作成されたリポジトリ:"
    for repo in "${created_repos[@]}"; do
        echo "  - https://github.com/$repo"
    done
    echo ""
    
    echo "次のステップ:"
    if [ "$SEND_MAIL" = true ]; then
        echo "1. 学生への通知メールが送信されました"
        echo "   メールが届かない場合は手動で連絡してください"
        echo ""
        echo "2. 必要に応じて各リポジトリに以下を設定:"
        echo "   - Collaboratorの追加"
        echo "   - Branch protection rules"
        echo "   - GitHub Actions設定の確認"
    else
        echo "1. 各学生に以下を伝えてください:"
        echo "   - リポジトリURL"
        echo "   - GitHub Desktopでのクローン方法"
        echo "   - aldc環境構築手順"
        echo ""
        echo "2. 必要に応じて各リポジトリに以下を設定:"
        echo "   - Collaboratorの追加"
        echo "   - Branch protection rules"
        echo "   - GitHub Actions設定の確認"
    fi
fi

if [ $error_count -gt 0 ]; then
    echo "注意: $error_count 個のリポジトリで問題が発生しました"
    echo "詳細は上記のログを確認してください"
    exit 1
fi

echo "すべての処理が完了しました"
