# リリース運用ガイド

`student-repo-management` のセットアップスクリプト（`create-repo/setup.sh`）の
**再現性・安全性**を高めるためのリリース（バージョン固定）運用をまとめる。

## 背景

学生のリポジトリ作成は、`main` 上のスクリプトを `curl` で取得してそのまま実行する
（いわゆる `curl | bash`）。利便性は高い一方で、次の懸念がある。

- **再現性**: `main` を参照するため、時間経過でスクリプト内容が変わり得る。
- **安全性**: 内容を確認せずにリモートスクリプトを実行する形になりやすい。

これに対し、**タグ（バージョン）で固定した状態でも実行できる**仕組みを用意している。
既定は利便性重視で `main`、必要に応じて明示的に固定版を使う、という両立方針。

## 固定の二段構造

セットアップは 2 段階のリモート取得で構成されるため、完全な固定には両方を揃える必要がある。

1. **`setup.sh` 本体の取得**（`curl` の URL）
   `https://raw.githubusercontent.com/smkwlab/student-repo-management/<ref>/create-repo/setup.sh`
   - `<ref>` を `main` から `v1.0.0` 等のタグに変えると、本体が固定される。
2. **本体が内部で `clone` する内容**（`setup.sh` 内の `SETUP_REF`）
   - `setup.sh` には `EMBEDDED_REF` が埋め込まれており、リリース時にタグへ書き換えられる。
   - `main` ブランチ上では `EMBEDDED_REF="main"` のまま。
   - 環境変数 `UNIVERSAL_REF` / `UNIVERSAL_BRANCH` で上書き可能。
   - 優先順位: `UNIVERSAL_REF` > `UNIVERSAL_BRANCH` > `EMBEDDED_REF`(=既定 `main`)

タグ付き URL から取得した `setup.sh` は `EMBEDDED_REF` がそのタグになっているため、
**URL を固定するだけで①②の両方が同一タグに揃う**（環境変数の指定は不要）。

## バージョニング方針（SemVer）

