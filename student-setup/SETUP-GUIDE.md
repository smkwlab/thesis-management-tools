# 論文リポジトリセットアップガイド（学生用）

## 必要なソフトウェア

### Windows
1. **Git for Windows**: https://gitforwindows.org/
2. **GitHub CLI**: https://cli.github.com/
3. **Docker Desktop**: https://www.docker.com/products/docker-desktop/
4. **VS Code**: https://code.visualstudio.com/

### macOS
1. **Homebrew** (ターミナルで実行):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
2. **GitHub CLI**:
   ```bash
   brew install gh
   ```
3. **Docker Desktop**: https://www.docker.com/products/docker-desktop/
4. **VS Code**: https://code.visualstudio.com/

## セットアップ手順

### 1. GitHub にログイン

**Windows (PowerShell) / macOS (Terminal)**:
```bash
gh auth login
```
- 「GitHub.com」を選択
- 「HTTPS」を選択
- 「Login with a web browser」を選択
- 表示されるコードをコピーしてブラウザでログイン

### 2. リポジトリ作成

**自分の学籍番号に置き換えて実行してください！**

#### 卒業論文の場合 (k??rs???)
```bash
# 学籍番号を設定（自分の番号に変更！）
STUDENT_ID="k21rs001"
REPO_NAME="${STUDENT_ID}-sotsuron"

# リポジトリ作成
gh repo create $REPO_NAME --template smkwlab/sotsuron-template --private --clone
cd $REPO_NAME

# 不要ファイル削除
rm -f thesis.tex abstract.tex
```

#### 修士論文の場合 (k??gjk??)
```bash
# 学籍番号を設定（自分の番号に変更！）
STUDENT_ID="k21gjk01"
REPO_NAME="${STUDENT_ID}-thesis"

# リポジトリ作成
gh repo create $REPO_NAME --template smkwlab/sotsuron-template --private --clone
cd $REPO_NAME

# 不要ファイル削除
rm -f sotsuron.tex gaiyou.tex example*.tex
```

### 3. LaTeX環境セットアップ

**Windows (PowerShell)**:
```powershell
# aldcスクリプトをダウンロードして実行
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/smkwlab/aldc/main/aldc" -OutFile "aldc.sh"
bash aldc.sh
Remove-Item aldc.sh
```

**macOS (Terminal)**:
```bash
# aldcスクリプトを実行
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/aldc/main/aldc)"
```

### 4. ブランチ設定

**Windows (PowerShell) / macOS (Terminal)**:
```bash
# 初期ブランチ作成
git checkout -b initial-empty
git rm -rf . 2>$null
git commit --allow-empty -m "初期状態"
git push -u origin initial-empty

# 作業ブランチ
git checkout main
git checkout -b 0th-draft
git push -u origin 0th-draft

# レビューブランチ
git checkout -b review-branch
git push -u origin review-branch

# 0th-draftに戻る
git checkout 0th-draft
```

### 5. VS Code で開く

```bash
code .
```

VS Code が開いたら:
1. 左下の「><」アイコンをクリック
2. 「Reopen in Container」を選択
3. コンテナが起動するまで待つ（初回は5-10分）

## トラブルシューティング

### "command not found" エラー
- GitHub CLI がインストールされているか確認
- Windows: 新しいPowerShellウィンドウを開く
- macOS: `brew install gh` を実行

### Docker エラー
- Docker Desktop が起動しているか確認
- Windows: システムトレイのDockerアイコンを確認
- macOS: メニューバーのDockerアイコンを確認

### 権限エラー
- `gh auth status` で認証状態を確認
- 必要に応じて `gh auth login` を再実行

## 質問・サポート

- 指導教員に連絡
- [thesis-management-tools](https://github.com/smkwlab/thesis-management-tools) のIssueに投稿