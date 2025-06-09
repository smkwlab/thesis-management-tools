# 論文リポジトリ 簡単セットアップ

## セットアップ方法

### 方法1: 対話形式で実行（最も簡単）

**Windows (PowerShell) / macOS (Terminal)**:
```bash
docker run -it --rm smkwlab/thesis-setup:latest
```

実行後、学籍番号の入力を求められます。

### 方法2: 学籍番号を直接指定

```bash
docker run -it --rm smkwlab/thesis-setup:latest k21rs001
```
※ `k21rs001` を自分の学籍番号に変更してください

初回実行時は GitHub にログインする必要があります。

### 方法3: 高度な設定

#### 組織を指定してリポジトリ作成
```bash
docker run -it --rm -e TARGET_ORG=my-university smkwlab/thesis-setup:latest
```

#### テンプレートリポジトリを指定
```bash
docker run -it --rm -e TEMPLATE_REPO=my-org/my-template smkwlab/thesis-setup:latest
```

#### GitHub Token を使用（2回目以降）
```bash
docker run -it --rm -e GITHUB_TOKEN=YOUR_TOKEN smkwlab/thesis-setup:latest k21rs001
```

#### 複数の環境変数を組み合わせ
```bash
docker run -it --rm \
  -e TARGET_ORG=my-university \
  -e TEMPLATE_REPO=my-university/thesis-template \
  -e GITHUB_TOKEN=YOUR_TOKEN \
  smkwlab/thesis-setup:latest k21rs001
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