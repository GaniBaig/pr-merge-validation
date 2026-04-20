# pr-merge-validation


---
### **Detailed Implementation Prompt**

**Context:**
In our GitHub repository, we have a release branch (e.g., `release-5.2.1`) and a `master` branch. Currently, fixes sometimes get merged into only one of these branches, leading to inconsistencies and regression risks. While we already have a workflow that blocks PRs lacking a parent work item reference (e.g., `#54321`), we need an additional safeguard.

**Objective:**
Create a GitHub Actions workflow that ensures when a fix for a given parent issue is made in one branch, a corresponding PR must exist in the other branch **with the same parent issue reference**. This will prevent incomplete merges across `master` and release branches.

