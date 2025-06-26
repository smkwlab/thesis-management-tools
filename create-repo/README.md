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
TARGET_ORG=あなたのユーザー名 /bin/bash -c "$(curl -fsSL ...)"
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
