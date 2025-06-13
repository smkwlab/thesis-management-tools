# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an administrative tools repository for managing LaTeX-based thesis supervision workflows at Kyushu Sangyo University's Faculty of Science and Engineering, Information Science Department. It provides batch creation and management tools for student thesis repositories with automated GitHub-based review workflows.

## Key Commands

### Student Repository Creation 

#### Individual Creation (Docker Script)
Students can create repositories using Docker environment with zero local dependencies:

**Prerequisites**: WSL + Docker Desktop (Windows) or Docker Desktop (macOS)

**One-liner execution**:
```bash
# Interactive mode (Homebrew-style)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# With student ID
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

Key features:
- Zero local dependencies (GitHub CLI installed in Docker)
- Interactive GitHub authentication within Docker container
- Student's own credentials used for repository creation
- Automatic template selection based on student ID pattern
- Complete LaTeX environment setup via aldc integration
- Cross-platform compatibility (Windows WSL, macOS, Linux)

#### Emergency Manual Review Branch Update
```bash
# Manual review branch update (emergency use only - GitHub Actions preferred)
./scripts/update-review-branch.sh {repo-name} {branch-name}
```

### Documentation Generation
```bash
# Generate HTML from markdown documentation
# (Currently manual process - PR-REVIEW-GUIDE.html exists but untracked)
```

## Architecture

### Automated Thesis Management System
The repository implements a sophisticated GitHub Actions-based workflow for thesis supervision:

1. **Student ID-Based Template Selection**: 
   - `k??rs???` pattern → Undergraduate thesis (sotsuron template)
   - `k??gjk??` pattern → Graduate thesis (master template)

2. **Intelligent File Cleanup**: Automatically removes unused template files based on thesis type to prevent student confusion

3. **Hybrid Review Workflow**:
   ```
   initial (review base)
    ├─ 0th-draft → 1st-draft → 2nd-draft → ... (sequential drafts)
    └─ review-branch (auto-updated with latest content)
   ```

4. **Dual Review System**:
   - **Individual Draft PRs**: Differential review (changes from previous version)
   - **Persistent Review PR**: Holistic review (entire thesis content)

### Repository Creation Process
The Docker-based student setup (`main.sh`) performs:
1. GitHub authentication via web browser workflow
2. Private repository creation from `smkwlab/sotsuron-template` template
3. Template file cleanup based on student ID pattern (undergraduate/graduate)
4. DevContainer setup via aldc script integration
5. Initial branch structure creation (`initial`, `0th-draft`, `review-branch`)
6. Git configuration with student's GitHub credentials

### Branch Management Strategy
- **Sequential Drafts**: Each draft branches from the previous (clear diff tracking)
- **Automatic Branch Creation**: Next draft branch auto-created upon PR submission
- **Parallel Writing Support**: Students can work on next draft while previous is under review
- **Abstract Management**: Separate branch sequence for thesis abstracts

## Student ID Patterns and Template Selection
- **Undergraduate**: `k??rs???` (e.g., k21rs001) → sotsuron-template files kept
- **Graduate**: `k??gjk??` (e.g., k21gjk01) → master-template files kept (now unified in sotsuron-template)

## Operational Notes

### Non-Merging Workflow
- PRs are used for review purposes only
- Students close PRs after addressing feedback (PRs are never merged)
- Review system maintains diff clarity through branch-from-branch strategy

### Faculty Review Process
- Multi-faculty coordination support
- GitHub Suggestion feature integration for direct edits
- Role-based review assignment capabilities
- Both incremental and comprehensive review tracks

### Emergency Procedures
- Manual review branch update script available for GitHub Actions failures
- Fallback mechanisms for automated workflow interruptions

## Dependencies

### Required Tools
- **GitHub CLI**: Repository creation and management
- **Git**: Version control operations
- **Bash**: Script execution environment
- **Docker**: DevContainer LaTeX environment (via aldc)

### Template Repositories
- `smkwlab/sotsuron-template`: Unified thesis template (primary)
- `smkwlab/master-template`: [DEPRECATED] Graduate template (functionality merged)

## File Structure Conventions

### Administrative Scripts
- `scripts/update-review-branch.sh`: Emergency manual override for GitHub Actions failures

### Repository Creation Scripts
- `create-repo/setup.sh`: Cross-platform entry point with browser integration
- `create-repo/main.sh`: Docker-based repository creation and environment setup
- `create-repo/Dockerfile`: Ubuntu-based container with GitHub CLI

### Documentation
- `docs/TEACHER-GUIDE.md`: Complete faculty workflow documentation
- `docs/PR-REVIEW-GUIDE.md`: GitHub PR review guide for beginners
- `docs/PR-REVIEW-GUIDE.html`: HTML version (untracked, generated manually)

### Security and Access
- All student repositories created as private
- Minimal collaborator permissions applied
- Branch protection available for critical branches