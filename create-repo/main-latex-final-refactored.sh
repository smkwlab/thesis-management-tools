#!/bin/bash
# 汎用LaTeXリポジトリセットアップスクリプト（最終リファクタリング版）

set -e

# 共通ライブラリの読み込み
source ./common-lib.sh

# 共通初期化
init_script_common "汎用LaTeXリポジトリセットアップツール" "📝"

# 個別表示メッセージ
if [ "$INDIVIDUAL_MODE" = true ]; then
    echo -e "${BLUE}   - ブランチ保護: 無効（デフォルト）${NC}"
    echo -e "${BLUE}   - Registry登録: 無効${NC}"
else
    echo -e "${GREEN}   - ブランチ保護: 無効（デフォルト）${NC}"
    echo -e "${GREEN}   - Registry登録: 有効${NC}"
fi

# ブランチ保護設定の確認（環境変数でオプトイン）
ENABLE_PROTECTION="${ENABLE_PROTECTION:-false}"
[ "$ENABLE_PROTECTION" = "true" ] && echo -e "${YELLOW}⚠️ ブランチ保護が有効化されています（上級者向け）${NC}"

# 組織設定（共通関数使用）
ORGANIZATION=$(determine_organization)

# テンプレートリポジトリの設定
TEMPLATE_REPOSITORY="${ORGANIZATION}/latex-template"
echo -e "${GREEN}✓ テンプレートリポジトリ: $TEMPLATE_REPOSITORY${NC}"

# 学籍番号の入力（共通関数使用）
STUDENT_ID=$(read_student_id "$1")

# 学籍番号の正規化と検証（共通関数使用）
STUDENT_ID=$(normalize_student_id "$STUDENT_ID") || exit 1
echo -e "${GREEN}✓ 学籍番号: $STUDENT_ID${NC}"

