# 学生向け：ブラウザで論文リポジトリを作成する方法

## 🎯 概要

ブラウザだけで、あなた専用の論文執筆リポジトリを作成できます。
Docker のインストールやコマンド実行は不要です。

## 📋 手順

### 1. GitHub Actions ページにアクセス

以下のリンクをクリック：
👉 **[学生リポジトリ作成ページ](https://github.com/smkwlab/thesis-management-tools/actions/workflows/student-repo-setup.yml)**

### 2. ワークフローを実行

1. **「Run workflow」**ボタンをクリック
2. **学籍番号を入力**（例：`k21rs001`）
3. **「Run workflow」**をクリックして実行開始

### 3. 実行完了を待つ

- 約2-3分で完了します
- 進行状況は画面で確認できます
- 緑色のチェックマークが表示されたら完了

### 4. 作成されたリポジトリにアクセス

実行完了後、以下の形式でリポジトリが作成されます：
- **卒業論文**: `https://github.com/smkwlab/あなたの学籍番号-sotsuron`
- **修士論文**: `https://github.com/smkwlab/あなたの学籍番号-thesis`

## 📥 論文執筆の開始

### 1. リポジトリをクローン

```bash
# 学籍番号を自分のものに変更してください
git clone https://github.com/smkwlab/k21rs001-sotsuron.git
cd k21rs001-sotsuron
```

### 2. VS Code で開く

```bash
code .
```

### 3. DevContainer で開く

VS Code で以下を実行：
1. 左下の「><」アイコンをクリック
2. 「Reopen in Container」を選択
3. 初回は5-10分待つ（LaTeX環境のダウンロード）

### 4. 論文執筆開始！

- **卒業論文**: `sotsuron.tex` を編集
- **修士論文**: `thesis.tex` を編集

## 🆘 トラブルシューティング

### Q: ワークフローが見つからない
A: 以下を確認してください：
- GitHub にログインしているか
- smkwlab organization のメンバーか（招待を受けているか）

### Q: 実行が失敗する
A: 以下を確認してください：
- 学籍番号の形式が正しいか（`k21rs001` or `k21gjk01`）
- 同じ名前のリポジトリが既に存在していないか

### Q: VS Code でコンテナが開けない
A: 以下を確認してください：
- Docker Desktop が起動しているか
- Dev Containers 拡張機能がインストールされているか

## 📚 詳細な使い方

論文の書き方や Git の使い方は以下を参照：
👉 **[論文執筆ガイド](./WRITING-GUIDE.md)**

## 📞 サポート

質問があれば以下に連絡：
- 指導教員
- [Issues](https://github.com/smkwlab/thesis-management-tools/issues)（技術的な問題）