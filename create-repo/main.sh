#!/bin/bash
# 論文リポジトリセットアップスクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BRIGHT_WHITE='\033[1;37m'
NC='\033[0m'

echo "🎓 論文リポジトリセットアップツール"
echo "=============================================="

# GitHub認証
echo "GitHub認証を確認中..."

# セキュアファイルからトークンを読み取り（フォールバック：環境変数）
if [ -f "/tmp/gh_token" ]; then
    echo -e "${GREEN}✓ ホストからセキュアトークンを取得しました${NC}"
    export GH_TOKEN=$(cat /tmp/gh_token)
    
    # トークンの有効性を確認
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓ GitHub認証済み（セキュアファイル認証）${NC}"
    else
        echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
        exit 1
    fi
elif [ -n "$GH_TOKEN" ]; then
    echo -e "${GREEN}✓ ホストから認証トークンを取得しました（環境変数）${NC}"
    export GH_TOKEN
    
    # トークンの有効性を確認
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓ GitHub認証済み（トークン認証）${NC}"
    else
        echo -e "${RED}エラー: 提供されたトークンが無効です${NC}"
        exit 1
    fi
elif ! gh auth status &>/dev/null; then
    echo -e "${YELLOW}GitHub認証が必要です${NC}"
    echo ""
    echo "=== ブラウザ認証手順 ==="
    echo "1. ブラウザで https://github.com/login/device が開いているはずです"
    echo -e "2. ${GREEN}Continue${NC} ボタンをクリック"
    echo -e "3. 下から2行目の以下のような行の ${YELLOW}XXXX-XXXX${NC} をコピーしてブラウザに入力:"
    echo -e "   ${YELLOW}!${NC} First copy your one-time code: ${BRIGHT_WHITE}XXXX-XXXX${NC}"
    echo -e "4. ${GREEN}Authorize github${NC} ボタンをクリックする"
    echo ""

    if echo -e "Y\n" | gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --scopes "repo,workflow,read:org,gist"; then
        echo -e "${GREEN}✓ GitHub認証完了${NC}"
    else
        echo -e "${RED}エラー: GitHub認証に失敗しました${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ GitHub認証済み${NC}"
fi

# 組織/ユーザーの設定
if [ -n "$TARGET_ORG" ]; then
    # 環境変数で明示的に指定された場合
    ORGANIZATION="$TARGET_ORG"
    echo -e "${GREEN}✓ 指定された組織: $ORGANIZATION${NC}"
elif [ -n "$GITHUB_REPOSITORY" ]; then
    # GitHub Actions等で実行されている場合、リポジトリから組織を取得
    ORGANIZATION=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
    echo -e "${GREEN}✓ 自動検出された組織: $ORGANIZATION${NC}"
else
    # デフォルトは smkwlab
    ORGANIZATION="smkwlab"
    echo -e "${YELLOW}✓ デフォルト組織を使用: $ORGANIZATION${NC}"
fi

# テンプレートリポジトリの設定
if [ -n "$TEMPLATE_REPO" ]; then
    TEMPLATE_REPOSITORY="$TEMPLATE_REPO"
else
    TEMPLATE_REPOSITORY="${ORGANIZATION}/sotsuron-template"
fi
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力または引数から取得
if [ -n "$1" ]; then
    STUDENT_ID="$1"
    echo -e "${GREEN}学籍番号: $STUDENT_ID${NC}"
else
    echo ""
    echo "学籍番号を入力してください"
    echo "  卒業論文の例: k21rs001"
    echo "  修士論文の例: k21gjk01"
    echo ""
    read -p "学籍番号: " STUDENT_ID
fi

# 論文タイプの判定
if [[ "$STUDENT_ID" =~ k[0-9]{2}rs[0-9]{3} ]]; then
    THESIS_TYPE="sotsuron"
    echo -e "${GREEN}✓ 卒業論文として設定します${NC}"
