# 学生リポジトリ セットアップ

学生が自分の論文・レポートリポジトリを作成するためのDockerベースのツールです。

## 🎓 学生のみなさんへ

### 論文リポジトリ（卒業研究・修士論文）

**WSL上の bash または mac のターミナル上で以下の行を実行し、リポジトリを作成してください：**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

### 情報科学演習レポートリポジトリ

**情報科学演習I・II用のレポートリポジトリを作成する場合：**

```bash
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-ise.sh)"
```

※ `k21rs001` の部分を自分の学籍番号に変更してください。

### 週報リポジトリ

**研究週報用のリポジトリを作成する場合：**

```bash
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-wr.sh)"
```

**前提条件:**
- Windows: WSL + Docker Desktop
- macOS: Docker Desktop

## 再現性・安全性（固定版の利用）

これまでの `setup.sh` 実行コマンドは利便性を重視し、URL の `main`（最新版）から
スクリプトを取得します。ある時点の手順を確実に再現したい場合や、内容を固定して
実行したい場合は、**タグ（バージョン）で固定した版**を利用できます。

`setup.sh` の URL のブランチ部分（`main`）をタグに変えるだけで、スクリプト本体・
内部で取得する内容ともに同じバージョンに固定されます（文書タイプ引数の指定方法は
これまでと同じで、以下は論文 `thesis` の例です）。

```bash
# 最新の v1 系（移動タグ。安定版を使いたい場合の推奨。テンプレート README もこちら）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/v1/create-repo/setup.sh)" bash thesis

# 特定パッチに完全固定（厳密な再現が必要な場合）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/v1.0.0/create-repo/setup.sh)" bash thesis
```

> `v1` は「最新の v1 系リリース」を指す移動タグです（GitHub Actions の `@v4` と同様）。
> 完全に同一の内容を再現したい場合は `v1.0.0` のように具体的なバージョンを指定してください。

> 変更するのは **URL 内の `main` の部分だけ**です。コマンド末尾の引数（上の例では
> `bash thesis`。`bash` は `bash -c` のダミー引数 `$0`、`thesis` が実際の文書タイプ `$1`）や、
> 各コマンド先頭の環境変数（`STUDENT_ID=...` など）はそのまま残してください。

- スクリプトの内容は公開リポジトリでいつでも確認できます。実行前に内容を確認したい場合は、
  上記 URL をブラウザで開いて確認してください。
- 利用可能なバージョン（`v1.0.0` などの具体的なリリース）は [Releases](https://github.com/smkwlab/thesis-management-tools/releases) を参照してください。なお `v1` はそれらの最新を指す移動タグ（ポインタ）であり、Releases 一覧には個別の項目としては現れません。
- リリース運用の詳細は [docs/RELEASE.md](../docs/RELEASE.md) を参照してください。

## よくある質問

### Q: Docker Desktop が起動していないエラー
A: タスクバー/メニューバーの Docker アイコンを確認し、起動してください。

### Q: ブラウザが開かない
A: 手動で https://github.com/login/device を開いて、表示されたワンタイムコードを入力してください。

### Q: リポジトリはどこに作成される？
A: デフォルトでは `smkwlab` 組織に作成されます。環境変数 `TARGET_ORG` で変更可能です。

### Q: 組織への権限がないエラー
A: 組織の管理者に招待を依頼するか、個人アカウントに作成してください：
```bash
TARGET_ORG=あなたのユーザー名 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

### Q: エラーの詳細を確認したい
A: デバッグモードで実行すると詳細な情報が表示されます：

```bash
DEBUG=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

## セットアップ後の作業

リポジトリ作成後の詳しい手順は、作成されたリポジトリ内の README を参照してください。

### 論文執筆の流れ
1. GitHub Desktop でリポジトリをクローン
2. VS Code で開く
3. DevContainer で LaTeX 環境を起動
4. 論文執筆開始！

詳細な手順: 作成されたリポジトリの README または [sotsuron-template の執筆ガイド](https://github.com/smkwlab/sotsuron-template/blob/main/WRITING-GUIDE.md) を参照

### ISEレポート作成の流れ
1. GitHub Desktop でリポジトリをクローン
2. VS Code で開く（DevContainer環境が自動起動）
3. `1st-draft` ブランチを作成
4. `index.html` を編集してレポート作成
5. Pull Request を作成・提出
6. レビューフィードバックを確認・対応

詳細な手順: [ise-report-template のREADME](https://github.com/smkwlab/ise-report-template/blob/main/README.md) を参照

## 各リポジトリの特徴

| 種類 | 用途 | 期間 | 技術 | 学習目標 |
|------|------|------|------|----------|
| **論文** | 卒業研究・修士論文 | 1年 | LaTeX + textlint | 学術論文執筆 |
| **ISEレポート** | 情報科学演習I・II | 前期・後期 | HTML + textlint | Pull Request学習 |
| **週報** | 研究進捗報告 | 通年 | LaTeX + textlint | 継続的な報告 |
