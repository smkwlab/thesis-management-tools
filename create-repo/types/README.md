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

- `main.sh` のヘルパー（`is_individual_mode`、`determine_thesis_type` など）は
  **明示名**で呼んでよい。eval や動的関数名解決は禁止
- 共通フローの順序に依存する副作用を持たないこと

## 逐語保存

プロンプト・コミットメッセージ・完了メッセージの文言は、学生リポジトリの
初期履歴・実行ログに残る。**既存タイプの文言は 1 文字も変えないこと**
（文言を変える場合は、その変更自体を目的とする PR で行う）。
