# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the thesis-management-tools repository.

## Repository Overview

This repository contains **administrative tools and workflows for thesis supervision** at Kyushu Sangyo University. It provides Docker-based student repository creation, faculty review workflows, and management documentation for the thesis-environment ecosystem. The tools enable zero-dependency, self-service thesis repository creation and sophisticated GitHub-based review systems.

## Key Commands

### Student Repository Creation
```bash
# Self-service repository creation (zero dependencies required)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# With student ID for automatic thesis type detection
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# For weekly reports
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup-wr.sh)"

# Debug mode for troubleshooting
DEBUG=1 STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# Multiple GitHub accounts support
# Create repository in personal account instead of smkwlab organization
TARGET_ORG=your-github-username STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"

# Switch GitHub CLI account before running (if multiple accounts exist)
gh auth switch --user target-username
STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/smkwlab/thesis-management-tools/main/create-repo/setup.sh)"
```

### Development and Testing
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

## Architecture

### Docker-Based Repository Creation
The system uses containerized scripts to eliminate local dependencies:

**Prerequisites for students:**
- WSL + Docker Desktop (Windows) or Docker Desktop (macOS)
- No local Git, GitHub CLI, or other tools required

**Creation Process:**
1. **Authentication**: GitHub CLI authentication via browser in container
2. **Repository creation**: From appropriate template (sotsuron-template or wr-template)
3. **File cleanup**: Automatic removal of unused files based on student ID pattern
4. **Environment setup**: LaTeX devcontainer integration via aldc script
5. **Workflow initialization**: Review system setup with initial branches

### Student ID Pattern Recognition
```bash
# Undergraduate thesis (卒業論文)
k??rs??? (e.g., k21rs001) → sotsuron-template → keeps sotsuron.tex, gaiyou.tex, examples

# Graduate thesis (修士論文)  
k??gjk?? (e.g., k21gjk01) → sotsuron-template → keeps thesis.tex, abstract.tex only

# Weekly reports
Any pattern → wr-template → weekly report structure
```

### Review Workflow System
Sophisticated GitHub Actions-based supervision:

**Branch Strategy:**
- `initial`: Base state for clean diff tracking
- `0th-draft`, `1st-draft`, `2nd-draft`, etc.: Sequential development
- `review-branch`: Persistent branch for holistic review (auto-updated)

**Faculty Workflow:**
- **Differential review**: Each draft PR shows changes from previous version
- **Comprehensive review**: `review-branch` PR shows entire document content
- **GitHub suggestions**: Direct edit capabilities for faculty
- **Auto-management**: Students close PRs after addressing feedback

## File Structure Conventions

### Repository Structure
```
create-repo/
├── Dockerfile                  # Main thesis repository creation
├── Dockerfile-wr               # Weekly report repository creation
├── main.sh                     # Thesis creation script
├── main-wr.sh                  # Weekly report creation script
├── setup.sh                    # Public entry point for thesis
├── setup-wr.sh                 # Public entry point for weekly reports
└── README.md                   # Usage instructions

scripts/
├── update-review-branch.sh     # Emergency manual review branch update
└── (other management scripts)

docs/
├── PR-REVIEW-GUIDE.md          # Faculty review workflow guide
├── TEACHER-GUIDE.md            # Complete faculty documentation
└── (other documentation)
```

### Template Integration
- **sotsuron-template**: Primary template for undergraduate/graduate theses
- **wr-template**: Weekly report template
- **latex-environment**: LaTeX development environment (via aldc)

## Development Workflow

### For Script Updates
1. **Test locally** with sample student IDs
2. **Verify Docker builds** work across platforms
3. **Test authentication flow** in containerized environment
4. **Validate file cleanup** for different student ID patterns
5. **Test integration** with GitHub repository creation

### For Workflow Enhancements
1. **Test review system** with sample repositories
2. **Verify branch management** automation
3. **Validate faculty workflow** documentation
4. **Test error handling** and edge cases

### For Documentation Updates
1. **Keep faculty guides current** with GitHub interface changes
2. **Update student instructions** for clarity
3. **Document troubleshooting** procedures
4. **Maintain screenshot accuracy** in guides

## Student Workflow (Automated)

### Repository Creation Phase
1. **Run one-liner command** (Docker handles everything)
2. **Browser authentication** with GitHub (automatic)
3. **Repository creation** from appropriate template
4. **File cleanup** based on thesis type
5. **LaTeX environment setup** via aldc integration
6. **Initial branch setup** for review workflow

### Development Phase
```
Phase 1: Thesis Writing
0th-draft (outline) → 1st-draft → 2nd-draft → ... → submit tag

Phase 2: Abstract Writing  
abstract-1st → abstract-2nd → abstract completion

Phase 3: Final Submission
Further improvements → Final PR → Faculty approval → final-* tag → Auto-merge
```

## Faculty Workflow

### Review Process
1. **Monitor draft PRs** for incremental changes
2. **Use review-branch PR** for holistic document review
3. **Provide feedback** via GitHub comments and suggestions
4. **Track progress** through branch sequence
5. **Final approval** through GitHub workflow

