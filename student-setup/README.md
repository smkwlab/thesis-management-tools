# 論文リポジトリ セットアップ

学生が自分のGitHub認証で論文リポジトリを作成するためのDockerベースのツールです。

## 🎓 学生の方へ

**ワンライナー実行でリポジトリを作成してください：**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh)"
```

学籍番号指定：
```bash
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/student-setup/setup-oneliner.sh)"
```

**前提条件:**
- Windows: WSL + Docker Desktop
- macOS: Docker Desktop
- GitHub CLI は不要（Docker内で自動インストール）

## 🔧 開発者向け情報

このディレクトリには以下のファイルが含まれています：

- **setup-oneliner.sh**: クロスプラットフォーム対応エントリーポイント
- **setup-thesis.sh**: Docker内で実行されるメインスクリプト
- **Dockerfile**: Ubuntu 22.04 + GitHub CLI の実行環境

## 高度な設定

環境変数で動作をカスタマイズできます：

```bash
# 組織を指定
TARGET_ORG=my-org STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL ...)"

# テンプレートリポジトリを指定
TEMPLATE_REPO=my-org/my-template STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL ...)"

# ブランチを指定（開発用）
THESIS_BRANCH=feature-branch STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL ...)"
```

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

## セットアップ後の作業

リポジトリ作成後、以下の手順で論文執筆を開始：

1. **リポジトリをクローン**:
   ```bash
   git clone https://github.com/smkwlab/学籍番号-sotsuron.git
   cd 学籍番号-sotsuron
   ```

2. **VS Code で開く**:
   ```bash
   code .
   ```

3. **DevContainer で開く**: VS Code で「Reopen in Container」を選択

4. **論文執筆開始！**