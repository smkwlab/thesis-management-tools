#!/bin/bash

# ⚠️ 【非推奨】レビュー用ブランチ更新スクリプト（教員用）
# 
# 現在はGitHub Actionsによる自動更新を推奨しています。
# このスクリプトは緊急時やトラブルシューティング用として残されています。
#
# 🔄 自動更新: 学生がPRを作成すると GitHub Actions が自動的にreview-branchを更新
# 📁 ワークフロー: .github/workflows/update-review-branch.yml
#
# 使用例（非推奨）: 
#   ./update-review-branch.sh k21rs001-sotsuron 1st-draft  (リポジトリ名指定)
#   ./update-review-branch.sh 1st-draft                    (Gitリモートからリポジトリ名を自動取得)
#   ./update-review-branch.sh                              (Gitリモートからリポジトリ名と最新PRを自動取得)

set -e  # エラー時に終了

ORGANIZATION="smkwlab"

# Gitリモート設定からリポジトリ名を取得する関数
get_repo_name_from_git() {
    # 現在のディレクトリがGitリポジトリかチェック
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 1
    fi
    
    # origin のリモートURLを取得
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null)
    
    if [ -z "$remote_url" ]; then
        return 1
    fi
    
    # GitHubのURL形式からリポジトリ名を抽出
    # https://github.com/smkwlab/k21rs001-sotsuron.git
    # git@github.com:smkwlab/k21rs001-sotsuron.git
    local repo_name
    if [[ "$remote_url" =~ github\.com[:/]smkwlab/([^/]+)$ ]]; then
        repo_name="${BASH_REMATCH[1]}"
        # .git サフィックスを削除
        repo_name="${repo_name%.git}"
        # 学生リポジトリの形式かチェック
        if [[ "$repo_name" =~ ^k[0-9]{2}(rs[0-9]{3}|gjk[0-9]{2})-(sotsuron|master)$ ]]; then
            echo "$repo_name"
            return 0
        fi
    fi
    
    return 1
}

# 最新のPRから更新対象ブランチを取得する関数
get_latest_pr_branch() {
    # 最新のOpenなPRのheadブランチを取得（review-branchを除く）
    local latest_branch
    latest_branch=$(gh pr list --state open --json headRefName --jq '.[] | select(.headRefName != "review-branch") | .headRefName' | head -1)
    
    if [ -n "$latest_branch" ] && [ "$latest_branch" != "null" ]; then
        echo "$latest_branch"
        return 0
    else
        return 1
    fi
}

# 引数の解析
case $# in
    0)
        # 引数なし：Gitリモート設定からリポジトリ名と最新PRブランチを自動取得
        if REPO_DIR=$(get_repo_name_from_git); then
            echo "Gitリモート設定からリポジトリ名を自動取得: $REPO_DIR"
        else
            echo "エラー: リポジトリ名を自動取得できませんでした"
            echo "現在のディレクトリ: $(pwd)"
            echo "学生リポジトリのGitディレクトリで実行するか、明示的に引数を指定してください"
            echo ""
            echo "使用方法:"
            echo "  $0 <リポジトリ名> <更新元ブランチ名>"
            echo "  $0 <更新元ブランチ名>          (Gitリモートからリポジトリ名を自動取得)"
            echo "  $0                           (Gitリモートからリポジトリ名と最新PRを自動取得)"
            exit 1
        fi
        
        if SOURCE_BRANCH=$(get_latest_pr_branch); then
            echo "最新のPRから更新元ブランチを自動取得: $SOURCE_BRANCH"
        else
            echo "エラー: 最新のPRブランチを自動取得できませんでした"
            echo "現在OpenなPRがないか、GitHub CLIの認証が必要です"
            echo "明示的にブランチ名を指定してください"
            exit 1
        fi
        ;;
    1)
        # 引数1個：Gitリモート設定からリポジトリ名を自動取得、引数をブランチ名として使用
        if REPO_DIR=$(get_repo_name_from_git); then
            echo "Gitリモート設定からリポジトリ名を自動取得: $REPO_DIR"
            SOURCE_BRANCH="$1"
        else
            echo "エラー: リポジトリ名を自動取得できませんでした"
            echo "現在のディレクトリ: $(pwd)"
            echo "学生リポジトリのGitディレクトリで実行するか、明示的にリポジトリ名を指定してください"
            echo ""
            echo "使用方法:"
            echo "  $0 <リポジトリ名> <更新元ブランチ名>"
            echo "  $0 <更新元ブランチ名>          (Gitリモートからリポジトリ名を自動取得)"
            exit 1
        fi
        ;;
    2)
        # 引数2個：リポジトリ名とブランチ名を指定
        REPO_DIR="$1"
        SOURCE_BRANCH="$2"
        ;;
    *)
        echo "使用方法:"
        echo "  $0 <リポジトリ名> <更新元ブランチ名>"
        echo "  $0 <更新元ブランチ名>          (Gitリモートからリポジトリ名を自動取得)"
        echo "  $0                           (Gitリモートからリポジトリ名と最新PRを自動取得)"
        echo ""
        echo "例:"
        echo "  $0 k21rs001-sotsuron 1st-draft"
        echo "  $0 k21gjk01-master 2nd-draft"
        echo "  $0 1st-draft               (学生リポジトリのGitディレクトリ内で実行)"
        echo "  $0                         (学生リポジトリのGitディレクトリ内で実行、最新PR自動検出)"
        exit 1
        ;;
