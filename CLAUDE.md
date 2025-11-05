# CLAUDE.md

Administrative tools and workflows for thesis supervision at Kyushu Sangyo University. Provides Docker-based student repository creation and GitHub-based review systems.

## Quick Start

### Student Repository Creation
```bash
# Universal Setup Script - All document types supported (Recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash thesis

# With student ID specified (environment variable)
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash thesis

# Document type specific usage
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash thesis   # Thesis repository
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash wr       # Weekly reports
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash latex    # General LaTeX
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash ise      # ISE reports

# Environment variable style (Legacy, still supported)
DOC_TYPE=thesis /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# Advanced configuration with environment variables
DOCUMENT_NAME=research-note AUTHOR_NAME="Taro Yamada" STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash latex

# Individual mode for personal LaTeX documents (no student ID required)
INDIVIDUAL_MODE=true DOCUMENT_NAME=my-paper /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)" bash latex
```

### Branch Protection Setup (Faculty)
```bash
# Individual student setup
./scripts/setup-branch-protection.sh k21rs001-sotsuron

# Check protection status
gh repo view smkwlab/k21rs001-sotsuron --json branchProtectionRules
```

## Key Files & Structure

```
create-repo/
├── setup.sh              # Universal Setup Script - All document types
├── main-thesis.sh        # Thesis creation script
├── main-wr.sh            # Weekly report creation script
├── main-latex.sh         # General LaTeX document creation script
├── main-ise.sh           # ISE report creation script
├── common-lib.sh         # Shared functions and utilities
├── Dockerfile-thesis     # Docker image for thesis
├── Dockerfile-wr         # Docker image for weekly reports
├── Dockerfile-latex      # Docker image for general LaTeX documents
└── Dockerfile-ise        # Docker image for ISE reports

scripts/
├── setup-branch-protection.sh    # Branch protection for individual student
├── process-pending-issues.sh     # Batch processing of pending repository requests
├── bulk-setup-protection.sh      # Bulk branch protection setup
├── update-review-branch.sh       # Emergency manual review branch update
└── validate-yaml.sh              # YAML/GitHub Actions validation

## Data Management Integration

**IMPORTANT**: Student data management has been consolidated into `thesis-student-registry`:

- **Student registry**: `thesis-student-registry/data/repositories.json`
- **Management tool**: `registry-manager` (Elixir escript)
- **Monitoring tool**: `thesis-monitor` (Elixir escript)

All operations now use GitHub API for safe, atomic data management instead of local files.

## Document Type Configuration

Universal Setup Script uses `DOC_TYPE` environment variable to specify document type:

### Supported Document Types
- **thesis**: Undergraduate/Graduate thesis (sotsuron-template)
- **wr**: Weekly reports (wr-template)
- **latex**: General LaTeX documents (latex-template)
- **ise**: Information Science Exercise reports (ise-report-template)

### Environment Variable Options
```bash
# LaTeX document configuration
DOCUMENT_NAME=research-note    # Custom document name
AUTHOR_NAME="Taro Yamada"      # Author name
ENABLE_PROTECTION=true         # Enable branch protection

# Individual mode behavior (DOC_TYPE=latex only)
INDIVIDUAL_MODE=true           # Skip student ID input, create in personal account
# Note: When INDIVIDUAL_MODE=true, any STUDENT_ID argument is ignored
# Note: Individual mode automatically disables Registry Manager integration

# ISE report configuration
ASSIGNMENT_TYPE=exercise       # Assignment type
ISE_REPORT_NUM=1              # Report number (1 or 2)
```

## Student ID Patterns

```bash
# Undergraduate: k##rs### → DOC_TYPE=thesis
k21rs001, k22rs123, k23rs999

# Graduate: k##gjk## → DOC_TYPE=thesis
k21gjk01, k22gjk15, k23gjk99

# Weekly reports: any pattern → DOC_TYPE=wr
# General LaTeX: any pattern → DOC_TYPE=latex
# ISE reports: any pattern → DOC_TYPE=ise
```

## Common Tasks

### Test Repository Creation
```bash
# Local testing
cd create-repo && ./main.sh k21rs999

# Docker testing
docker build -f create-repo/Dockerfile -t test-creator .
```

### Data Management (Registry Manager Integration)
```bash
# View repository registry status
cd thesis-student-registry
./thesis_monitor/thesis-monitor status

# Add new repository to registry
./registry_manager/registry-manager add k21rs001-sotsuron k21rs001 sotsuron active thesis

# Mark branch protection complete
./registry_manager/registry-manager protect k21rs001-sotsuron

# Update repository status
./registry_manager/registry-manager update k21rs001-sotsuron status completed
```

### Debug Authentication Issues
```bash
# Check GitHub CLI status
gh auth status && gh api user --jq .login

# Enable debug mode
DEBUG=1 STUDENT_ID=k21rs001 ./create-repo/setup.sh
```

### Emergency Manual Operations
```bash
# Manual review branch update
./scripts/update-review-branch.sh repo-name branch-name

# Validate repository structure
gh repo view smkwlab/repo-name --json defaultBranch,visibility
```

## Detailed Documentation

- **[Development Guide](docs/CLAUDE-DEVELOPMENT.md)** - Architecture, security, testing
- **[Troubleshooting](docs/CLAUDE-TROUBLESHOOTING.md)** - Common issues, debug commands
- **[Workflows](docs/CLAUDE-WORKFLOWS.md)** - Student/faculty workflows, ecosystem integration
- **[Command Examples](docs/CLAUDE-EXAMPLES.md)** - Detailed usage examples, patterns