[Semantic Versioning](https://semver.org/lang/ja/) に従い `vMAJOR.MINOR.PATCH` を用いる。

- **MAJOR**: 学生のワンライナー手順・対応文書タイプ・必須環境など、後方非互換な変更
- **MINOR**: 後方互換のある機能追加（新しい文書タイプ追加、オプション追加など）
- **PATCH**: 後方互換のバグ修正・ドキュメント修正

## リリース手順（手動）

`EMBEDDED_REF` をタグ値に固定したコミットへタグを打つ。`main` の `EMBEDDED_REF` は
`main` のまま保ちたいので、**リリース用コミットを `main` にマージせずタグだけを push する**。

例として `v1.0.0` をリリースする場合：

```bash
# 0. main を最新化
git checkout main
git pull

# 1. リリース用の作業ブランチを作成（main にはマージしない）
git checkout -b release-v1.0.0

# 2. EMBEDDED_REF をリリースタグに固定
#    create-repo/setup.sh の  EMBEDDED_REF="main"  を  EMBEDDED_REF="v1.0.0"  に変更
git add create-repo/setup.sh
git commit -m "Release v1.0.0"

# 3. このコミットにタグを打つ
git tag -a v1.0.0 -m "Release v1.0.0"

# 4. タグのみを push（release ブランチは push 不要・破棄してよい）
git push origin v1.0.0

# 5. main へ戻る（EMBEDDED_REF="main" のまま維持）
git checkout main
git branch -D release-v1.0.0

# 6. GitHub Release を作成（リリースノートを添付）
gh release create v1.0.0 --title "v1.0.0" --notes "リリース内容..."

# 7. メジャー移動タグ v1 を当該リリースに合わせる（下記「メジャー移動タグ」参照）
#    vX.Y.Z は annotated tag のため、^{} でコミットへ剥がして軽量タグにする
#    （v1 がタグオブジェクトを指すと解決が不安定になるのを防ぐ）
git tag -f v1 v1.0.0^{}
git push origin v1 --force
```

> **重要**: リリース用コミット（`EMBEDDED_REF="v1.0.0"`）を `main` にマージしないこと。
> マージすると `main` の `setup.sh` が古いタグを指し続けてしまう。
> `main` 上の `EMBEDDED_REF` は常に `"main"` を保つ。

## メジャー移動タグ（`v1` など）

利用側テンプレート（`sotsuron-template` 等）のコマンド例は、安定したメジャー系列を
指す**移動タグ** `vN`（例: `v1`）を参照する（GitHub Actions の `@v4` と同じ考え方）。

- `vN` は「その時点の最新の `vN.*.*` リリース」を指す。リリースのたびに最新へ動かす。
- これにより、パッチ／マイナーリリースのたびに各テンプレートの README を更新する必要が
  なくなる。**README の更新が必要になるのはメジャー更新（`v1` → `v2`）のときだけ**。
- `vN` は単なるポインタ用タグであり、GitHub Release は作らない（Release は `vX.Y.Z` のみ）。

### 二段固定との関係

`vN` は「どのリリースコミットを取得するか」を選ぶだけで、固定の正確さは損なわれない。

- `…/v1/create-repo/setup.sh` を取得すると、`v1` が指すコミット（例: `v1.0.0`）の
  `setup.sh` が得られる。その `EMBEDDED_REF` は**正確なバージョン**（`v1.0.0`）なので、
  内部 clone も `v1.0.0` に固定される。
- `v1` を `v1.1.0` のコミットへ動かせば、`…/v1/…` は自動的に `v1.1.0` を取得・固定する
  （`EMBEDDED_REF` は各リリースコミットに焼き込まれているため）。

### 運用ルール

- **パッチ／マイナー**（`v1.0.1`, `v1.1.0` など）: 上記リリース手順の最後に
  `git tag -f v1 vX.Y.Z^{} && git push origin v1 --force` で `v1` を前進させる
  （`^{}` で annotated tag をコミットへ剥がし、`v1` を必ずコミットに向ける）。
- **メジャー**（`v2.0.0`）: 新しい移動タグ `v2` を作成し、利用側テンプレートの
  README コマンド例を `/v1/` → `/v2/` に更新する（旧 `v1` は据え置きで互換維持）。

```bash
# 例: v1 系の新リリース vX.Y.Z 後に v1 を前進させる
# ^{} で annotated tag をコミットへ剥がし、v1 が必ずリリースコミットを指すようにする
git tag -f v1 vX.Y.Z^{}
git push origin v1 --force
```

### 検証

タグ作成後、固定版の `setup.sh` が正しいタグを指していることを確認する。

```bash
# タグ付き URL の EMBEDDED_REF がタグ値になっているか
curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/v1.2.0/create-repo/setup.sh \
  | grep '^EMBEDDED_REF='
# => EMBEDDED_REF="v1.2.0"

# main 側は "main" のまま
curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/main/create-repo/setup.sh \
  | grep '^EMBEDDED_REF='
# => EMBEDDED_REF="main"
```

## 利用側（学生・教員）での使い方

### 既定（最新版 / 利便性重視）

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/main/create-repo/setup.sh)" bash thesis
```

### 固定版（再現性重視）

URL のブランチ部分をタグに変えるだけで、本体・内部 clone とも当該タグに固定される。

```bash
# 最新の v1 系（移動タグ。テンプレート README はこちらを採用）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/v1/create-repo/setup.sh)" bash thesis

# 特定パッチに完全固定（厳密な再現が必要な場合）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/v1.2.0/create-repo/setup.sh)" bash thesis
```

### 参照先を明示的に上書きしたい場合

```bash
# タグ / コミットSHA / ブランチを明示指定（内部 clone の参照先を上書き）
UNIVERSAL_REF=v1.0.0 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/student-repo-management/main/create-repo/setup.sh)" bash thesis
```

## 安全性に関する注意

- スクリプトの内容は公開リポジトリでいつでも確認できる。
  実行前に内容を確認したい場合は、上記の URL をブラウザ等で開いて確認できる。
- 再現性・監査性が必要な運用（手順書への記載など）では、`main` ではなく固定版（タグ）を推奨する。