esac

repo_name="${ORGANIZATION}/${REPO_DIR}"

echo "=== レビュー用ブランチ更新スクリプト ==="
echo "リポジトリ: $repo_name"
echo "更新元ブランチ: $SOURCE_BRANCH"
echo ""

# GitHub CLI認証確認
if ! gh auth status >/dev/null 2>&1; then
    echo "エラー: GitHub CLIの認証が必要です"
    echo "以下のコマンドで認証してください:"
    echo "  gh auth login"
    exit 1
fi

# リモートリポジトリ存在確認
if ! gh repo view "$repo_name" >/dev/null 2>&1; then
    echo "エラー: リモートリポジトリが見つかりません: $repo_name"
    exit 1
fi

# 現在のディレクトリが対象リポジトリかチェック
cwd_basename=$(basename "$(pwd)")
if [ "$cwd_basename" = "$REPO_DIR" ]; then
    echo "現在のディレクトリで作業を継続します: $(pwd)"
else
    # ローカルリポジトリの確認
    if [ ! -d "$REPO_DIR" ]; then
        echo "ローカルリポジトリが見つかりません。クローンします..."
        if ! gh repo clone "$repo_name"; then
            echo "エラー: リポジトリのクローンに失敗"
            exit 1
        fi
    fi
    
    # リポジトリディレクトリに移動
    echo "リポジトリディレクトリに移動: $REPO_DIR"
    cd "$REPO_DIR" || exit 1
fi

# 最新情報を取得
echo "最新情報を取得中..."
git fetch origin

# 更新元ブランチの存在確認
if ! git show-ref --verify --quiet "refs/remotes/origin/$SOURCE_BRANCH"; then
    echo "エラー: ブランチ '$SOURCE_BRANCH' がリモートに存在しません"
    echo "利用可能なブランチ:"
    git branch -r | grep -v "HEAD"
    # 元のディレクトリに戻る（移動していた場合のみ）
    if [ "$cwd_basename" != "$REPO_DIR" ]; then
        cd ..
    fi
    exit 1
fi

# review-branchの存在確認
if ! git show-ref --verify --quiet "refs/remotes/origin/review-branch"; then
    echo "エラー: review-branchがリモートに存在しません"
    echo "先に create-student-repos.sh で初期設定を行ってください"
    # 元のディレクトリに戻る（移動していた場合のみ）
    if [ "$cwd_basename" != "$REPO_DIR" ]; then
        cd ..
    fi
    exit 1
fi

# review-branchに切り替え
echo "review-branchに切り替え中..."
git checkout review-branch
git pull origin review-branch