elif [[ "$STUDENT_ID" =~ k[0-9]{2}gjk[0-9]{2} ]]; then
    THESIS_TYPE="thesis"
    echo -e "${GREEN}✓ 修士論文として設定します${NC}"
else
    echo -e "${RED}エラー: 学籍番号の形式が正しくありません${NC}"
    exit 1
fi

REPO_NAME="${STUDENT_ID}-${THESIS_TYPE}"
FULL_REPO_NAME="${ORGANIZATION}/${REPO_NAME}"

# GitHubユーザー名の取得
echo "GitHub認証情報を確認中..."
GITHUB_USER=$(gh api user --jq .login)
echo -e "${GREEN}✓ GitHubユーザー: $GITHUB_USER${NC}"

# 組織への権限確認
echo "組織への権限を確認中..."
if gh api orgs/"$ORGANIZATION"/members/"$GITHUB_USER" &>/dev/null; then
    echo -e "${GREEN}✓ 組織 $ORGANIZATION のメンバーです${NC}"
elif [ "$ORGANIZATION" = "$GITHUB_USER" ]; then
    echo -e "${GREEN}✓ 個人アカウントにリポジトリを作成します${NC}"
else
    echo -e "${RED}エラー: 組織 $ORGANIZATION への権限がありません${NC}"
    echo "対処法:"
    echo "1. 組織の管理者に招待を依頼してください"
    echo "2. または個人アカウントに作成: docker run -e TARGET_ORG=$GITHUB_USER ..."
    exit 1
fi

# リポジトリ作成
echo "リポジトリ ${FULL_REPO_NAME} を作成中..."
if gh repo create "$FULL_REPO_NAME" \
    --template "$TEMPLATE_REPOSITORY" \
    --private \
    --clone \
    --description "${STUDENT_ID}の${THESIS_TYPE}"; then
    echo -e "${GREEN}✓ リポジトリ作成完了${NC}"
else
    echo -e "${RED}リポジトリ作成に失敗しました${NC}"
    exit 1
fi

cd "$REPO_NAME"

# Git設定
echo "Git設定を確認中..."
GITHUB_EMAIL=$(gh api user --jq .email)
GITHUB_NAME=$(gh api user --jq .name)

if [ "$GITHUB_EMAIL" = "null" ] || [ -z "$GITHUB_EMAIL" ]; then
    GITHUB_EMAIL="${GITHUB_USER}@users.noreply.github.com"
fi
if [ "$GITHUB_NAME" = "null" ] || [ -z "$GITHUB_NAME" ]; then
    GITHUB_NAME="$GITHUB_USER"
fi

git config user.email "$GITHUB_EMAIL"
git config user.name "$GITHUB_NAME"
echo -e "${GREEN}✓ Git設定完了: $GITHUB_NAME <$GITHUB_EMAIL>${NC}"

# 不要なファイルを削除
echo "テンプレートファイルを整理中..."
if [ "$THESIS_TYPE" = "sotsuron" ]; then
    rm -f thesis.tex abstract.tex
    git add -A && git commit -m "Remove graduate thesis template files" >/dev/null 2>&1
else
    rm -f sotsuron.tex gaiyou.tex example*.tex
    git add -A && git commit -m "Remove undergraduate thesis template files" >/dev/null 2>&1
fi

# devcontainer セットアップ
echo "LaTeX環境をセットアップ中..."
if ALDC_QUIET=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)"; then
    echo -e "${GREEN}✓ LaTeX環境のセットアップ完了${NC}"
    
    # aldc一時ファイルの削除
    echo "一時ファイルを削除中..."
    if find . -name "*-aldc" -type f -delete; then
        echo -e "${GREEN}✓ 一時ファイル削除完了${NC}"
    else
        echo -e "${YELLOW}⚠ 一時ファイル削除で警告が発生しましたが、処理を続行します${NC}"
    fi
    
    # LaTeX環境セットアップ完了をコミット
    git add -A && git commit -m "Add LaTeX development environment with devcontainer" >/dev/null 2>&1
