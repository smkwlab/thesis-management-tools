#!/usr/bin/env bash
#
# validate-type-confs.sh
#
# create-repo/types/*.conf が契約（create-repo/types/README.md）を守っている
# ことを機械検証する。各 conf を clean な bash で source し、定義された変数・
# 関数が契約の一覧と**完全一致**することを確認する:
# - 契約外の名前を定義していない（ORGANIZATION 等の共通変数の誤上書き検出）
# - 契約の名前をすべて定義している（必須 3 関数・必須変数の欠落検出）
# - TEMPLATE_ORG_POLICY が follow / smkwlab のいずれかである
#
# main.sh は関与しない（source 時点の宣言だけを見る静的な契約検査。文言の
# 逐語保存はレビューで担保する）。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TYPES_DIR="${REPO_ROOT}/create-repo/types"

ALLOWED_VARS="RUN_ALDC SCRIPT_EMOJI SCRIPT_TITLE SETUP_AUTO_ASSIGN STUDENT_ID_EXAMPLES TEMPLATE_BASENAME TEMPLATE_ORG_POLICY USE_DRAFT_FLOW"
ALLOWED_FUNCS="build_commit_message decide_repo_name print_next_steps"

fail=0
for conf in "${TYPES_DIR}"/*.conf; do
    name=$(basename "$conf")
    # clean な bash で source し、宣言差分と TEMPLATE_ORG_POLICY を出力させる。
    # env -i で親環境を遮断する（共通変数の「新規定義」を確実に差分に出すため）
    # 内側シェルの死（構文エラー・set -u の未定義参照など）は per-conf の NG に
    # 変換し、後続 conf の検査を続ける（|| で受けないと外側の set -e が全体を止め、
    # 診断が出ないまま残りが未検査になる）
    if ! out=$(env -i bash --noprofile --norc -c '
        set -u
        conf="$1"
        # スナップショット用の自前変数は差分から除外する
        before_vars=$(compgen -v | sort)
        source "$conf" || exit 3
        after_vars=$(compgen -v | sort)
        # comm -13 は「source で新規定義された名前」だけを検出する（既存名の
        # unset は対象外。clean シェルのため保護すべき既存名は元々ほぼ無い）
        new_vars=$(comm -13 <(printf "%s\n" "$before_vars") <(printf "%s\n" "$after_vars") \
                   | grep -v -x -e before_vars -e after_vars || true)
        new_funcs=$(declare -F | awk "{print \$3}" | sort)
        # $(echo $var) のクォート無しは意図的: 改行区切りをスペース区切り 1 行に
        # 正規化して ALLOWED_* と比較する（順序は直前の sort が保証）
        echo "VARS:$(echo $new_vars)"
        echo "FUNCS:$(echo $new_funcs)"
        echo "POLICY:${TEMPLATE_ORG_POLICY:-<unset>}"
    ' _ "$conf"); then
        echo "NG  $name: source に失敗しました（構文エラーまたは実行時エラー）"
        fail=1
        continue
    fi
    vars=$(sed -n 's/^VARS://p' <<<"$out")
    funcs=$(sed -n 's/^FUNCS://p' <<<"$out")
    policy=$(sed -n 's/^POLICY://p' <<<"$out")

    err=""
    [ "$vars" = "$ALLOWED_VARS" ] || err+=" 変数が契約と不一致: [$vars]"
    [ "$funcs" = "$ALLOWED_FUNCS" ] || err+=" 関数が契約と不一致: [$funcs]"
    case "$policy" in follow|smkwlab) ;; *) err+=" TEMPLATE_ORG_POLICY が不正: $policy" ;; esac

    if [ -z "$err" ]; then
        echo "OK  $name"
    else
        echo "NG  $name:$err"
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    echo "❌ types conf の契約違反があります（create-repo/types/README.md 参照）" >&2
    exit 1
fi
echo "✅ all type confs conform to the contract"
