# CLAUDE.md

Administrative tools and workflows for thesis supervision at Kyushu Sangyo University. Provides Docker-based student repository creation and GitHub-based review systems.

## Quick Start

### Student Repository Creation
```bash
# Create thesis repository (zero dependencies)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# With student ID specified
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# For weekly reports
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-wr.sh)"
```

### Branch Protection Setup (Faculty)
```bash
# Individual student setup
./scripts/setup-branch-protection.sh k21rs001

# Check protection status
gh repo view smkwlab/k21rs001-sotsuron --json branchProtectionRules
```

## Key Files & Structure

```
create-repo/
├── setup.sh              # Public entry point for thesis
├── setup-wr.sh           # Public entry point for weekly reports
├── main.sh               # Thesis creation script
└── main-wr.sh            # Weekly report creation script

scripts/
├── setup-branch-protection.sh    # Branch protection for individual student
├── process-pending-issues.sh     # Batch processing of pending repository requests
├── bulk-setup-protection.sh      # Bulk branch protection setup
├── update-review-branch.sh       # Emergency manual review branch update
├── update-student-registry.sh    # Registry maintenance utilities
└── validate-yaml.sh              # YAML/GitHub Actions validation

## Data Management Integration

**IMPORTANT**: Student data management has been consolidated into `thesis-student-registry`:

- **Student registry**: `thesis-student-registry/data/repositories.json`
- **Management tool**: `registry-manager` (Elixir escript)
- **Monitoring tool**: `thesis-monitor` (Elixir escript)

All operations now use GitHub API for safe, atomic data management instead of local files.

## Student ID Patterns

```bash
# Undergraduate: k##rs### → sotsuron-template
k21rs001, k22rs123, k23rs999

# Graduate: k##gjk## → sotsuron-template  
k21gjk01, k22gjk15, k23gjk99

# Weekly reports: any pattern → wr-template
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