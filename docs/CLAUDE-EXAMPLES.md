# Command Examples and Samples

This document provides detailed command examples and usage samples for thesis-management-tools.

## Student Repository Creation Examples

### Basic Usage
```bash
# Self-service repository creation (zero dependencies required)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# With student ID for automatic thesis type detection
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# For weekly reports
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-wr.sh)"
```

### Universal Setup Script with Document Types
```bash
# Thesis repository
DOC_TYPE=thesis STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# Weekly reports
DOC_TYPE=wr STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# General LaTeX documents (organization mode)
DOC_TYPE=latex STUDENT_ID=k21rs001 DOCUMENT_NAME=research-note /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# General LaTeX documents (individual mode - no student ID required)
INDIVIDUAL_MODE=true DOC_TYPE=latex DOCUMENT_NAME=my-paper /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# ISE reports
DOC_TYPE=ise STUDENT_ID=k21rs001 ISE_REPORT_NUM=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

### Advanced Usage
```bash
# Debug mode for troubleshooting
DEBUG=1 STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# Multiple GitHub accounts support
# Create repository in personal account instead of smkwlab organization
TARGET_ORG=your-github-username STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# Switch GitHub CLI account before running (if multiple accounts exist)
gh auth switch --user target-username
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

## Development and Testing Examples

### Docker Operations
```bash
# Build and test Docker containers
docker build -f create-repo/Dockerfile -t thesis-creator .
docker build -f create-repo/Dockerfile-wr -t wr-creator .

# Test repository creation locally
cd create-repo && docker run --rm -e STUDENT_ID=k21rs001 thesis-creator

# Test scripts directly (requires GitHub CLI)
cd create-repo && ./main.sh k21rs001
cd create-repo && ./main-wr.sh k21rs001
```

### Manual Repository Management (Emergency Use)
```bash
# Update review branch manually (emergency only)
./scripts/update-review-branch.sh {repo-name} {branch-name}

# Validate repository structure
gh repo view {org}/{repo-name} --json defaultBranch,visibility
```

## Student ID Pattern Examples

### Valid Patterns
```bash
# Undergraduate thesis (卒業論文)
k21rs001, k22rs123, k20rs999

# Graduate thesis (修士論文)
k21gjk01, k22gjk99, k20gjk15

# Weekly reports (any pattern accepted)
k21rs001, k22gjk01, any-valid-id
```

### Pattern Testing
```bash
# Test undergraduate pattern
echo "k21rs001" | grep -E "k[0-9]{2}rs[0-9]{3}" && echo "Valid undergraduate ID"

# Test graduate pattern  
echo "k21gjk01" | grep -E "k[0-9]{2}gjk[0-9]{2}" && echo "Valid graduate ID"

# Combined test
STUDENT_ID="k21rs001"
if [[ "$STUDENT_ID" =~ ^k[0-9]{2}rs[0-9]{3}$ ]]; then
    echo "Undergraduate thesis"
elif [[ "$STUDENT_ID" =~ ^k[0-9]{2}gjk[0-9]{2}$ ]]; then
    echo "Graduate thesis"
else
    echo "Invalid or unknown pattern"
fi
```

## Authentication Examples

### GitHub CLI Setup
```bash
# Basic authentication
gh auth login

# Check current status
gh auth status

# List all accounts
gh auth list

# Switch between accounts
gh auth switch --user username

# Get current user info
gh api user --jq .login
```

### Token Management
```bash
# Get current token (for debugging)
gh auth token

# Test token validity
echo "$(gh auth token)" | gh auth login --with-token

# Refresh expired token
gh auth refresh
```

## Environment Variable Examples

### Repository Creation Variables
```bash
# Target organization (default: smkwlab)
export TARGET_ORG="your-organization"

# Student ID (for automated processing)
export STUDENT_ID="k21rs001"

# Debug mode (for troubleshooting)
export DEBUG=1

# GitHub token (automatically handled)
export GH_TOKEN="$(gh auth token)"
```

### Docker Environment Variables
```bash
# Run with all variables
docker run --rm \
  -e STUDENT_ID="k21rs001" \
  -e TARGET_ORG="smkwlab" \
  -e DEBUG=1 \
  -e GH_TOKEN="$(gh auth token)" \
  thesis-creator
```