# Troubleshooting Guide

This document provides troubleshooting information for common issues in thesis-management-tools.

## Common Issues

### GitHub CLI Authentication Problems
- Verify GitHub CLI is installed: `command -v gh`
- Check authentication status: `gh auth status`
- Re-authenticate if needed: `gh auth login`
- Refresh expired tokens: `gh auth refresh`

### Multiple Account Issues
- Check active account: `gh api user --jq .login`
- Switch accounts: `gh auth switch --user target-username`
- Verify organization access: `gh org list`
- Check TARGET_ORG environment variable

### Docker Authentication Problems
- Verify Docker Desktop is running
- Ensure host GitHub CLI authentication is complete
- Test with `DEBUG=1` for detailed output
- Check token passing: `echo $GH_TOKEN` (in container)

### Repository Creation Failures
- Verify student ID format matches patterns
- Check GitHub API rate limits
- Validate template repository access
- Confirm organization membership and permissions

### File Cleanup Issues
- Test student ID pattern matching
- Verify template file structure
- Check file permissions and Git operations

## Debug Commands

### Authentication Debugging
```bash
# Check host authentication status
gh auth status
gh api user --jq .login

# Test multiple account scenarios
gh auth list
gh auth switch --user target-username

# Test token validity manually
gh auth token | gh auth login --with-token
```

### Docker Debugging
```bash
# Test Docker container with token
docker run -it --rm -e GH_TOKEN="$(gh auth token)" thesis-creator bash

# Check GitHub CLI in container (with token)
docker run --rm -e GH_TOKEN="$(gh auth token)" thesis-creator gh auth status
```

### Repository Creation Debugging
```bash
# Enable debug mode for detailed output
DEBUG=1 STUDENT_ID=k21rs001 /bin/bash -c "$(curl -fsSL ...)"

# Verify student ID patterns
echo "k21rs001" | grep -E "k[0-9]{2}rs[0-9]{3}" && echo "undergraduate" || echo "graduate"

# Test TARGET_ORG scenarios
TARGET_ORG=your-username STUDENT_ID=k21rs001 ./setup.sh
```

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

## Shell Command Gotchas

### Backticks in gh pr create/edit
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