### Management Tools
- **Progress tracking**: Via GitHub repository insights
- **Deadline management**: Through milestone and project features
- **Quality assurance**: Automated LaTeX compilation and textlint checks
- **Communication**: Integrated with GitHub notification system

## Testing Guidelines

### Local Testing
```bash
# Test Docker builds
docker build -f create-repo/Dockerfile -t test-creator .
docker build -f create-repo/Dockerfile-wr -t test-wr .

# Test scripts with sample IDs
cd create-repo
./main.sh k21rs999  # Test undergraduate
./main.sh k21gjk99  # Test graduate  
./main-wr.sh k21rs999  # Test weekly report

# Test file cleanup logic
echo "k21rs001" | grep -E "k[0-9]{2}rs[0-9]{3}"  # Should match
echo "k21gjk01" | grep -E "k[0-9]{2}gjk[0-9]{2}"  # Should match
```

### Integration Testing
- Test complete student onboarding flow
- Verify repository creation with all template types
- Test review workflow with sample content
- Validate faculty tools and documentation accuracy

### Error Handling Testing
```bash
# Test with invalid student IDs
DEBUG=1 STUDENT_ID=invalid ./main.sh

# Test without Docker
STUDENT_ID=k21rs001 ./setup.sh  # Should handle gracefully

# Test network issues
# (Simulate offline conditions and verify error messages)
```

## Troubleshooting

### Common Issues

**Docker authentication problems:**
- Verify Docker Desktop is running
- Check GitHub CLI authentication in container
- Test with `DEBUG=1` for detailed output

**Repository creation failures:**
- Verify student ID format matches patterns
- Check GitHub API rate limits
- Validate template repository access

**File cleanup issues:**
- Test student ID pattern matching
- Verify template file structure
- Check file permissions and Git operations

### Debug Commands
```bash
# Enable debug mode
DEBUG=1 STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL ...)"

# Test Docker container manually
docker run -it --rm thesis-creator bash

# Check GitHub CLI in container
docker run --rm thesis-creator gh auth status

# Verify student ID patterns
echo "k21rs001" | grep -E "k[0-9]{2}rs[0-9]{3}" && echo "undergraduate" || echo "graduate"
```

## Security Considerations

### Container Security
- Minimal container images with only required tools
- No persistent storage of credentials
- GitHub authentication via secure browser flow
- Regular base image updates

### Access Control
- Repository creation limited to authenticated GitHub users
- Template access controlled via GitHub permissions
- Faculty review permissions managed through GitHub teams
- Audit trail through GitHub activity logs

## Ecosystem Integration

### Related Repositories
- **sotsuron-template**: Primary thesis template
- **wr-template**: Weekly report template  
- **latex-environment**: Development environment
- **aldc**: LaTeX environment deployment tool

### Coordination Points
- Template updates require coordination with creation scripts
- LaTeX environment changes may affect repository setup
- Faculty workflow changes require documentation updates
- Student onboarding process spans multiple repositories

## Emergency Procedures

### Repository Creation Failures
1. **Check system status** (GitHub, Docker Hub)
2. **Verify template availability**
3. **Test with debug mode** for detailed error information
4. **Manual repository creation** as fallback
5. **Document issues** for future prevention

### Review System Problems
1. **Use manual review branch update script**
2. **Verify GitHub Actions functionality**
3. **Check repository permissions and settings**
4. **Communicate with affected faculty and students**
5. **Document resolution steps**

## MCP Tools Usage

### GitHub Operations
Use MCP tools instead of `gh` command for GitHub operations:
- **Development**: Use `mcp__gh-toshi__*` tools for development work
- **Student testing**: Use `mcp__gh-k19__*` tools only when testing student workflows

### Shell Command Gotchas

#### Backticks in gh pr create/edit
When using `gh pr create` or `gh pr edit` with `--body`, backticks (`) in the body text are interpreted as command substitution by the shell. This causes errors like:
```
permission denied: .devcontainer/devcontainer.json
command not found: 2025c-test
```

**Solution**: Always escape backticks with backslashes when using them in PR bodies:
```bash
# Wrong - will cause errors
gh pr create --body "Updated `file.txt` to version `1.2.3`"

# Correct - escaped backticks
gh pr create --body "Updated \`file.txt\` to version \`1.2.3\`"
```
## Contributing Guidelines

### Script Development
- Test with multiple student ID patterns
- Ensure cross-platform Docker compatibility
- Maintain error handling and user feedback
- Document all environment variables and options

### Documentation
- Keep faculty guides synchronized with GitHub interface
- Update screenshots and examples regularly
- Maintain troubleshooting procedures
- Include step-by-step instructions

### Testing Requirements
- All scripts must pass integration tests
- Docker containers must build successfully
- Error handling must be comprehensive
- Documentation must be accurate and current

### Review Process
- Test changes with sample student repositories
- Verify faculty workflow compatibility
- Check ecosystem integration points
- Validate security and access control measures