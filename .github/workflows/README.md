# PR Merge Validation Workflow

## Overview

This GitHub Actions workflow ensures that fixes merged into one branch have corresponding PRs in other monitored branches, preventing incomplete merges and regression risks.

## Features

- ✅ Validates cross-branch PR consistency
- 🔍 Extracts parent issue references (e.g., `#54321`)
- 🔄 Searches for matching PRs in comparison branches
- 🚫 Blocks merges when no matching PR exists
- ✋ Provides override mechanism for intentional single-branch merges
- 💬 Posts detailed validation results as PR comments

## Configuration

### Branch Configuration

Update the branch names in the workflow file (`.github/workflows/pr-merge-validation.yml`):

```yaml
env:
  PRIMARY_BRANCH: 'master'        # Change to your primary branch
  RELEASE_BRANCH: 'release-5.2.1' # Change to your current release branch
```

**Update these values for each release cycle.**

### Workflow Triggers

The workflow runs automatically when:
- A PR is opened
- A PR is synchronized (new commits pushed)
- A PR is reopened
- A PR is edited (title or description changed)

## How It Works

### 1. Issue Reference Extraction
The workflow searches the PR title and body for issue references matching the pattern `#12345`.

### 2. Branch Determination
- If PR targets `PRIMARY_BRANCH` → searches for matching PR in `RELEASE_BRANCH`
- If PR targets `RELEASE_BRANCH` → searches for matching PR in `PRIMARY_BRANCH`
- If PR targets other branches → validation is skipped

### 3. Matching PR Search
Uses GitHub CLI to search for open PRs in the comparison branch that contain the same issue reference.

### 4. Validation Result

#### ✅ PASSED - Matching PR Found
- Merge is allowed to proceed
- Success comment posted to PR
- Any blocking labels are removed

#### ⚠️ BLOCKED - No Matching PR Found
- Merge is blocked (workflow fails)
- Warning comment posted with override instructions
- Label `merge-blocked:missing-cross-branch-pr` is added

## Override Mechanism

When a fix is intentionally for a single branch, a reviewer can override the block:

### Steps to Override:

1. **Add the label** `approved:single-branch-merge` to the PR
2. **Post a comment** justifying the single-branch merge

**Example comment:**
```
Approved for single-branch merge. This fix is specific to master and does not 
apply to release-5.2.1 because it addresses a feature that only exists in master.
```

3. **Re-run the workflow** (push a new commit or close/reopen the PR)

### Override Label

Create the label in your repository:
- **Name:** `approved:single-branch-merge`
- **Description:** Approves PR for single-branch merge despite missing cross-branch PR
- **Color:** `#fbca04` (yellow)

## Required Permissions

The workflow requires these permissions (already configured):

```yaml
permissions:
  pull-requests: write  # To post comments and add labels
  issues: write         # To manage labels
  contents: read        # To read repository content
```

## Example Scenarios

### Scenario 1: Complete Fix (Both Branches)

**PR #100** → `master` branch, references `#54321`  
**PR #101** → `release-5.2.1` branch, references `#54321`

**Result:** Both PRs pass validation ✅

---

### Scenario 2: Incomplete Fix (Missing Cross-Branch PR)

**PR #102** → `master` branch, references `#54321`  
**No matching PR** in `release-5.2.1`

**Result:** PR #102 is blocked ⚠️  
**Action Required:** Create matching PR or add override label

---

### Scenario 3: Intentional Single-Branch Fix

**PR #103** → `release-5.2.1` branch, references `#54321`  
**No matching PR** in `master` (intentional)

**Result:** Initially blocked ⚠️  
**Override:** Reviewer adds `approved:single-branch-merge` label  
**Final Result:** PR #103 passes validation ✅

## Integration with Existing Workflows

This workflow runs **in addition to** any existing validation workflows. It does not replace:
- Parent work item reference validation
- Code review requirements
- CI/CD tests
- Other branch protection rules

## Troubleshooting

### Workflow Not Running

**Check:**
- Workflow file is in `.github/workflows/` directory
- Branch names in `env` section match your repository branches
- PR targets one of the monitored branches

### False Negatives (Matching PR Not Found)

**Possible causes:**
- Issue reference format differs between PRs
- Matching PR is in draft state (workflow only searches open PRs)
- Issue reference is in a comment, not in title/body

**Solution:**
- Ensure issue references use the same format (e.g., `#54321`)
- Include issue reference in PR title or description
- Convert draft PRs to open state

### Override Not Working

**Check:**
- Label name is exactly `approved:single-branch-merge`
- Label was added before the workflow ran
- Re-trigger the workflow after adding the label

## Maintenance

### Per Release Cycle

Update the `RELEASE_BRANCH` value in the workflow file:

```yaml
env:
  PRIMARY_BRANCH: 'master'
  RELEASE_BRANCH: 'release-5.3.0'  # Update this
```

### Monitoring

Check workflow runs in the **Actions** tab of your repository to monitor:
- Validation success/failure rates
- Override usage frequency
- Common blocking pattern

## Support

For issues or questions about this workflow:
1. Check the workflow run logs in the Actions tab
2. Review the validation comment posted on the PR
3. Verify branch configuration matches your repository structure
