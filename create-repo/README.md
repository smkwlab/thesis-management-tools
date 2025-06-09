# 論文リポジトリ セットアップ

学生が自分の論文リポジトリを作成するためのDockerベースのツールです。

## 🎓 学生のみなさんへ

**WSL上の bash または mac のターミナル上で以下の行を実行し、リポジトリを作成してください：**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
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

**基本的な流れ：**
1. GitHub Desktop でリポジトリをクローン
2. VS Code で開く
3. DevContainer で LaTeX 環境を起動
4. 論文執筆開始！

詳細な手順: 作成されたリポジトリの README または [sotsuron-template の執筆ガイド](https://github.com/smkwlab/sotsuron-template/blob/main/WRITING-GUIDE.md) を参照
