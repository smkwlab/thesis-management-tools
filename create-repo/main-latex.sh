#!/bin/bash
# 汎用LaTeXリポジトリセットアップスクリプト

set -e

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BRIGHT_WHITE='\033[1;37m'
NC='\033[0m'

echo "📝 汎用LaTeXリポジトリセットアップツール"
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

# 動作モードの判定（setup-latex.shから渡された環境変数）
USER_TYPE="${USER_TYPE:-organization_member}"
INDIVIDUAL_MODE=false

if [ "$USER_TYPE" = "individual_user" ]; then
    INDIVIDUAL_MODE=true
    echo -e "${BLUE}👤 個人ユーザーモード有効${NC}"
    echo -e "${BLUE}   - ブランチ保護: 無効（デフォルト）${NC}"
    echo -e "${BLUE}   - Registry登録: 無効${NC}"
else
    echo -e "${GREEN}🏢 組織ユーザーモード${NC}"
    echo -e "${GREEN}   - ブランチ保護: 無効（デフォルト）${NC}"
    echo -e "${GREEN}   - Registry登録: 有効${NC}"
fi

# ブランチ保護設定の確認（環境変数でオプトイン）
ENABLE_PROTECTION="${ENABLE_PROTECTION:-false}"
if [ "$ENABLE_PROTECTION" = "true" ]; then
    echo -e "${YELLOW}⚠️ ブランチ保護が有効化されています（上級者向け）${NC}"
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
TEMPLATE_REPOSITORY="${ORGANIZATION}/latex-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力または引数から取得
if [ -n "$1" ]; then
    STUDENT_ID="$1"
else
    echo ""
    echo "学籍番号を入力してください"
    echo "  例: k21rs001, k21gjk01"
    echo ""
    read -p "学籍番号: " STUDENT_ID
fi

# 学籍番号の正規化（小文字化）
STUDENT_ID=$(echo "$STUDENT_ID" | tr '[:upper:]' '[:lower:]')

# 学籍番号の検証
if [ -z "$STUDENT_ID" ]; then
    echo -e "${RED}エラー: 学籍番号が指定されていません${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# ドキュメント名の入力
