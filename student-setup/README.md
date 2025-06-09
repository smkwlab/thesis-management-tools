# 論文リポジトリ セットアップ

学生が自分のGitHub認証で論文リポジトリを作成するためのDockerベースのツールです。

## 使用方法

### 1. Dockerイメージをビルド

```bash
git clone https://github.com/smkwlab/thesis-management-tools.git
cd thesis-management-tools/student-setup
docker build -t thesis-setup .
```

### 2. リポジトリ作成

```bash
# 対話形式で実行
docker run --rm -it thesis-setup

# 学籍番号を直接指定
docker run --rm -it thesis-setup k21rs001
```

### 3. GitHub認証

初回実行時はGitHub認証が必要です：
1. ワンタイムコードをメモ
2. https://github.com/login/device をブラウザで開く
3. コードを入力して認証完了

### 高度な設定

```bash
# 組織を指定
docker run --rm -it -e TARGET_ORG=my-org thesis-setup k21rs001

# テンプレートリポジトリを指定
docker run --rm -it -e TEMPLATE_REPO=my-org/my-template thesis-setup k21rs001
```

## よくある質問

### Q: Docker Desktop が起動していないエラー
A: タスクバー/メニューバーの Docker アイコンを確認し、起動してください。

### Q: GitHub へのログインが必要と表示される
A: 初回実行時は GitHub 認証が必要です。表示される指示に従ってください。

### Q: リポジトリはどこに作成される？
A: デフォルトでは `smkwlab` 組織（`https://github.com/smkwlab/学籍番号-sotsuron`）に作成されます。`TARGET_ORG` 環境変数で変更可能です。

### Q: 組織への権限がないエラー
A: 組織の管理者に招待を依頼するか、個人アカウントに作成してください：
```bash
docker run -e TARGET_ORG=あなたのユーザー名 smkwlab/thesis-setup:latest
```

## セットアップ後の作業

1. 作成されたリポジトリをクローン:
   ```bash
   git clone https://github.com/あなたのユーザー名/学籍番号-sotsuron.git
   cd 学籍番号-sotsuron
   ```

2. VS Code で開く:
   ```bash
   code .
   ```

3. VS Code で「Reopen in Container」を選択

4. 論文執筆開始！