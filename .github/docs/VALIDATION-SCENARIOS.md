# Cross-Branch PR Validation - Comprehensive Scenarios Guide

This document covers all possible scenarios and edge cases for the enhanced cross-branch PR validation system.

## Table of Contents

1. [Basic Scenarios](#basic-scenarios)
2. [Multi-Issue Scenarios](#multi-issue-scenarios)
3. [Branch Imbalance Scenarios](#branch-imbalance-scenarios)
4. [State Synchronization Scenarios](#state-synchronization-scenarios)
5. [Override Scenarios](#override-scenarios)
6. [Edge Cases](#edge-cases)
7. [Performance Scenarios](#performance-scenarios)

---

## Basic Scenarios

### Scenario 1.1: Perfect Match (Both Branches)

**Setup:**
- PR #100 → `master`, references `#54321`
- PR #101 → `release-5.3.1`, references `#54321`

**Expected Behavior:**
- ✅ Both PRs pass validation
- Status: `PASS`
- Labels: `cross-branch-validated` added to both
- Comments: Success message posted on both PRs

**Validation Logic:**
```
Issue #54321:
  master: 1 PR (✓)
  release: 1 PR (✓)
Result: PASS - Both branches covered
```

---

### Scenario 1.2: Missing Cross-Branch PR

**Setup:**
- PR #102 → `master`, references `#54321`
- No matching PR in `release-5.3.1`

**Expected Behavior:**
- ❌ PR #102 blocked
- Status: `FAIL_MISSING`
- Labels: `merge-blocked:cross-branch-validation` added
- Comments: Warning with override instructions

**Validation Logic:**
```
Issue #54321:
  master: 1 PR (✓)
  release: 0 PRs (✗)
Result: FAIL_MISSING - No coverage in release branch
```

**Resolution Options:**
1. Create matching PR in `release-5.3.1` with `#54321`
2. Add override label `approved:single-branch-merge`

---

### Scenario 1.3: Intentional Single-Branch Fix (Override)

**Setup:**
- PR #103 → `release-5.3.1`, references `#54321`
- No matching PR in `master` (intentional)
- Reviewer adds `approved:single-branch-merge` label

**Expected Behavior:**
- ✅ PR #103 passes validation
- Status: `PASS_OVERRIDE`
- Labels: Both override and validated labels present
- Comments: Override acknowledgment posted

**Validation Logic:**
```
Issue #54321:
  master: 0 PRs (✗)
  release: 1 PR (✓)
Override: YES (✓)
Result: PASS_OVERRIDE - Override approved
```

---

## Multi-Issue Scenarios

### Scenario 2.1: Multiple Issues - Exact Match Required

**Setup:**
- PR #200 → `master`, references `#12345, #67890`
- PR #201 → `release-5.3.1`, references `#12345, #67890`
- Config: `require_exact_match: true`

**Expected Behavior:**
- ✅ Both PRs pass validation
- Status: `PASS`
- All issues must match exactly

**Validation Logic:**
```
Issues: #12345, #67890
  master: PR #200 has [#12345, #67890] (✓)
  release: PR #201 has [#12345, #67890] (✓)
Result: PASS - Exact match found
```

---

### Scenario 2.2: Multiple Issues - Partial Match (Strict Mode)

**Setup:**
- PR #202 → `master`, references `#12345, #67890`
- PR #203 → `release-5.3.1`, references `#12345` only
- Config: `require_exact_match: true`

**Expected Behavior:**
- ❌ Both PRs blocked
- Status: `FAIL_MISMATCH`
- Issue `#67890` missing in release branch

**Validation Logic:**
```
Issues: #12345, #67890
  master: PR #202 has [#12345, #67890] (✓)
  release: PR #203 has [#12345] (✗ - missing #67890)
Result: FAIL_MISMATCH - Not all issues covered
```

**Resolution:**
- Update PR #203 to include `#67890`, OR
- Create separate PR for `#67890` in release branch

---

### Scenario 2.3: Multiple Issues - Superset Match (Lenient Mode)

**Setup:**
- PR #204 → `master`, references `#12345, #67890`
- PR #205 → `release-5.3.1`, references `#12345, #67890, #99999`
- Config: `require_exact_match: false`

**Expected Behavior:**
- ✅ Both PRs pass validation
- Status: `PASS`
- Superset is acceptable

**Validation Logic:**
```
Issues: #12345, #67890
  master: PR #204 has [#12345, #67890] (✓)
  release: PR #205 has [#12345, #67890, #99999] (✓ - superset)
Result: PASS - All required issues covered
```

---

### Scenario 2.4: Multiple Issues - Distributed Across PRs

**Setup:**
- PR #206 → `master`, references `#12345, #67890`
- PR #207 → `release-5.3.1`, references `#12345`
- PR #208 → `release-5.3.1`, references `#67890`
- Config: `multi_issue_strategy: all`

**Expected Behavior:**
- ✅ All PRs pass validation
- Status: `PASS`
- Issues covered across multiple PRs

**Validation Logic:**
```
Issues: #12345, #67890
  master: PR #206 has [#12345, #67890] (✓)
  release: 
    - PR #207 has [#12345] (✓)
    - PR #208 has [#67890] (✓)
Result: PASS - All issues covered (distributed)
```

---

## Branch Imbalance Scenarios

### Scenario 3.1: Acceptable Imbalance

**Setup:**
- Issue `#54321` has:
  - 3 PRs in `master`
  - 2 PRs in `release-5.3.1`
- Config: `max_imbalance: 2`

**Expected Behavior:**
- ✅ All PRs pass validation
- Status: `PASS`
- Imbalance = 1 (within limit)

**Validation Logic:**
```
Issue #54321:
  master: 3 PRs
  release: 2 PRs
Imbalance: |3 - 2| = 1
Max allowed: 2
Result: PASS - Imbalance acceptable
```

---

### Scenario 3.2: Excessive Imbalance

**Setup:**
- Issue `#54321` has:
  - 5 PRs in `master`
  - 1 PR in `release-5.3.1`
- Config: `max_imbalance: 2`

**Expected Behavior:**
- ⚠️ All PRs show warning
- Status: `WARN_IMBALANCE`
- Labels: `cross-branch-warning` added
- Merge allowed but flagged

**Validation Logic:**
```
Issue #54321:
  master: 5 PRs
  release: 1 PR
Imbalance: |5 - 1| = 4
Max allowed: 2
Result: WARN_IMBALANCE - Excessive imbalance detected
```

**Recommended Action:**
- Review if all 5 PRs in master are necessary
- Consider consolidating or creating matching PRs in release

---

### Scenario 3.3: Zero PRs in One Branch

**Setup:**
- Issue `#54321` has:
  - 5 PRs in `master`
  - 0 PRs in `release-5.3.1`

**Expected Behavior:**
- ❌ All PRs blocked
- Status: `FAIL_MISSING`
- Critical imbalance

**Validation Logic:**
```
Issue #54321:
  master: 5 PRs
  release: 0 PRs
Result: FAIL_MISSING - No coverage in release branch
```

---

## State Synchronization Scenarios

### Scenario 4.1: Real-Time Cross-PR Update with Pending State

**Timeline:**
1. **T0:** PR #300 → `master`, references `#54321` (BLOCKED - no matching PR)
2. **T1:** PR #301 → `release-5.3.1`, references `#54321` (created)
3. **T2:** Workflow triggers on PR #301
4. **T3:** System detects PR #300 validation is still running
5. **T4:** PR #301 shows PENDING status (waiting for PR #300 to complete)
6. **T5:** PR #300 validation completes
7. **T6:** Both PRs automatically updated to PASS status

**Expected Behavior:**
- ⏳ PR #301 shows PENDING status initially (waiting for PR #300 check)
- ✅ PR #300 automatically unblocked once its validation completes
- ✅ Both PRs automatically updated to PASS when both validations complete
- Both PRs show synchronized status
- No manual re-run needed

**Validation Logic:**
```
Event: PR #301 opened
Action: Query all PRs with #54321
Found: PR #300 (master, validation in progress), PR #301 (release)
Status: PR #301 → PENDING (waiting for PR #300)
Later: PR #300 completes → Both PRs → PASS status
```

**Key Feature:** Eliminates stale validation problem and prevents premature failures

---

### Scenario 4.1b: Real-Time Cross-PR Update (Both Checks Complete)

**Timeline:**
1. **T0:** PR #300 → `master`, references `#54321` (validation complete, BLOCKED)
2. **T1:** PR #301 → `release-5.3.1`, references `#54321` (created)
3. **T2:** Workflow triggers on PR #301
4. **T3:** System finds PR #300 with same issue (validation already complete)
5. **T4:** Both PR #300 and PR #301 updated simultaneously to PASS

**Expected Behavior:**
- ✅ PR #300 automatically unblocked
- ✅ PR #301 passes validation immediately
- Both PRs show synchronized status
- No manual re-run needed

**Validation Logic:**
```
Event: PR #301 opened
Action: Query all PRs with #54321
Found: PR #300 (master, validation complete), PR #301 (release)
Update: Both PRs → PASS status immediately
```

**Key Feature:** Instant synchronization when all checks are complete

---

### Scenario 4.2: Merged PR Updates Related PRs

**Timeline:**
1. **T0:** PR #302 → `master`, references `#54321` (PASS)
2. **T1:** PR #303 → `release-5.3.1`, references `#54321` (PASS)
3. **T2:** PR #303 merged
4. **T3:** Workflow triggers on PR #303 close
5. **T4:** PR #302 status updated

**Expected Behavior:**
- ✅ PR #302 still shows PASS
- Comment updated to reflect PR #303 merged
- Config: `include_merged: true`

**Validation Logic:**
```
Event: PR #303 merged
Action: Query all open PRs with #54321
Found: PR #302 (master, open)
Update: PR #302 → PASS (matching merged PR exists)
```

---

### Scenario 4.3: Draft PR Handling

**Setup:**
- PR #304 → `master`, references `#54321` (open)
- PR #305 → `release-5.3.1`, references `#54321` (draft)
- Config: `include_drafts: false`

**Expected Behavior:**
- ❌ PR #304 blocked
- Draft PR #305 not counted
- Status: `FAIL_MISSING`

**Validation Logic:**
```
Issue #54321:
  master: 1 PR (open) (✓)
  release: 1 PR (draft) → excluded (✗)
Result: FAIL_MISSING - No open PR in release
```

**Resolution:**
- Convert PR #305 from draft to open, OR
- Create new open PR in release branch

---

### Scenario 4.4: Closed PR Handling

**Setup:**
- PR #306 → `master`, references `#54321` (open)
- PR #307 → `release-5.3.1`, references `#54321` (closed, not merged)
- Config: `include_closed: false`

**Expected Behavior:**
- ❌ PR #306 blocked
- Closed PR #307 not counted
- Status: `FAIL_MISSING`

**Validation Logic:**
```
Issue #54321:
  master: 1 PR (open) (✓)
  release: 1 PR (closed) → excluded (✗)
Result: FAIL_MISSING - No open PR in release
```

---

## Override Scenarios

### Scenario 5.1: Override with Justification

**Setup:**
- PR #400 → `master`, references `#54321`
- No matching PR in release
- Reviewer adds override label
- Reviewer posts: "This fix is specific to master's new feature X"

**Expected Behavior:**
- ✅ PR #400 passes validation
- Status: `PASS_OVERRIDE`
- Justification logged in audit trail
- Override notification sent

**Validation Logic:**
```
Issue #54321:
  master: 1 PR (✓)
  release: 0 PRs (✗)
Override: YES with justification (✓)
Result: PASS_OVERRIDE
```

---

### Scenario 5.2: Override Without Justification (Strict Mode)

**Setup:**
- PR #401 → `master`, references `#54321`
- Override label added
- No justification comment
- Config: `require_justification: true`

**Expected Behavior:**
- ⚠️ Override pending
- Bot comments requesting justification
- PR remains blocked until justification provided

**Validation Logic:**
```
Override label: YES
Justification: NO (✗)
Config requires justification: YES
Result: Override incomplete - awaiting justification
```

---

### Scenario 5.3: Unauthorized Override Attempt

**Setup:**
- PR #402 → `master`, references `#54321`
- Junior developer adds override label
- Config: `allowed_approvers: ["senior-dev-team"]`
- Junior dev not in allowed list

**Expected Behavior:**
- ❌ Override rejected
- Label automatically removed
- Comment: "Override requires approval from: senior-dev-team"
- PR remains blocked

**Validation Logic:**
```
Override label: YES
User: junior-dev
Allowed approvers: [senior-dev-team]
User authorized: NO (✗)
Result: Override rejected - unauthorized
```

---

## Edge Cases

### Scenario 6.1: Issue Reference in Comment (Not Title/Body)

**Setup:**
- PR #500 → `master`
- Title: "Fix bug in authentication"
- Body: "This PR fixes the login issue"
- Comment: "Related to #54321"

**Expected Behavior:**
- ⚠️ Issue reference not detected
- PR skips validation (no issue found)
- Warning comment posted

**Validation Logic:**
```
Search locations: Title + Body only
Issue found: NO
Result: SKIP - No issue reference in PR metadata
```

**Best Practice:** Always include issue references in PR title or description

---

### Scenario 6.2: Multiple PRs Same Branch Same Issue

**Setup:**
- PR #501 → `master`, references `#54321`
- PR #502 → `master`, references `#54321`
- PR #503 → `release-5.3.1`, references `#54321`

**Expected Behavior:**
- ✅ All PRs pass validation
- Status: `PASS`
- Multiple PRs per branch allowed

**Validation Logic:**
```
Issue #54321:
  master: 2 PRs (#501, #502) (✓)
  release: 1 PR (#503) (✓)
Result: PASS - Both branches covered
```

---

### Scenario 6.3: Issue Number Collision

**Setup:**
- PR #504 → `master`, references `#123`
- PR #505 → `release-5.3.1`, references `#123`
- But they refer to different issues (GitHub issue #123 vs JIRA-123)

**Expected Behavior:**
- ✅ System validates based on pattern match
- Status: `PASS`
- Manual review recommended

**Validation Logic:**
```
Pattern: #\d+
PR #504: #123 found
PR #505: #123 found
Result: PASS - Pattern matches
```

**Note:** System cannot distinguish between different issue tracking systems

---

### Scenario 6.4: Circular Dependencies

**Setup:**
- PR #506 → `master`, references `#54321, #67890`
- PR #507 → `release-5.3.1`, references `#67890, #54321`
- Both PRs depend on each other

**Expected Behavior:**
- ✅ Both PRs pass validation
- Status: `PASS`
- Circular dependency detected and logged
- Warning comment about merge order

**Validation Logic:**
```
Issue #54321:
  master: PR #506 (✓)
  release: PR #507 (✓)
Issue #67890:
  master: PR #506 (✓)
  release: PR #507 (✓)
Result: PASS - All issues covered
Warning: Circular dependency detected
```

---

### Scenario 6.5: Renamed/Moved Branches

**Setup:**
- Config: `PRIMARY_BRANCH: master`
- Repository renames `master` → `main`
- Existing PRs target old branch name

**Expected Behavior:**
- ❌ Validation fails
- Error: Branch not found
- Manual config update required

**Resolution:**
1. Update [`.github/validation-config.yml`](.github/validation-config.yml:15)
2. Change `PRIMARY_BRANCH: main`
3. Re-run validation

---

### Scenario 6.6: Stale PR with Outdated Issue Reference

**Setup:**
- PR #508 → `master`, created 6 months ago
- References `#54321` (now closed/resolved)
- New PR #509 → `release-5.3.1`, references `#54321`

**Expected Behavior:**
- ✅ Both PRs pass validation
- Status: `PASS`
- Warning: Issue #54321 is closed
- Recommendation: Review if PRs still needed

**Validation Logic:**
```
Issue #54321: (closed)
  master: PR #508 (6 months old) (✓)
  release: PR #509 (new) (✓)
Result: PASS with warning - Issue closed
```

---

## Performance Scenarios

### Scenario 7.1: High Volume - Many PRs Same Issue

**Setup:**
- Issue `#54321` has 50 related PRs
- 25 in `master`, 25 in `release-5.3.1`
- New PR #600 created

**Expected Behavior:**
- ✅ Validation completes within timeout
- GraphQL query fetches all 50 PRs in single call
- All 50 PRs updated with synchronized status
- Performance: < 30 seconds

**Optimization:**
```
Traditional approach: 50 × 2 = 100 API calls
Enhanced approach: 1 GraphQL query + 50 updates
Time saved: ~80%
```

---

### Scenario 7.2: API Rate Limiting

**Setup:**
- Multiple PRs created simultaneously
- GitHub API rate limit approaching
- Workflow needs to validate all PRs

**Expected Behavior:**
- ⚠️ Rate limit detected
- Exponential backoff applied
- Validation queued and retried
- Status: `PENDING` until complete

**Handling:**
```
Attempt 1: Failed (rate limited)
Wait: 2 seconds
Attempt 2: Failed (rate limited)
Wait: 4 seconds
Attempt 3: Success
```

---

### Scenario 7.3: Large Repository - 1000+ Open PRs

**Setup:**
- Repository has 1000+ open PRs
- Need to find PRs with specific issue reference
- Config: `batch_size: 10`

**Expected Behavior:**
- ✅ Validation uses optimized GraphQL query
- Only fetches PRs linked to specific issues
- Avoids scanning all 1000+ PRs
- Performance: < 10 seconds

**Optimization:**
```
Naive approach: Scan all 1000 PRs
Enhanced approach: Query issue timeline (10-20 PRs)
Efficiency gain: 50-100x faster
```

---

## Summary Matrix

| Scenario | Status | Blocking | Override | Sync |
|----------|--------|----------|----------|------|
| Perfect Match | PASS | No | N/A | Yes |
| Missing PR | FAIL_MISSING | Yes | Allowed | Yes |
| Pending Validation | PENDING | No | N/A | Yes |
| Exact Match | PASS | No | N/A | Yes |
| Partial Match | FAIL_MISMATCH | Yes | Allowed | Yes |
| Superset Match | PASS | No | N/A | Yes |
| Acceptable Imbalance | PASS | No | N/A | Yes |
| Excessive Imbalance | WARN_IMBALANCE | No | N/A | Yes |
| Zero Coverage | FAIL_MISSING | Yes | Allowed | Yes |
| Draft PR | FAIL_MISSING | Yes | Allowed | Yes |
| Merged PR | PASS | No | N/A | Yes |
| Override Approved | PASS_OVERRIDE | No | Active | Yes |
| Circular Dependency | PASS | No | N/A | Yes |

---

## Testing Checklist

Use this checklist to verify your validation system:

- [ ] Basic single-issue validation works
- [ ] Multi-issue exact matching works
- [ ] Multi-issue superset matching works
- [ ] Branch imbalance detection works
- [ ] Real-time cross-PR synchronization works
- [ ] Pending state detection works (Scenario 2)
- [ ] Automatic update after pending check completes
- [ ] Draft PR handling works correctly
- [ ] Merged PR handling works correctly
- [ ] Override mechanism works
- [ ] Override justification required
- [ ] Unauthorized override rejected
- [ ] Issue reference extraction accurate
- [ ] GraphQL query optimization effective
- [ ] Performance acceptable with many PRs
- [ ] Rate limiting handled gracefully
- [ ] Circular dependencies detected
- [ ] Stale PR warnings shown
- [ ] Configuration changes applied
- [ ] Labels added/removed correctly
- [ ] Comments posted/updated correctly
- [ ] Audit trail maintained

---

## Troubleshooting Guide

### Problem: Validation not running

**Check:**
1. Workflow file in [`.github/workflows/`](.github/workflows/pr-validation-enhanced.yml:1)
2. Branch names in config match repository
3. PR targets monitored branch
4. Workflow permissions correct

### Problem: False negatives (matching PR not found)

**Check:**
1. Issue reference format consistent
2. Draft PRs excluded (if configured)
3. Issue reference in title/body (not comments)
4. GraphQL query returning results

### Problem: Performance issues

**Check:**
1. Batch size configuration
2. API rate limits
3. Number of related PRs
4. Cache configuration

### Problem: Override not working

**Check:**
1. Label name exact match
2. User authorization
3. Justification provided (if required)
4. Workflow re-triggered after label added

---

## Best Practices

1. **Always include issue references in PR title or description**
2. **Use consistent issue reference format** (`#12345`)
3. **Create matching PRs promptly** to avoid blocking
4. **Document override justifications** thoroughly
5. **Monitor branch imbalance** regularly
6. **Update configuration** per release cycle
7. **Review validation metrics** weekly
8. **Test changes** in dry-run mode first
9. **Keep PRs focused** on single issues when possible
10. **Communicate** with team about validation requirements