else
    echo -e "${YELLOW}⚠ LaTeX環境のセットアップに失敗しました${NC}"
fi

# GitHub CLIの認証情報をgitに設定
# これによりgit pushコマンドが認証プロンプトなしで実行可能になる
echo "Git認証を設定中..."
if ! gh auth setup-git; then
    echo -e "${RED}✗ Git認証設定に失敗しました${NC}"
    echo -e "${RED}GitHub CLIの認証が正しく設定されているか確認してください${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git認証設定完了${NC}"

# 初期ブランチ構成
echo "ブランチを設定中..."

git checkout -b initial >/dev/null 2>&1
git commit --allow-empty -m "初期状態（リポジトリ作成直後）" >/dev/null 2>&1
git push -u origin initial >/dev/null 2>&1

git checkout -b review-branch >/dev/null 2>&1
git push -u origin review-branch >/dev/null 2>&1

git checkout -b 0th-draft >/dev/null 2>&1
git push -u origin 0th-draft >/dev/null 2>&1

# Note: mainブランチ保護は教員が後から設定する必要があります
# ブランチ保護ツール: thesis-management-tools/scripts/setup-branch-protection.sh

# 学生IDの処理ロック獲得（並行実行防止）
acquire_student_lock() {
    local student_id="$1"
    
    # 一時ディレクトリの作成（より安全）
    local tmp_dir
    if command -v mktemp >/dev/null 2>&1; then
        tmp_dir=$(mktemp -d -t "thesis-protection.XXXXXX") 2>/dev/null
    fi
    
    # フォールバック: /tmp 使用
    if [ -z "$tmp_dir" ] || [ ! -d "$tmp_dir" ]; then
        tmp_dir="/tmp"
    fi
    
    local lockfile="${tmp_dir}/thesis-protection-${student_id}.lock"
    
    # ロック取得試行（タイムアウト付き）
    local max_attempts=30  # 30秒間試行
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if (set -C; echo $$ > "$lockfile") 2>/dev/null; then
            # ロック獲得成功
            break
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -eq 1 ]; then
            echo -e "${YELLOW}⚠️  学生ID ${student_id} の処理が実行中です${NC}"
            echo -e "${YELLOW}   ロック取得を試行中... (最大30秒)${NC}"
        fi
        
        # 既存のロックファイルが古い場合は削除（5分以上古い）
        if [ -f "$lockfile" ]; then
            local lock_age
            if command -v stat >/dev/null 2>&1; then
                # Linux/macOS対応
                if stat -f%m "$lockfile" >/dev/null 2>&1; then
                    # macOS (BSD stat)
                    lock_age=$(( $(date +%s) - $(stat -f%m "$lockfile" 2>/dev/null || echo 0) ))
                else
                    # Linux (GNU stat)
                    lock_age=$(( $(date +%s) - $(stat -c%Y "$lockfile" 2>/dev/null || echo 0) ))
                fi
                
                if [ "$lock_age" -gt 300 ]; then  # 5分 = 300秒
                    echo -e "${YELLOW}   古いロックファイルを削除中...${NC}"
                    rm -f "$lockfile" 2>/dev/null || true
                fi
            fi
        fi
        
        sleep 1
    done
    
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}❌ ロック取得タイムアウト${NC}"
        echo "   他の処理が完了するまでお待ちください"
        return 1
    fi
    
    # 終了時にロックファイルを削除
    trap "rm -f '$lockfile'" EXIT
    echo -e "${GREEN}✅ 処理ロック獲得完了${NC}"
    return 0
}

