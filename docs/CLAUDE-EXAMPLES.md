# Command Examples and Samples

This document provides detailed command examples and usage samples for student-repo-management.

## Student Repository Creation Examples

### Basic Usage
```bash
# Self-service repository creation (zero dependencies required)
bash <(curl -fsSL https://repo-setup.smkwlab.net) thesis

# With student ID (specify thesis explicitly; setup.sh does not auto-detect the type)
STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net) thesis

# For weekly reports
STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net) wr
```

### Universal Setup Script with Document Types
```bash
# Thesis repository
DOC_TYPE=thesis STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net)

# Weekly reports
DOC_TYPE=wr STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net)

# General LaTeX documents (organization mode)
DOC_TYPE=latex STUDENT_ID=k21rs001 DOCUMENT_NAME=research-note bash <(curl -fsSL https://repo-setup.smkwlab.net)

# General LaTeX documents (individual mode - no student ID required)
INDIVIDUAL_MODE=true DOC_TYPE=latex DOCUMENT_NAME=my-paper bash <(curl -fsSL https://repo-setup.smkwlab.net)

# ISE reports
DOC_TYPE=ise STUDENT_ID=k21rs001 ISE_REPORT_NUM=1 bash <(curl -fsSL https://repo-setup.smkwlab.net)
```

### Advanced Usage
```bash
# Debug mode for troubleshooting
DEBUG=1 STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net) thesis

# Multiple GitHub accounts support
# Create repository in personal account instead of smkwlab organization
TARGET_ORG=your-github-username STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net) thesis

# Switch GitHub CLI account before running (if multiple accounts exist)
gh auth switch --user target-username
STUDENT_ID=k21rs001 bash <(curl -fsSL https://repo-setup.smkwlab.net) thesis
```

## Development and Testing Examples

### Docker Operations
```bash
# Build and test Docker containers (single image for all document types)
docker build -f create-repo/Dockerfile -t thesis-creator .

# Test repository creation locally (DOC_TYPE selects the document type)
cd create-repo && docker run --rm -it -e DOC_TYPE=thesis thesis-creator k21rs001

# Test scripts directly (requires GitHub CLI)
cd create-repo && DOC_TYPE=thesis ./main.sh k21rs001
cd create-repo && DOC_TYPE=wr ./main.sh k21rs001
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
docker run --rm -it \
  -e DOC_TYPE="thesis" \
  -e TARGET_ORG="smkwlab" \
  -e DEBUG=1 \
  -e GH_TOKEN="$(gh auth token)" \
  thesis-creator k21rs001
```