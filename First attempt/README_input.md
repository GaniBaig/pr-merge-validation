# pr-merge-validation


---
### **Detailed Implementation Prompt**

**Context:**
In our GitHub repository, we have a release branch (e.g., `release-5.2.1`) and a `master` branch. Currently, fixes sometimes get merged into only one of these branches, leading to inconsistencies and regression risks. While we already have a workflow that blocks PRs lacking a parent work item reference (e.g., `#54321`), we need an additional safeguard.

**Objective:**
Create a GitHub Actions workflow that ensures when a fix for a given parent issue is made in one branch, a corresponding PR must exist in the other branch **with the same parent issue reference**. This will prevent incomplete merges across `master` and release branches.

**Requirements:**

1. **Configurable Inputs:**
   * Allow the repo owner to specify the two branches to compare (e.g., `master` and `release-5.2.1`). These should be configurable inputs to the workflow, so they can be updated per release cycle.
1. **Trigger:**
   * The workflow should run when a PR is opened or updated against **either** of the two monitored branches mention as a repo maintainer where can he change the branch names to run this below utomation.
1. **Validation Logic:**
   * Extract the parent issue reference from the PR (using the existing regex pattern for `#54321`).
   * Search for an **open PR** in the *other* monitored branch that references the **same parent issue**.
   * If such a PR exists in the other branch, allow merging to proceed.
   * If no matching PR is found in the other branch, block the merge and display a **mandatory prompt** requiring explicit reviewer confirmation to override.
1. **Override Mechanism:**
   * The prompt should require the reviewer to acknowledge that the fix is intentionally being merged into only one branch, accepting the risk of inconsistency.
1. **Integration with Existing Workflow:**
   * This new check should run **in addition** to the existing “parent work item reference” validation, not replace it.

**Technical Notes:**

* Use the GitHub REST API or GraphQL API to search for open PRs in the other branch containing the same issue reference.
* The workflow should be reusable and easily adjustable for different branch pairs.
---``