# 既存学生ID登録状況チェック（重複回避）
check_existing_student() {
    local student_id="$1"
    
    echo "📋 既存学生ID登録状況をチェック中..."
    
    # pending-protection.txtの内容を取得して確認
    if gh api "repos/smkwlab/thesis-management-tools/contents/student-repos/pending-protection.txt" \
       --jq '.content' 2>/dev/null | base64 -d | grep -q "^${student_id} "; then
        echo -e "${YELLOW}⚠️  学生ID ${student_id} は既に登録済みです${NC}"
        echo "   既存のIssueを確認してください"
        return 1
    fi
    
    # completed-protection.txtも確認
    if gh api "repos/smkwlab/thesis-management-tools/contents/student-repos/completed-protection.txt" \
       --jq '.content' 2>/dev/null | base64 -d | grep -q "^${student_id} "; then
        echo -e "${GREEN}ℹ️  学生ID ${student_id} のブランチ保護は既に設定済みです${NC}"
        echo "   新しいIssue作成をスキップします"
        return 1
    fi
    
    echo -e "${GREEN}✅ 学生ID重複チェック完了（新規登録）${NC}"
    return 0
}

# Issue作成失敗時の詳細診断（エラー要因特定）
diagnose_issue_failure() {
    local exit_code="$1"
    
    echo "🔍 エラー診断中..."
    
    case $exit_code in
        128) 
            echo -e "${YELLOW}   原因: GitHub リポジトリへのアクセス権限がありません${NC}"
            echo "   対処: 教員に以下の権限設定を依頼してください："
            echo "         - thesis-management-tools リポジトリへの Issue 作成権限"
            echo "         - smkwlab 組織のメンバーシップ確認"
            echo "         - ラベル管理権限（branch-protection ラベル追加用）"
            ;;
        1)   
            echo -e "${YELLOW}   原因: ネットワークエラーまたは認証エラーです${NC}"
            echo "   対処: 以下を確認してください："
            echo "         1. 'gh auth status' で認証状態を確認"
            echo "         2. インターネット接続を確認"
            echo "         3. GitHub のサービス状況を確認"
            ;;
        2)
            echo -e "${YELLOW}   原因: GitHub CLI の設定エラーです${NC}"
            echo "   対処: GitHub CLI を再設定してください："
            echo "         'gh auth login' を実行して再認証"
            ;;
        *)   
            echo -e "${YELLOW}   原因: 予期しないエラーが発生しました (exit code: $exit_code)${NC}"
            echo "   対処: 以下の情報を教員に連絡してください："
            echo "         - 学生ID: ${STUDENT_ID:-unknown}"
            echo "         - エラーコード: $exit_code"
            echo "         - 実行時刻: $(date)"
            ;;
    esac
}

