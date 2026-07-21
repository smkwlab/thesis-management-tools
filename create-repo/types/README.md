# types/ — 文書タイプ定義

`main.sh` が `DOC_TYPE` に応じて `types/<type>.conf` を 1 つだけ source する。
新しい文書タイプの追加は、原則として **conf を 1 ファイル追加し、`main.sh` の
whitelist case と `setup.sh` の whitelist に 1 行ずつ足すだけ**で完結する
（タイプ固有の判定・プロンプトが必要な場合のみ `main.sh` にヘルパーを足す）。

## conf が定義するもの（これ以外を定義しないこと）

### 変数

| 変数 | 意味 |
|------|------|
| `SCRIPT_TITLE` / `SCRIPT_EMOJI` | `init_script_common` に渡すタイトルと絵文字 |
| `STUDENT_ID_EXAMPLES` | 学籍番号プロンプトの例示（空なら既定文言） |
| `RUN_ALDC` | aldc による LaTeX 環境セットアップを行うか（HTML 系は false） |
| `SETUP_AUTO_ASSIGN` | 組織メンバー向け auto-assign 設定を追加するか |
| `USE_DRAFT_FLOW` | main + 0th-draft の draft PR サイクルを使うか |
| `TEMPLATE_BASENAME` | テンプレートリポジトリ名（org 部分を除く） |
| `TEMPLATE_ORG_POLICY` | `follow`（実行 org に追従）か `smkwlab`（固定） |

`TEMPLATE_REPO` 環境変数による上書きと `REVIEW_FLOW` オプトイン（latex）の
適用は `main.sh` 側で行う。

### 関数（3 つとも必須）

| 関数 | 契約 |
|------|------|
| `decide_repo_name` | `REPO_NAME`（とタイプ固有変数）を設定する |
| `build_commit_message` | `COMMIT_MESSAGE` を設定する |
| `print_next_steps` | 完了メッセージを表示する |

**呼び出し順序は `decide_repo_name` → `build_commit_message` → `print_next_steps`**
（`main.sh` のメインフローが保証する）。後続の関数は先行の関数が設定した
タイプ固有変数（`THESIS_TYPE` / `ISE_REPORT_NUM` / `DOCUMENT_NAME` /
`POSTER_NAME`）を参照してよい。

このほか、関数から参照してよい `main.sh` / `common-lib.sh` 側の名前:

- 変数: `STUDENT_ID`、`TEMPLATE_REPOSITORY`、`REPO_PATH`（`print_next_steps`
  時点で設定済み）、`USE_DRAFT_FLOW`（`REVIEW_FLOW` 上書き後の値）
- 関数: `is_individual_mode`、`print_completion_message`、`log_*`、および
  `main.sh` のタイプ固有ヘルパー（`determine_thesis_type` など）。
  **明示名**で呼ぶこと。eval や動的関数名解決は禁止

書き込んでよいのは契約に挙げた変数（`REPO_NAME` / `COMMIT_MESSAGE` /
タイプ固有変数）だけ。それ以外への代入や、共通フローの順序に依存する
副作用を持たないこと。

## 逐語保存

プロンプト・コミットメッセージ・完了メッセージの文言は、学生リポジトリの
初期履歴・実行ログに残る。**既存タイプの文言は 1 文字も変えないこと**
（文言を変える場合は、その変更自体を目的とする PR で行う）。
