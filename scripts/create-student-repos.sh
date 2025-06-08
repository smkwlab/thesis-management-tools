#!/bin/bash

# 下川研論文リポジトリ一括作成スクリプト
# 使用例: 
#   卒業論文: ./create-student-repos.sh k21rs001 k21rs002 k21rs003
#   修士論文: ./create-student-repos.sh k21gjk01 k21gjk02

set -e  # エラー時に終了

# 引数チェック
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <学籍番号1> <学籍番号2> ..."
    echo "例（卒業論文）: $0 k21rs001 k21rs002 k21rs003"
    echo "例（修士論文）: $0 k21gjk01 k21gjk02"
    echo ""
    echo "対応する学籍番号の形式:"
    echo "  卒業論文: k??rs??? (例: k21rs001)"
    echo "  修士論文: k??gjk?? (例: k21gjk01)"
    exit 1
fi

# 設定
ORGANIZATION="smkwlab"

echo "=== 下川研論文リポジトリ作成スクリプト ==="
echo "作成対象: $# 個のリポジトリ"
echo ""

# GitHub CLI認証確認
if ! gh auth status >/dev/null 2>&1; then
    echo "エラー: GitHub CLIの認証が必要です"
    echo "以下のコマンドで認証してください:"
    echo "  gh auth login"
    exit 1
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
    git commit --allow-empty -m "Initial review branch for thesis comments"
    git push
    
    # レビュー用PR作成（initial-emptyベース）
    if gh pr create \
        --base initial-empty \
        --head review-branch \
        --title "【レビュー用】論文全体へのコメント" \
        --body "$(cat <<EOF
## このPRについて

この Pull Request は論文全体への添削コメント用です。

### 使用方法

- **論文全体の構成**や**以前の部分への追加指摘**は、このPRでコメントしてください
- **直前版からの変更点**は、各版のPR（1st-draft等）でコメントしてください

### 重要

⚠️ **このPRは絶対にマージしないでください** ⚠️

このPRは添削専用で、最終提出まで開いたままにしておきます。
**initial-empty → review-branch** の構成により、論文全体（merge済み箇所含む）にコメント可能です。

### ハイブリッドワークフロー

\`\`\`
initial-empty (空の初期状態) ← レビュー用PRのベース
 ├─ 0th-draft (目次案)
 ├─ 1st-draft (0th-draftベース) ← 差分明確  
 ├─ 2nd-draft (1st-draftベース) ← 差分明確
 ├─ 3rd-draft (2nd-draftベース) ← 差分明確
 └─ review-branch (定期的に最新版をマージ)
\`\`\`

### 教員の作業手順

1. **差分レビュー**: 各版のPRで直前版からの変更をレビュー
2. **全体レビュー**: このPRで論文全体をレビュー
3. **自動更新**: GitHub Actions により学生PR作成時に自動更新

### レビュー対象ファイル

- 論文本体: \`${repo_suffix}.tex\`
- 概要: \`gaiyou.tex\`
- その他関連ファイル

### 使い分けガイド

| コメントの種類 | 使用するPR |
|------------|-----------|
| 目次案への指摘 | 0th-draft PR |
| 直前版からの変更点 | 各版のPR (1st-draft等) |
| 論文全体の構成 | このPR |
| merge済み箇所への追加指摘 | このPR |
| 章を跨ぐ整合性の確認 | このPR |
| 最終提出前の全体確認 | このPR |

### Suggestion対応

学生がsuggestionを適用した場合：
1. 学生: 「Apply suggestion」→「Re-request review」🔄
2. 教員: 確認後にmerge
3. システム: GitHub Actions が自動的にこのPRを最新化

### 並行作業

学生は前版PR提出後、教員merge完了を待たずに次版作業開始可能です。
教員merge完了後、GitHub Desktop で「Update from main」で調整。
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

# 各学生のリポジトリ作成
success_count=0
error_count=0
created_repos=()

for student_id in "$@"; do
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
    
    # リポジトリ存在チェック
    if gh repo view "$repo_name" >/dev/null 2>&1; then
        echo "警告: リポジトリ '$repo_name' は既に存在します"
        echo "スキップします"
        ((error_count++))
        continue
    fi
    
    # リポジトリ作成
    echo "リポジトリを作成中: $repo_name"
    if gh repo create "$repo_name" \
        --template "$template_repo" \
        --private \
        --clone \
        --description "${student_id}の${thesis_type}"; then
        
        echo "✓ 作成成功: https://github.com/$repo_name"
        
        # 不要なテンプレートファイルを削除
        echo "論文タイプ別ファイル調整中..."
        if cleanup_template_files "$student_id" "$repo_suffix"; then
            echo "✓ 不要ファイル削除完了"
        else
            echo "⚠ ファイル削除に失敗（手動削除が必要）"
        fi
        
        # LaTeX devcontainer の追加
        echo "LaTeX devcontainer を追加中..."
        if setup_devcontainer "$student_id" "$repo_suffix"; then
            echo "✓ devcontainer 追加完了"
        else
            echo "⚠ devcontainer 追加に失敗（手動設定が必要）"
        fi
        
        # レビュー用PRの初期設定
        echo "レビュー用PRを設定中..."
        if setup_review_pr "$student_id" "$repo_suffix"; then
            echo "✓ レビュー用PR設定完了"
        else
            echo "⚠ レビュー用PR設定に失敗（手動設定が必要）"
        fi
        
        created_repos+=("$repo_name")
        ((success_count++))
    else
        echo "✗ 作成失敗: $repo_name"
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

if [ $error_count -gt 0 ]; then
    echo "注意: $error_count 個のリポジトリで問題が発生しました"
    echo "詳細は上記のログを確認してください"
    exit 1
fi

echo "すべての処理が完了しました"