# 管理リポジトリへのIssue作成（ブランチ保護設定依頼）
create_protection_request_issue() {
    local student_id="$1"
    local repo_name="$2"
    
    # Dockerコンテナ内でのJST時刻を正確に取得
    # UTCに9時間を加算してJSTに変換（日付境界も考慮）
    local utc_hour=$(date -u +'%H')
    local utc_minute=$(date -u +'%M')
    local utc_year=$(date -u +'%Y')
    local utc_month=$(date -u +'%m')
    local utc_day=$(date -u +'%d')
    
    local jst_hour=$(( (utc_hour + 9) % 24 ))
    
    # 日付が変わる場合の処理（UTC 15:00以降はJST翌日）
    if [ $((utc_hour + 9)) -ge 24 ]; then
        # 翌日になる場合、エポック時間を使って正確に計算
        local tomorrow_epoch=$(( $(date -u +%s) + 86400 ))
        local created_date=$(date -u -d "@$tomorrow_epoch" +'%Y-%m-%d')
    else
        local created_date="${utc_year}-${utc_month}-${utc_day}"
    fi
    
    local created_time=$(date -u)
    local created_jst_time=$(printf "%02d:%02d" "$jst_hour" "$utc_minute")
    
    echo "📋 ブランチ保護設定依頼Issueを作成中..."
    
    # GitHub Issue作成（学生でも権限があれば可能）
    local issue_number=""
    if issue_number=$(gh issue create \
        --repo smkwlab/thesis-management-tools \
        --title "🔒 ブランチ保護設定依頼: smkwlab/${repo_name}" \
        --assignee toshi0806 \
        --body "$(cat <<EOF
## ブランチ保護設定依頼

### リポジトリ情報
- **リポジトリ**: [smkwlab/${repo_name}](https://github.com/smkwlab/${repo_name})
- **学生ID**: ${student_id}
- **作成日時**: ${created_date} ${created_jst_time} JST

### 教員の対応手順
- [ ] 以下のコマンドを実行
\`\`\`bash
cd thesis-management-tools/scripts
./setup-branch-protection.sh ${student_id}
\`\`\`
- [ ] 設定完了を確認: [リポジトリ設定](https://github.com/smkwlab/${repo_name}/settings/branches)
- [ ] このIssueをクローズ

### 一括処理オプション
複数の学生を一括処理する場合：
\`\`\`bash
cd thesis-management-tools/scripts
# 学生リストファイルに追加
echo "${student_id} # Created: ${created_date} Repository: ${repo_name}" >> ../student-repos/pending-protection.txt
# 一括実行
./bulk-setup-protection.sh ../student-repos/pending-protection.txt
\`\`\`

### 設定される保護ルール
- 1つ以上の承認レビューが必要
- 新しいコミット時に古いレビューを無効化
- フォースプッシュとブランチ削除を禁止

---
*この Issue は学生の setup.sh 実行時に自動生成されました*
*学生ID: ${student_id} | リポジトリ: ${repo_name} | 作成: ${created_date} ${created_jst_time} JST*
EOF
)" 2>/dev/null); then
        # Issue作成成功時のラベル確認と修正
        echo -e "${GREEN}✅ ブランチ保護設定依頼Issue作成完了${NC}"
        # Issue番号からURLを正しく抽出
        local clean_issue_number=$(echo "$issue_number" | grep -o '[0-9]\+' | head -1)
        echo "   Issue #${clean_issue_number}: https://github.com/smkwlab/thesis-management-tools/issues/${clean_issue_number}"
        
        # Issue作成完了
        echo -e "${GREEN}ℹ️  教員が上記Issueを確認してブランチ保護設定を実行します${NC}"
        
        # 学生リストファイルへの追加（Dockerコンテナ内では実行環境に依存）
        # Note: Dockerコンテナ内では相対パスが異なるため、Issueでの管理を優先
        
        return 0
    else
        local exit_code=$?
        echo -e "${YELLOW}⚠️  Issue作成に失敗しました${NC}"
        diagnose_issue_failure "$exit_code"
        echo ""
        echo "   手動作成用情報:"
        echo "   - 学生ID: ${student_id}"
        echo "   - リポジトリ: https://github.com/smkwlab/${repo_name}"
        echo "   - 実行コマンド: ./setup-branch-protection.sh ${student_id}"
        return 1
    fi
}

# 自動Issue作成の実行
if [ -n "$STUDENT_ID" ]; then
    # 並行実行防止のためのロック獲得
    if acquire_student_lock "$STUDENT_ID"; then
        # 重複学生ID検出・回避
        if check_existing_student "$STUDENT_ID"; then
            create_protection_request_issue "$STUDENT_ID" "$REPO_NAME"
        else
            echo -e "${YELLOW}⚠️  Issue作成をスキップしました（既存学生ID）${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  処理をスキップしました（他の処理が実行中）${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  学籍番号が設定されていないため、自動Issue作成をスキップしました${NC}"
    echo "   手動で教員にブランチ保護設定を依頼してください"
fi

# 完了メッセージ
echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "リポジトリURL:"
echo "  https://github.com/${FULL_REPO_NAME}"
echo ""
echo "論文執筆の開始方法:"
echo "  https://github.com/${FULL_REPO_NAME}/blob/main/WRITING-GUIDE.md"
