# GitHub CLI (gh) のインストール

GitHub CLI は、リポジトリ作成スクリプト (`setup.sh`) の実行に必要なツールです。

## macOS

Homebrew を使用してインストール：

```bash
brew install gh
```

## Windows (WSL)

WSL (Ubuntu/Debian) 内で公式リポジトリからインストール：

```bash
# 公式リポジトリのセットアップ
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# インストール
sudo apt update
sudo apt install gh
```

**注意**: Windows では WSL 内で全ての操作を実行してください。

## インストール確認

```bash
gh --version
```

バージョン情報が表示されればインストール成功です。

## 認証

```bash
gh auth login
```

### 認証手順

1. `GitHub.com` を選択
2. `HTTPS` を選択
3. `Login with a web browser` を選択
4. 表示されたワンタイムコードをコピー
5. ブラウザが自動で開くので、コードを入力して認証完了

### 認証確認

```bash
gh auth status
```

`Logged in to github.com` と表示されれば認証成功です。

## 参考

- [GitHub CLI 公式サイト](https://cli.github.com/)
- [GitHub CLI ドキュメント](https://cli.github.com/manual/)