# 更新元ブランチの内容をマージ
echo "$SOURCE_BRANCH の内容をreview-branchにマージ中..."
if git merge "origin/$SOURCE_BRANCH" --no-edit; then
    echo "✓ マージ成功"
    
    # draft系ブランチの場合、最新のabstractがあれば概要ファイルもマージ
    if [[ "$SOURCE_BRANCH" =~ -draft$ ]]; then
        echo "draft系ブランチを検出。最新の概要を確認中..."
        
        # 最新のabstractブランチを検索（20thから逆順で探す）
        LATEST_ABSTRACT=""
        for i in {20..1}; do
            case $i in
                1|21) SUFFIX="st" ;;
                2|22) SUFFIX="nd" ;;
                3|23) SUFFIX="rd" ;;
                *) SUFFIX="th" ;;
            esac
            
            ABSTRACT_BRANCH="abstract-${i}${SUFFIX}"
            if git show-ref --verify --quiet "refs/remotes/origin/$ABSTRACT_BRANCH"; then
                LATEST_ABSTRACT="$ABSTRACT_BRANCH"
                break
            fi
        done
        
        # 最新のabstractが見つかった場合は概要ファイルをマージ
        if [ -n "$LATEST_ABSTRACT" ]; then
            echo "最新の概要ブランチを発見: $LATEST_ABSTRACT"
            echo "gaiyou.tex を $LATEST_ABSTRACT からマージ中..."
            
            # gaiyou.texのみを最新のabstractから取得
            if git show "origin/$LATEST_ABSTRACT:gaiyou.tex" > /dev/null 2>&1; then
                git checkout "origin/$LATEST_ABSTRACT" -- gaiyou.tex
                git add gaiyou.tex
                git commit -m "Update abstract from $LATEST_ABSTRACT" || true
                echo "✓ 概要ファイルを $LATEST_ABSTRACT からマージしました"
            else
                echo "gaiyou.tex が $LATEST_ABSTRACT に見つかりませんでした"
            fi
        else
            echo "概要ブランチが見つかりません"
        fi
    fi
    
    # リモートにプッシュ
    echo "リモートにプッシュ中..."
    if git push origin review-branch; then
        echo "✓ プッシュ成功"
        
        # レビュー用PRのURLを表示
        pr_url=$(gh pr list --head review-branch --state open --json url --jq '.[0].url' 2>/dev/null || echo "")
        if [ -n "$pr_url" ] && [ "$pr_url" != "null" ]; then
            echo ""
            echo "レビュー用PRで全体確認ができます:"
            echo "$pr_url"
        fi
        
        echo ""
        echo "✓ review-branchの更新が完了しました"
        echo "  最新版: $SOURCE_BRANCH"
        if [ -n "$LATEST_ABSTRACT" ]; then
            echo "  概要: $LATEST_ABSTRACT からマージ済み"
        fi
        echo "  レビュー用PR（initial → review-branch）で論文全体への添削が可能です"
        echo "  merge済み箇所を含む全体にコメントできます"
    else
        echo "✗ プッシュに失敗しました"
        # 元のディレクトリに戻る（移動していた場合のみ）
        if [ "$cwd_basename" != "$repo_dir" ]; then
            cd ..
        fi
        exit 1
    fi
else
    echo "✗ マージに失敗しました"
    echo "コンフリクトが発生している可能性があります"
    echo "手動での解決が必要です"
    # 元のディレクトリに戻る（移動していた場合のみ）
    if [ "$cwd_basename" != "$REPO_DIR" ]; then
        cd ..
    fi
    exit 1
fi

# 元のディレクトリに戻る（移動していた場合のみ）
if [ "$cwd_basename" != "$REPO_DIR" ]; then
    cd ..
fi

echo ""
echo "=== 更新完了 ==="
echo "⚠️  注意: このスクリプトは非推奨です"
echo "今後は GitHub Actions による自動更新をご利用ください"
echo ""
echo "次のステップ:"
echo "1. レビュー用PR（initial → review-branch）で全体的な添削を実施"
echo "   → merge済み箇所を含む論文全体にコメント可能"
echo "2. $SOURCE_BRANCH PRで差分レビューを実施"
echo "   → 直前版からの変更点を確認"
echo "3. 添削完了後、両方のPRにコメント"