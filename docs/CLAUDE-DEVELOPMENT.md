# Development Guide

This document provides detailed development guidance for thesis-management-tools.

## Architecture

### Docker-Based Repository Creation
The system uses containerized scripts to eliminate local dependencies:

**Prerequisites for students:**
- WSL + Docker Desktop (Windows) or Docker Desktop (macOS)
- GitHub CLI (recommended for improved experience)
- GitHub account with appropriate organization access

**Creation Process:**
1. **Host Authentication**: GitHub CLI authentication check and token retrieval on host
2. **Secure Token Transfer**: Authentication tokens passed to container via environment variables
3. **Repository creation**: From appropriate template (sotsuron-template or wr-template)
4. **File cleanup**: Automatic removal of unused files based on student ID pattern
5. **Environment setup**: LaTeX devcontainer integration via aldc script
6. **Workflow initialization**: Review system setup with initial branches

### Enhanced Authentication System
The authentication system provides a secure and user-friendly experience:

**Authentication Flow:**
1. **Host-side Validation**: Check GitHub CLI installation and authentication status
2. **Multiple Account Detection**: Automatically detect and validate multiple GitHub accounts
3. **Token Extraction**: Securely retrieve authentication tokens using `gh auth token`
4. **Container Security**: Pass tokens via environment variables, no persistent storage
5. **Fallback Support**: Maintain browser authentication for environments without GitHub CLI

**Multiple Account Support:**
```bash
# Automatic account detection with conflict resolution
CURRENT_USER=$(gh api user --jq .login)
if [ "$CURRENT_USER" != "$TARGET_ORG" ]; then
    # Provide clear guidance for account switching
    echo "gh auth switch --user $TARGET_ORG"
fi
```

**Security Features:**
- No persistent authentication storage in containers
- Automatic token validation before use
- Clear permission error handling for student accounts
- Secure token passing via environment variables

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

## Security Considerations

### Enhanced Authentication Security
- **Host-side Authentication**: GitHub CLI authentication performed on user's machine
- **Secure Token Transfer**: Tokens passed via environment variables, not stored in containers
- **Token Lifecycle**: Tokens are temporary and automatically expire
- **No Persistent Storage**: Containers do not store authentication information
- **Fallback Security**: Browser-based authentication maintained as secure fallback

### Container Security
- Minimal container images with only required tools
- No persistent storage of credentials
- Temporary token-based authentication only
- Regular base image updates
- Process isolation prevents token leakage

### Access Control
- Repository creation limited to authenticated GitHub users
- Multiple account support with proper validation
- Template access controlled via GitHub permissions
- Faculty review permissions managed through GitHub teams
- Student permission limitations handled gracefully
- Audit trail through GitHub activity logs

### Token Security Considerations
- **Environment Variable Exposure**: Tokens visible in process lists (acceptable for personal PC use)
- **Scope Limitation**: Tokens use minimal required scopes
- **Automatic Validation**: Token validity checked before use
- **Future Enhancement**: Consider file-based token transfer for enhanced security

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