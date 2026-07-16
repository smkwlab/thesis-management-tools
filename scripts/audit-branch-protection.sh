#!/bin/bash
#
# Branch Protection Audit Script
#
# レジストリ（thesis-student-registry の data/registry.json）と GitHub の
# 実設定を突き合わせ、乖離を検出する（issue #531）。
#
# クローズ時ガード（verify-protection-on-close.yml、issue #530）のセーフティ
# ネット: 登録依頼 Issue を経由しないリポジトリ作成や、設定後の保護解除、
# registry 記録との乖離を定期的に検出する。
#
# Usage:
#   ./audit-branch-protection.sh            # 乖離があれば Issue を起票/追記
#   ./audit-branch-protection.sh --dry-run  # レポートを標準出力のみ（検証用）
#
# Environment:
#   REGISTRY_REPO  レジストリデータリポジトリ（owner/repo。
#                  default: smkwlab/thesis-student-registry）。
#                  監査対象リポジトリの owner はこの値の owner を使用する
#   REPORT_REPO    乖離レポート Issue の起票先（owner/repo。
#                  default: $GITHUB_REPOSITORY、無ければ
#                  smkwlab/student-repo-management）
#
# 監査対象:
#   - repository_type が sotsuron / master / ise のエントリ（保護必須種別）
#   - archived リポジトリは対象外（過年度分の恒常的なノイズを防ぐ）
#
# 分類:
#   critical  main が実際に未保護（本来あってはならない状態）
#   drift     実際は保護済みだが registry の protection_status が不一致
#   stale     registry に存在するが GitHub にリポジトリが無い
#   errors    一時的なエラーで確認できなかった（判定保留）

set -eu

REGISTRY_REPO="${REGISTRY_REPO:-smkwlab/thesis-student-registry}"
REPORT_REPO="${REPORT_REPO:-${GITHUB_REPOSITORY:-smkwlab/student-repo-management}}"
AUDIT_ISSUE_TITLE="🔍 ブランチ保護監査: 乖離を検出"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

org="${REGISTRY_REPO%%/*}"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "レジストリを取得中: ${REGISTRY_REPO}"
registry=$(gh api "repos/${REGISTRY_REPO}/contents/data/registry.json" \
    --jq '.content' | base64 -d)

# 保護必須種別（sotsuron / master / ise）のみ監査対象
mapfile -t repos < <(echo "$registry" | jq -r '
    to_entries[]
    | select(.value.repository_type as $t | ["sotsuron", "master", "ise"] | index($t))
    | .key')

log "監査対象: ${#repos[@]} リポジトリ（保護必須種別のみ）"

checked=0
skipped_archived=0

for name in "${repos[@]}"; do
    reg_status=$(echo "$registry" | jq -r --arg r "$name" \
        '.[$r].protection_status // "(未記録)"')

    # リポジトリの存在と archived を確認
    if ! archived=$(gh api "repos/${org}/${name}" --jq '.archived' 2>&1); then
        if echo "$archived" | grep -q "HTTP 404"; then
            echo "- \`${name}\`: レジストリに存在するが GitHub にリポジトリが無い" \
                >> "$workdir/stale.txt"
        else
            echo "- \`${name}\`: リポジトリ情報の取得に失敗（判定保留）" \
                >> "$workdir/errors.txt"
        fi
        continue
    fi

    if [ "$archived" = "true" ]; then
        skipped_archived=$((skipped_archived + 1))
        continue
    fi

    checked=$((checked + 1))

    # main の保護状態を実確認（404 = 未保護、それ以外のエラーは判定保留）
    if prot_err=$(gh api "repos/${org}/${name}/branches/main/protection" 2>&1 >/dev/null); then
        if [ "$reg_status" != "protected" ]; then
            echo "- \`${org}/${name}\`: 実際は保護済みだが registry の記録は \`${reg_status}\`" \
                >> "$workdir/drift.txt"
        fi
    elif echo "$prot_err" | grep -q "HTTP 404"; then
        echo "- \`${org}/${name}\`: main が未保護（registry の記録: \`${reg_status}\`）" \
            >> "$workdir/critical.txt"
    else
        echo "- \`${name}\`: 保護状態の確認に失敗（判定保留）" >> "$workdir/errors.txt"
    fi
done

log "確認完了: ${checked} 件（archived スキップ: ${skipped_archived} 件）"

if [ ! -s "$workdir/critical.txt" ] && [ ! -s "$workdir/drift.txt" ] && \
   [ ! -s "$workdir/stale.txt" ] && [ ! -s "$workdir/errors.txt" ]; then
    log "✅ 乖離はありません"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        echo "## ブランチ保護監査: 乖離なし（${checked} 件確認）" >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 0
fi

# レポート本文の組み立て
{
    echo "定期監査（issue #531）で registry と GitHub 実設定の乖離を検出しました。"
    echo ""
    if [ -s "$workdir/critical.txt" ]; then
        echo "## 🚨 未保護（要対応）"
        echo ""
        cat "$workdir/critical.txt"
        echo ""
        echo "対応: \`scripts/setup-branch-protection.sh <repo>\` を実行" \
             "（registry-manager が PATH にあれば registry 記録まで自動）。"
        echo "過年度分など監査対象から外すべきものは、リポジトリを archive してください。"
        echo ""
    fi
    if [ -s "$workdir/drift.txt" ]; then
        echo "## 📝 registry 記録の乖離"
        echo ""
        cat "$workdir/drift.txt"
        echo ""
        echo "対応: \`registry-manager protect <repo>\` で記録を更新。"
        echo ""
    fi
    if [ -s "$workdir/stale.txt" ]; then
        echo "## 👻 レジストリの孤児エントリ"
        echo ""
        cat "$workdir/stale.txt"
        echo ""
        echo "対応: リポジトリ名の変更・削除を確認し、\`registry-manager update / remove\` で整合を取る。"
        echo ""
    fi
    if [ -s "$workdir/errors.txt" ]; then
        echo "## ⚠️ 確認できなかったもの（判定保留）"
        echo ""
        cat "$workdir/errors.txt"
        echo ""
    fi
    echo "---"
    echo "確認: ${checked} 件 / archived スキップ: ${skipped_archived} 件 /" \
         "実行: $(date '+%Y-%m-%d %H:%M:%S %Z')"
} > "$workdir/report.md"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    cat "$workdir/report.md" >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$DRY_RUN" = "true" ]; then
    log "--dry-run: 以下のレポートを出力のみ（Issue は起票しません）"
    echo "========================================"
    cat "$workdir/report.md"
    exit 0
fi

# 既存の open な監査 Issue があればコメント追記（毎週の重複起票を防ぐ）
existing=$(gh issue list --repo "$REPORT_REPO" --state open \
    --search "in:title ブランチ保護監査" \
    --json number --jq '.[0].number // empty')

if [ -n "$existing" ]; then
    log "既存の監査 Issue #${existing} にコメントを追記します"
    gh issue comment "$existing" --repo "$REPORT_REPO" --body-file "$workdir/report.md"
else
    log "監査 Issue を起票します"
    gh issue create --repo "$REPORT_REPO" \
        --title "$AUDIT_ISSUE_TITLE" \
        --body-file "$workdir/report.md"
fi

log "⚠️ 乖離を検出しました。詳細はレポート Issue を参照してください"