read_document_name() {
    if [ -n "$DOCUMENT_NAME" ]; then
        # 環境変数で既に指定されている場合
        echo -e "${GREEN}✓ ドキュメント名: $DOCUMENT_NAME（環境変数指定）${NC}"
        return 0
    fi
    
    echo ""
    echo "📝 ドキュメント名を入力してください (デフォルト: latex):"
    echo "   例: research-note, report2024, experiment-log"
    read -p "> " DOCUMENT_NAME
    
    # デフォルト値設定
    DOCUMENT_NAME="${DOCUMENT_NAME:-latex}"
    
    # バリデーション（英数字、ハイフン、アンダースコアのみ）
    if ! [[ "$DOCUMENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}❌ ドキュメント名は英数字、ハイフン、アンダースコアのみ使用可能です${NC}"
        DOCUMENT_NAME=""  # リセット
        read_document_name  # 再入力
    fi
}

read_document_name

# リポジトリ名の生成
REPO_NAME="${STUDENT_ID}-${DOCUMENT_NAME}"

echo ""
echo -e "${BRIGHT_WHITE}🎯 作成予定リポジトリ: ${ORGANIZATION}/${REPO_NAME}${NC}"
echo ""
read -p "続行しますか? [Y/n]: " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo -e "${YELLOW}キャンセルしました${NC}"
    exit 0
fi

# リポジトリ作成
echo ""
echo "📁 リポジトリを作成中..."

# テンプレートからリポジトリを作成
if [ "$INDIVIDUAL_MODE" = false ]; then
    # 組織の場合
    if gh repo create "${ORGANIZATION}/${REPO_NAME}" --public --template="$TEMPLATE_REPOSITORY" --clone; then
        echo -e "${GREEN}✓ リポジトリを作成しました: https://github.com/${ORGANIZATION}/${REPO_NAME}${NC}"
    else
        echo -e "${RED}エラー: リポジトリの作成に失敗しました${NC}"
        echo "- 既に同名のリポジトリが存在する可能性があります"
        echo "- 組織への権限が不足している可能性があります"
        exit 1
    fi
else
    # 個人の場合
    if gh repo create "${REPO_NAME}" --public --template="$TEMPLATE_REPOSITORY" --clone; then
        echo -e "${GREEN}✓ リポジトリを作成しました: https://github.com/${ORGANIZATION}/${REPO_NAME}${NC}"
    else
        echo -e "${RED}エラー: リポジトリの作成に失敗しました${NC}"
        echo "- 既に同名のリポジトリが存在する可能性があります"
        exit 1
    fi
fi

# リポジトリディレクトリに移動
cd "$REPO_NAME"

# main.texのカスタマイズ
echo "📄 main.texをカスタマイズ中..."

# 作者名の設定
AUTHOR_NAME="${AUTHOR_NAME:-著者名}"

# 新しいmain.texを生成
cat > main.tex << 'EOF'
\documentclass[dvipdfmx,uplatex,a4paper,10pt]{jsarticle}

%% 基本パッケージ
\usepackage{graphicx}                    % 図表挿入
\usepackage{amsmath,amssymb}            % 数式
\usepackage{url}                        % URL表示
\usepackage{enumitem}                   % リスト調整
\usepackage{textcomp}                   % 追加記号サポート

%% 日本語フォント設定
\usepackage[deluxe]{otf}
\usepackage[noalphabet,unicode,haranoaji]{pxchfon}

%% レイアウト設定
\usepackage[top=25mm,bottom=25mm,left=25mm,right=25mm]{geometry}
\linespread{1.2}                        % 行間調整

%% リスト設定
\renewcommand{\labelitemi}{$\bullet$}
\renewcommand{\labelitemii}{$\circ$}

%% ハイパーリンク設定（シンプル）
\usepackage[hidelinks]{hyperref}

%% 文書情報
EOF

# タイトルと著者名を動的に挿入
echo "\\title{${DOCUMENT_NAME}}" >> main.tex
echo "\\author{${AUTHOR_NAME}}" >> main.tex
echo "\\date{\\today}" >> main.tex

# main.texの残り部分を追加
cat >> main.tex << 'EOF'

\begin{document}
\maketitle

% 目次（簡素化）
\tableofcontents
\newpage

\section{はじめに}

EOF

echo "これは${DOCUMENT_NAME}の文書です。" >> main.tex

cat >> main.tex << 'EOF'

\subsection{このテンプレートの特徴}

\begin{itemize}
\item シンプルな構造で使いやすい
\item 日本語に最適化されたレイアウト
\item 基本的な機能を網羅
\item カスタマイズが容易
\end{itemize}

\section{基本的な使い方}

\subsection{文書の構成}

文書は\texttt{section}と\texttt{subsection}で構成します。必要に応じて\texttt{subsubsection}も使用できます。

\subsection{数式の記述}

数式は以下のように記述できます。

インライン数式: $E = mc^2$

独立した数式:
\begin{equation}
(x - a)^2 + (y - b)^2 = r^2
\label{eq:circle}
\end{equation}

式~\ref{eq:circle}は円の方程式です。

\end{document}
EOF

echo -e "${GREEN}✓ main.texをカスタマイズしました${NC}"

# README.mdのカスタマイズ
echo "📝 README.mdを生成中..."

cat > README.md << EOF
# ${STUDENT_ID}-${DOCUMENT_NAME}

${DOCUMENT_NAME}用のLaTeX文書プロジェクトです。

## 🚀 このプロジェクトについて

### 基盤テンプレート
- **ベース**: [latex-template](https://github.com/${ORGANIZATION}/latex-template) - 汎用LaTeXテンプレート
- **用途**: 研究ノート、レポート、実験記録など汎用的な文書作成
- **特徴**: 軽量・シンプル・即座に利用可能

### プロジェクト固有の設定
- **文書名**: ${DOCUMENT_NAME}
- **作成者**: ${STUDENT_ID}
- **作成日**: $(date '+%Y年%m月%d日')

## 📁 ファイル構成

\`\`\`
├── main.tex              # メイン文書（jsarticle形式）
├── README.md             # このファイル
└── .github/workflows/    # 自動PDF生成設定
\`\`\`

## 🔧 使用開始

### 1. 文書編集
\`main.tex\` を編集して文書を作成：
- **直接編集**: mainブランチで直接編集可能
- **構造**: section/subsection でシンプルに整理
- **数式・図表**: 基本LaTeX機能をすぐに利用

### 2. PDF生成
- **自動生成**: プッシュ時に自動でPDFが生成
- **確認方法**: GitHub Actionsタブで状況確認
- **ダウンロード**: Artifactsから生成PDFを取得

### 3. ローカルビルド（オプション）
\`\`\`bash
# 日本語LaTeXでコンパイル
uplatex main.tex
dvipdfmx main.dvi

# または一括処理（設定済みの場合）
latexmk -pdfdvi main.tex
\`\`\`

## 📋 書き方のコツ

### 基本構造
- **\\\section{}**: 大見出し
- **\\\subsection{}**: 中見出し  
- **段落**: 空行で段落分け

### よく使う要素
- **箇条書き**: \\\begin{itemize} \\\item ... \\\end{itemize}
- **数式**: \$...\$ （インライン）、\\\begin{equation} ... \\\end{equation} （独立）
- **図表**: \\\includegraphics{} for 画像、tabular環境 for 表

## 🆘 困った時は

### よくある問題
- **PDF生成されない**: GitHub Actionsログを確認、LaTeX構文エラーをチェック
- **日本語表示おかしい**: UTF-8エンコーディング確認
- **パッケージエラー**: 使用パッケージが対応環境で利用可能か確認

### 詳細ガイド
- **包括的な使用方法**: [latex-template README](https://github.com/${ORGANIZATION}/latex-template/blob/main/README.md)
- **LaTeX環境構築**: [latex-environment](https://github.com/${ORGANIZATION}/latex-environment)
- **研究室サイト**: [下川研究室](https://shimokawa-lab.kyusan-u.ac.jp/)

---

**セットアップ情報**: $(date '+%Y-%m-%d %H:%M:%S') に setup-latex.sh v1.0 で作成
EOF

echo -e "${GREEN}✓ README.mdを生成しました${NC}"

# ブランチ保護設定（オプトイン）
if [ "$ENABLE_PROTECTION" = "true" ]; then
    echo "🔒 ブランチ保護を設定中..."
    
    # デフォルトブランチ名を取得
    DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
    
    # ブランチ保護ルールを作成
    if gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/${ORGANIZATION}/${REPO_NAME}/branches/${DEFAULT_BRANCH}/protection" \
        -f required_status_checks='{"strict":true,"contexts":[]}' \
        -f enforce_admins=false \
        -f required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false}' \
        -f restrictions=null \
        -f allow_force_pushes=false \
        -f allow_deletions=false \
        -f required_conversation_resolution=true \
        -f lock_branch=false \
        -f allow_fork_syncing=true &>/dev/null; then
        echo -e "${GREEN}✓ ブランチ保護を有効化しました${NC}"
    else
        echo -e "${YELLOW}⚠️ ブランチ保護の設定に失敗しました（続行します）${NC}"
    fi
else
    echo -e "${BLUE}📝 汎用テンプレートのため、ブランチ保護は設定しません${NC}"
    echo -e "${BLUE}   mainブランチで直接作業できます${NC}"
fi

# 変更をコミットしてプッシュ
echo "📤 変更をコミット中..."

# GitHub CLIの認証情報をgitに設定
# これによりgit pushコマンドが認証プロンプトなしで実行可能になる
echo "Git認証を設定中..."
if ! gh auth setup-git; then
    echo -e "${RED}✗ Git認証設定に失敗しました${NC}"
    echo -e "${RED}GitHub CLIの認証が正しく設定されているか確認してください${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git認証設定完了${NC}"

# Gitユーザー設定（Docker環境用）
git config user.email "setup-latex@smkwlab.github.io"
git config user.name "LaTeX Setup Tool"

git add .
git commit -m "Initial customization for ${DOCUMENT_NAME}

- Customize main.tex for ${DOCUMENT_NAME}
- Add project-specific README.md
- Author: ${AUTHOR_NAME}
- Student ID: ${STUDENT_ID}
"

if git push origin main; then
    echo -e "${GREEN}✓ 変更をプッシュしました${NC}"
else
    echo -e "${RED}エラー: プッシュに失敗しました${NC}"
    exit 1
fi

# Registry Manager連携（組織ユーザーのみ）
if [ "$INDIVIDUAL_MODE" = false ]; then
    echo "📊 Registry Managerに登録中..."
    
    # thesis-student-registryリポジトリの存在確認
    if gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
        # registry_managerツールの存在確認（Docker内では使用不可なのでスキップ）
        echo -e "${YELLOW}⚠️ Registry Manager登録は手動で実行してください：${NC}"
        echo -e "   cd thesis-student-registry"
        echo -e "   ./registry_manager/registry-manager add ${REPO_NAME} ${STUDENT_ID} latex active general"
    else
        echo -e "${YELLOW}⚠️ thesis-student-registryリポジトリが見つかりません${NC}"
    fi
fi

# 完了メッセージ
echo ""
echo "=============================================="
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "リポジトリ: https://github.com/${ORGANIZATION}/${REPO_NAME}"
echo "ローカル: ./${REPO_NAME}"
echo ""
echo "次のステップ:"
echo "1. main.texを編集して文書を作成"
echo "2. git add, commit, pushで変更を保存"
echo "3. GitHub Actionsで自動的にPDFが生成されます"
echo ""
echo "ブランチ保護: ${ENABLE_PROTECTION}"
echo "=============================================="