# ドキュメント名の入力
read_document_name() {
    if [ -n "$DOCUMENT_NAME" ]; then
        echo -e "${GREEN}✓ ドキュメント名: $DOCUMENT_NAME（環境変数指定）${NC}"
        return 0
    fi
    
    echo ""
    echo "📝 ドキュメント名を入力してください (デフォルト: latex):"
    echo "   例: research-note, report2024, experiment-log"
    read -p "> " DOCUMENT_NAME
    
    DOCUMENT_NAME="${DOCUMENT_NAME:-latex}"
    
    if ! [[ "$DOCUMENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}❌ ドキュメント名は英数字、ハイフン、アンダースコアのみ使用可能です${NC}"
        DOCUMENT_NAME=""
        read_document_name
    fi
}

read_document_name
REPO_NAME="${STUDENT_ID}-${DOCUMENT_NAME}"

# 組織アクセス確認（共通関数使用）
check_organization_access "$ORGANIZATION"

# リポジトリパス決定（共通関数使用）
REPO_PATH=$(determine_repository_path "$ORGANIZATION" "$REPO_NAME")

# リポジトリの存在確認
if gh repo view "$REPO_PATH" >/dev/null 2>&1; then
    echo -e "${RED}❌ リポジトリ $REPO_PATH は既に存在します${NC}"
    exit 1
fi

# 作成確認（共通関数使用）
confirm_creation "$REPO_PATH" || exit 0

# リポジトリ作成（共通関数使用）
echo ""
echo "📁 リポジトリを作成中..."
create_repository "$REPO_PATH" "$TEMPLATE_REPOSITORY" "public" "true" || exit 1
cd "$REPO_NAME"

# main.texのカスタマイズ
echo "📄 main.texをカスタマイズ中..."
AUTHOR_NAME="${AUTHOR_NAME:-著者名}"

cat > main.tex << EOF
\\documentclass[dvipdfmx,uplatex,a4paper,10pt]{jsarticle}

%% 基本パッケージ
\\usepackage{graphicx}                    % 図表挿入
\\usepackage{amsmath,amssymb}            % 数式
\\usepackage{url}                        % URL表示
\\usepackage{enumitem}                   % リスト調整
\\usepackage{textcomp}                   % 追加記号サポート

%% 日本語フォント設定
\\usepackage[deluxe]{otf}
\\usepackage[noalphabet,unicode,haranoaji]{pxchfon}

%% レイアウト設定
\\usepackage[top=25mm,bottom=25mm,left=25mm,right=25mm]{geometry}
\\linespread{1.2}                        % 行間調整

%% リスト設定
\\renewcommand{\\labelitemi}{\$\\bullet\$}
\\renewcommand{\\labelitemii}{\$\\circ\$}

%% ハイパーリンク設定（シンプル）
\\usepackage[hidelinks]{hyperref}

%% 文書情報
\\title{${DOCUMENT_NAME}}
\\author{${AUTHOR_NAME}}
\\date{\\today}

\\begin{document}
\\maketitle

% 目次（簡素化）
\\tableofcontents
\\newpage

\\section{はじめに}

これは${DOCUMENT_NAME}の文書です。

\\subsection{このテンプレートの特徴}

\\begin{itemize}
\\item シンプルな構造で使いやすい
\\item 日本語に最適化されたレイアウト
\\item 基本的な機能を網羅
\\item カスタマイズが容易
\\end{itemize}

\\section{基本的な使い方}

\\subsection{文書の構成}

文書は\\texttt{section}と\\texttt{subsection}で構成します。必要に応じて\\texttt{subsubsection}も使用できます。

\\subsection{数式の記述}

数式は以下のように記述できます。

インライン数式: \$E = mc^2\$

独立した数式:
\\begin{equation}
(x - a)^2 + (y - b)^2 = r^2
\\label{eq:circle}
\\end{equation}

式~\\ref{eq:circle}は円の方程式です。

\\end{document}
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
latexmk main.tex
\`\`\`

## 📋 書き方のコツ

### 基本構造
- **\\\\section{}**: 大見出し
- **\\\\subsection{}**: 中見出し  
- **段落**: 空行で段落分け

### よく使う要素
- **箇条書き**: \\\\begin{itemize} \\\\item ... \\\\end{itemize}
- **数式**: \$...\$ （インライン）、\\\\begin{equation} ... \\\\end{equation} （独立）
- **図表**: \\\\includegraphics{} for 画像、tabular環境 for 表

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
    DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
    
    if gh api --method PUT -H "Accept: application/vnd.github+json" \
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

# Git設定（共通関数使用）
setup_git_auth || exit 1
setup_git_user "setup-latex@smkwlab.github.io" "LaTeX Setup Tool"

# 変更をコミットしてプッシュ（共通関数使用）
echo "📤 変更をコミット中..."
commit_and_push "Initial customization for ${DOCUMENT_NAME}

- Customize main.tex for ${DOCUMENT_NAME}
- Add project-specific README.md
- Author: ${AUTHOR_NAME}
- Student ID: ${STUDENT_ID}
" || exit 1

# Registry Manager連携（組織ユーザーのみ）
if [ "$INDIVIDUAL_MODE" = false ] && gh repo view "${ORGANIZATION}/thesis-student-registry" &>/dev/null; then
    echo "📊 Registry Managerに登録中..."
    echo -e "${YELLOW}⚠️ Registry Manager登録は手動で実行してください：${NC}"
    echo -e "   cd thesis-student-registry"
    echo -e "   ./registry_manager/registry-manager add ${REPO_NAME} ${STUDENT_ID} latex active general"
fi

# 完了メッセージ
echo ""
echo "=============================================="
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "リポジトリ: https://github.com/${REPO_PATH}"
echo "ローカル: ./${REPO_NAME}"
echo ""
echo "次のステップ:"
echo "1. main.texを編集して文書を作成"
echo "2. git add, commit, pushで変更を保存"
echo "3. GitHub Actionsで自動的にPDFが生成されます"
echo ""
echo "ブランチ保護: ${ENABLE_PROTECTION}"
echo "=============================================="