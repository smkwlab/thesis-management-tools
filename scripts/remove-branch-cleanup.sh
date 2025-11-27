#!/bin/bash
# Remove unnecessary latex-environment workflows from student repositories
#
# Removes the following workflows that are not needed in thesis repositories:
# - branch-cleanup.yml: Feature branch cleanup (thesis repos use draft branches)
# - pr-auto-cleanup.yml: PR merge logging (thesis repos don't merge PRs)
# - check-texlive-updates.yml: TeXLive update checker (development environment only)
# - update-release-branch.yml: Release branch updater (development environment only)
#
# Usage:
#   ./scripts/remove-branch-cleanup.sh              # Process all repositories
#   DRY_RUN=1 ./scripts/remove-branch-cleanup.sh    # Dry run mode (check only)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Removing unnecessary latex-environment workflows from student repositories ==="
echo ""

# Define workflows to remove
WORKFLOWS=(
    "branch-cleanup.yml"
    "pr-auto-cleanup.yml"
    "check-texlive-updates.yml"
    "update-release-branch.yml"
)

echo "Target workflows:"
for workflow in "${WORKFLOWS[@]}"; do
    echo "  - $workflow"
done
echo ""

# Check for dry run mode
if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "⚠️  DRY RUN MODE - No changes will be made"
    echo ""
fi

# Get thesis repositories from registry
echo "Fetching student repository list from thesis-student-registry..."
REPOS=$(gh api repos/smkwlab/thesis-student-registry/contents/data/repositories.json \
  --jq '.content' | base64 -d | \
  jq -r 'to_entries | map(select(.value.repository_type == "sotsuron" or .value.repository_type == "master")) | .[].key')

if [ -z "$REPOS" ]; then
    echo "❌ Error: No repositories found"
    exit 1
fi

TOTAL=$(echo "$REPOS" | wc -l | tr -d ' ')
PROCESSED=0
REMOVED=0
NOT_FOUND=0
FAILED=0

echo "Found $TOTAL student repositories"
echo ""

for repo in $REPOS; do
    PROCESSED=$((PROCESSED + 1))
    echo "[$PROCESSED/$TOTAL] Processing: $repo"

    REPO_REMOVED=0
    REPO_NOT_FOUND=0
    REPO_FAILED=0

    # Process each workflow file
    for workflow in "${WORKFLOWS[@]}"; do
        # Check if file exists
        FILE_SHA=$(gh api "repos/smkwlab/$repo/contents/.github/workflows/$workflow" \
                   --jq '.sha' 2>/dev/null || echo "")

        if [ -z "$FILE_SHA" ]; then
            echo "  ✓ $workflow not found (already clean)"
            REPO_NOT_FOUND=$((REPO_NOT_FOUND + 1))
            NOT_FOUND=$((NOT_FOUND + 1))
            continue
        fi

        if [ "${DRY_RUN:-0}" = "1" ]; then
            echo "  🔍 Would remove $workflow (SHA: ${FILE_SHA:0:7})"
            REPO_REMOVED=$((REPO_REMOVED + 1))
            REMOVED=$((REMOVED + 1))
            continue
        fi

        # Delete the file via GitHub API
        if gh api --method DELETE \
           "repos/smkwlab/$repo/contents/.github/workflows/$workflow" \
           -f message="Remove unnecessary latex-environment workflows

The following workflows were copied from latex-environment but are not
suitable for thesis repositories:

- branch-cleanup.yml: Feature branch cleanup (thesis repos use draft branches)
- pr-auto-cleanup.yml: PR merge logging (thesis repos don't merge PRs)
- check-texlive-updates.yml: TeXLive update checker (development only)
- update-release-branch.yml: Release branch updater (development only)

These workflows are designed for the latex-environment development workflow
and are not needed in student thesis repositories.

Related: thesis-management-tools#390, aldc#25" \
           -f sha="$FILE_SHA" \
           -f branch="main" >/dev/null 2>&1; then
            echo "  ✅ Removed $workflow"
            REPO_REMOVED=$((REPO_REMOVED + 1))
            REMOVED=$((REMOVED + 1))
        else
            echo "  ⚠️  Failed to remove $workflow"
            REPO_FAILED=$((REPO_FAILED + 1))
            FAILED=$((FAILED + 1))
        fi

        # Rate limiting: small delay between API calls
        sleep 1
    done

    # Summary for this repository
    if [ "$REPO_REMOVED" -gt 0 ] || [ "$REPO_FAILED" -gt 0 ]; then
        echo "  📊 Repository summary: removed=$REPO_REMOVED, not_found=$REPO_NOT_FOUND, failed=$REPO_FAILED"
    fi
    echo ""
done

echo ""
echo "=== Cleanup Summary ==="
echo "Total repositories processed: $TOTAL"
echo "Total workflow files already clean: $NOT_FOUND"

if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "Total workflow files that would be removed: $REMOVED"
else
    echo "Total workflow files successfully removed: $REMOVED"
    echo "Total workflow files failed to remove: $FAILED"
fi

echo ""
echo "Workflows targeted:"
for workflow in "${WORKFLOWS[@]}"; do
    echo "  - $workflow"
done
