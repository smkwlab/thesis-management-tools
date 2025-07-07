# ドキュメント更新案 - Universal Setup Script移行

## 概要

個別setup-*.shスクリプトを廃止し、Universal Setup Script（setup.sh）に統一することで、保守性向上と重複コード削除を実現する。

## 更新対象ファイル

### 1. thesis-management-tools/CLAUDE.md

#### 現在の問題
- 個別スクリプト（setup-thesis.sh, setup-wr.sh, setup-latex.sh）への参照
- 古いコマンド例の記載
- setup-ise.shの記載なし

#### 更新案
```markdown
### Student Repository Creation
```bash
# Universal Setup Script (推奨) - 全文書タイプ対応
DOC_TYPE=thesis STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# 文書タイプ別の使用例
DOC_TYPE=thesis  /bin/bash -c "$(curl -fsSL ...)"     # 論文リポジトリ
DOC_TYPE=wr      /bin/bash -c "$(curl -fsSL ...)"     # 週間報告
DOC_TYPE=latex   /bin/bash -c "$(curl -fsSL ...)"     # 汎用LaTeX
DOC_TYPE=ise     /bin/bash -c "$(curl -fsSL ...)"     # 情報科学演習

# 環境変数による詳細設定
DOC_TYPE=latex DOCUMENT_NAME=research-note AUTHOR_NAME="山田太郎" /bin/bash -c "$(curl -fsSL ...)"
```

### 2. Key Files & Structure セクション

#### 更新案
```
create-repo/
├── setup.sh              # Universal Setup Script - 全文書タイプ対応
├── main-thesis.sh        # 論文作成スクリプト
├── main-wr.sh            # 週間報告作成スクリプト
├── main-latex.sh         # 汎用LaTeX作成スクリプト
├── main-ise.sh           # 情報科学演習作成スクリプト
├── common-lib.sh         # 共通ライブラリ
├── Dockerfile-thesis     # 論文用Dockerイメージ
├── Dockerfile-wr         # 週間報告用Dockerイメージ
├── Dockerfile-latex      # 汎用LaTeX用Dockerイメージ
└── Dockerfile-ise        # 情報科学演習用Dockerイメージ
```

### 3. 新規セクション追加

#### Document Type Configuration
```markdown
## Document Type Configuration

Universal Setup Scriptは環境変数 `DOC_TYPE` で文書タイプを指定します：

### 対応文書タイプ
- **thesis**: 卒業論文・修士論文
  - テンプレート: sotsuron-template
  - 機能: PR-based review, branch protection
  
- **wr**: 週間報告
  - テンプレート: wr-template  
  - 機能: LaTeX environment setup
  
- **latex**: 汎用LaTeX文書
  - テンプレート: latex-template
  - 機能: カスタマイズ可能な文書・作者名
  
- **ise**: 情報科学演習レポート
  - テンプレート: ise-report-template
  - 機能: HTML-based reports, Pull Request learning

### 環境変数オプション
```bash
# LaTeX文書用
DOCUMENT_NAME=research-note    # 文書名指定
AUTHOR_NAME="山田太郎"          # 作者名指定
ENABLE_PROTECTION=true         # ブランチ保護有効化

# 情報科学演習用
ASSIGNMENT_TYPE=exercise       # 課題タイプ
ISE_REPORT_NUM=1              # レポート番号（1 or 2）
```

## 移行のメリット

### ✅ 保守性向上
- **単一コードベース**: 1つのスクリプトで全機能を提供
- **重複排除**: 1000行以上の重複コードを削除
- **統一したバグ修正**: 一箇所の修正で全文書タイプに反映

### ✅ 開発効率向上
- **新機能追加**: setup.shのみの更新で完了
- **テスト簡素化**: 単一スクリプトのテストのみ
- **ドキュメント統一**: 共通のトラブルシューティング

### ✅ ユーザー体験向上
- **統一インターフェース**: 同じコマンド体系で学習効果
- **一貫した動作**: 全文書タイプで統一されたエラーハンドリング
- **拡張性**: 新しい文書タイプの追加が容易

## 影響範囲

### 削除対象ファイル
- `create-repo/setup-thesis.sh`
- `create-repo/setup-wr.sh` 
- `create-repo/setup-latex.sh`
- `create-repo/setup-ise.sh`

### 既存URLへの影響
- **互換性問題なし**: DOC_TYPE環境変数を追加するだけで移行完了
- **段階的移行**: 既存URLを段階的に新形式に更新可能

## 実装スケジュール

1. **Phase 1**: ドキュメント更新（CLAUDE.md等）
2. **Phase 2**: 個別スクリプトの削除
3. **Phase 3**: 各テンプレートREADME更新（必要に応じて）
4. **Phase 4**: 動作確認とテスト

## リスク評価

### ❌ リスク無し
- Universal Setup Scriptは完全に上位互換
- 既存の3つのテンプレートで実証済み
- 機能的に同等以上の処理を提供