#!/bin/bash
# Cross-Branch PR Validation Library
# Reusable functions for PR validation workflows

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Extract all issue references from text
# Usage: extract_issue_refs "PR title and body text"
# Returns: Comma-separated list of issue refs (e.g., "#123,#456")
extract_issue_refs() {
    local text="$1"
    local refs=$(echo "$text" | grep -oP '#\d+' | sort -u | tr '\n' ',' | sed 's/,$//')
    echo "$refs"
}

# Count issue references
# Usage: count_issue_refs "#123,#456,#789"
# Returns: Number of issue references
count_issue_refs() {
    local refs="$1"
    if [ -z "$refs" ]; then
        echo "0"
    else
        echo "$refs" | tr ',' '\n' | wc -l
    fi
}

# Query GitHub GraphQL API for PRs linked to issues
# Usage: query_linked_prs "123,456" "owner" "repo" "token"
# Returns: JSON array of linked PRs
query_linked_prs() {
    local issue_numbers="$1"
    local owner="$2"
    local repo="$3"
    local token="$4"
    
    # Convert comma-separated to array for GraphQL
    local issue_array=$(echo "$issue_numbers" | tr ',' '\n' | sed 's/#//g' | jq -R . | jq -s .)
    
    local query='
    query($owner: String!, $repo: String!, $issueNumbers: [Int!]!) {
      repository(owner: $owner, name: $repo) {
        issues(first: 10, filterBy: {numbers: $issueNumbers}) {
          nodes {
            number
            title
            timelineItems(itemTypes: [CROSS_REFERENCED_EVENT], first: 100) {
              nodes {
                ... on CrossReferencedEvent {
                  source {
                    ... on PullRequest {
                      number
                      title
                      body
                      baseRefName
                      state
                      isDraft
                      url
                      createdAt
                      updatedAt
                      labels(first: 20) {
                        nodes {
                          name
                        }
                      }
                      author {
                        login
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }'
    
    gh api graphql \
        -f query="$query" \
        -f owner="$owner" \
        -f repo="$repo" \
        -f issueNumbers="$issue_array" \
        --jq '.data.repository.issues.nodes[].timelineItems.nodes[].source | select(. != null)'
}

# Filter PRs by branch and state
# Usage: filter_prs_by_branch "branch_name" "OPEN" "false" < prs.json
# Args: branch_name, state (OPEN/CLOSED/MERGED), include_drafts (true/false)
# Returns: Filtered PR numbers (one per line)
filter_prs_by_branch() {
    local branch="$1"
    local state="${2:-OPEN}"
    local include_drafts="${3:-false}"
    
    local draft_filter
    if [ "$include_drafts" = "false" ]; then
        draft_filter='select(.isDraft == false)'
    else
        draft_filter='.'
    fi
    
    jq -r --arg branch "$branch" --arg state "$state" \
        'select(.baseRefName == $branch and .state == $state) | '"$draft_filter"' | .number'
}

# Check if two issue reference sets match exactly
# Usage: check_exact_match "#123,#456" "#456,#123"
# Returns: 0 if match, 1 if no match
check_exact_match() {
    local refs1=$(echo "$1" | tr ',' '\n' | sort | tr '\n' ',')
    local refs2=$(echo "$2" | tr ',' '\n' | sort | tr '\n' ',')
    
    if [ "$refs1" = "$refs2" ]; then
        return 0
    else
        return 1
    fi
}

# Check if issue refs are a superset
# Usage: check_superset "#123,#456,#789" "#123,#456"
# Returns: 0 if first is superset of second, 1 otherwise
check_superset() {
    local superset="$1"
    local subset="$2"
    
    for issue in $(echo "$subset" | tr ',' ' '); do
        if ! echo "$superset" | grep -q "$issue"; then
            return 1
        fi
    done
    return 0
}

# Calculate branch imbalance
# Usage: calculate_imbalance 5 3
# Returns: Absolute difference
calculate_imbalance() {
    local count1=$1
    local count2=$2
    echo $((count1 > count2 ? count1 - count2 : count2 - count1))
}

# Check if PR has override label
# Usage: check_override_label "pr_number" "owner" "repo" "label_name"
# Returns: 0 if label exists, 1 otherwise
check_override_label() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local label_name="$4"
    
    local labels=$(gh pr view "$pr_number" \
        --repo "$owner/$repo" \
        --json labels \
        --jq '.labels[].name')
    
    if echo "$labels" | grep -q "^${label_name}$"; then
        return 0
    else
        return 1
    fi
}

# Add label to PR
# Usage: add_pr_label "pr_number" "owner" "repo" "label_name"
add_pr_label() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local label_name="$4"
    
    gh pr edit "$pr_number" \
        --repo "$owner/$repo" \
        --add-label "$label_name" 2>/dev/null || true
}

# Remove label from PR
# Usage: remove_pr_label "pr_number" "owner" "repo" "label_name"
remove_pr_label() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local label_name="$4"
    
    gh pr edit "$pr_number" \
        --repo "$owner/$repo" \
        --remove-label "$label_name" 2>/dev/null || true
}

# Post or update comment on PR
# Usage: post_pr_comment "pr_number" "owner" "repo" "comment_body" "comment_marker"
post_pr_comment() {
    local pr_number="$1"
    local owner="$2"
    local repo="$3"
    local comment_body="$4"
    local comment_marker="${5:-Cross-Branch Validation Status}"
    
    # Find existing comment
    local existing_comment=$(gh api \
        "/repos/$owner/$repo/issues/$pr_number/comments" \
        --jq ".[] | select(.body | contains(\"$comment_marker\")) | .id" \
        | head -1)
    
    if [ -n "$existing_comment" ]; then
        # Update existing comment
        gh api \
            -X PATCH \
            "/repos/$owner/$repo/issues/comments/$existing_comment" \
            -f body="$comment_body" > /dev/null
        log_info "Updated comment on PR #$pr_number"
    else
        # Create new comment
        gh pr comment "$pr_number" \
            --repo "$owner/$repo" \
            --body "$comment_body"
        log_info "Posted new comment on PR #$pr_number"
    fi
}

# Generate validation status comment
# Usage: generate_status_comment "result" "issue_refs" "primary_prs" "release_prs" "matching_prs" "imbalance"
generate_status_comment() {
    local result="$1"
    local issue_refs="$2"
    local primary_prs="$3"
    local release_prs="$4"
    local matching_prs="$5"
    local imbalance="$6"
    local primary_branch="${7:-master}"
    local release_branch="${8:-release}"
    local override_label="${9:-approved:single-branch-merge}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local primary_count=$(echo "$primary_prs" | tr ',' '\n' | grep -c . || echo "0")
    local release_count=$(echo "$release_prs" | tr ',' '\n' | grep -c . || echo "0")
    
    local status_icon
    local status_message
    case "$result" in
        PASS)
            status_icon="✅"
            status_message="Validation PASSED: Matching PRs found in both branches"
            ;;
        PASS_OVERRIDE)
            status_icon="✅"
            status_message="Validation PASSED (Override approved)"
            ;;
        WARN_IMBALANCE)
            status_icon="⚠️"
            status_message="Validation WARNING: Matching PRs found but branch imbalance detected"
            ;;
        FAIL_MISSING)
            status_icon="❌"
            status_message="Validation FAILED: No matching PR found in comparison branch"
            ;;
        FAIL_MISMATCH)
            status_icon="❌"
            status_message="Validation FAILED: Issue references don't match exactly"
            ;;
        *)
            status_icon="❓"
            status_message="Validation status unknown"
            ;;
    esac
    
    cat <<EOF
## 🔄 Cross-Branch Validation Status

**Last Updated:** $timestamp
**Validation Result:** $status_icon $status_message
**Issue References:** $issue_refs

### 📊 PR Distribution
- **$primary_branch:** $primary_count PR(s) ${primary_prs:+(#${primary_prs//,/, #})}
- **$release_branch:** $release_count PR(s) ${release_prs:+(#${release_prs//,/, #})}
- **Branch Imbalance:** $imbalance

EOF

    if [ -n "$matching_prs" ]; then
        cat <<EOF
### ✅ Matching PRs Found
- PR(s) #${matching_prs//,/, #} in comparison branch contain the same issue references

EOF
    fi
    
    if [[ "$result" == FAIL_* ]]; then
        cat <<EOF
### ⚠️ Action Required

This PR is **blocked** from merging. To proceed, you must either:

1. **Create a matching PR** in the comparison branch with the same issue references
2. **Add the override label** \`$override_label\` with justification

#### Override Instructions:
1. Add label: \`$override_label\`
2. Comment with justification (e.g., "This fix is specific to $primary_branch only")
3. Re-run this workflow

EOF
    fi
    
    echo "---"
    echo "*Automated validation by Cross-Branch PR Validation System*"
}

# Validate PR against rules
# Usage: validate_pr "current_issue_refs" "comparison_prs_json" "require_exact_match" "max_imbalance"
# Returns: JSON with validation result
validate_pr() {
    local current_refs="$1"
    local comparison_prs="$2"
    local require_exact="$3"
    local max_imbalance="$4"
    
    local exact_match=false
    local matching_prs=""
    
    # Check each comparison PR
    while IFS= read -r pr_data; do
        local pr_num=$(echo "$pr_data" | jq -r '.number')
        local pr_text=$(echo "$pr_data" | jq -r '.title + " " + .body')
        local pr_refs=$(extract_issue_refs "$pr_text")
        
        if [ "$require_exact" = "true" ]; then
            if check_exact_match "$current_refs" "$pr_refs"; then
                exact_match=true
                matching_prs="$matching_prs,$pr_num"
            fi
        else
            if check_superset "$pr_refs" "$current_refs"; then
                exact_match=true
                matching_prs="$matching_prs,$pr_num"
            fi
        fi
    done <<< "$comparison_prs"
    
    matching_prs=$(echo "$matching_prs" | sed 's/^,//')
    
    # Build result JSON
    jq -n \
        --arg exact_match "$exact_match" \
        --arg matching_prs "$matching_prs" \
        '{
            exact_match: ($exact_match == "true"),
            matching_prs: $matching_prs
        }'
}

# Export functions for use in workflows
export -f log_info log_success log_warning log_error
export -f extract_issue_refs count_issue_refs
export -f query_linked_prs filter_prs_by_branch
export -f check_exact_match check_superset calculate_imbalance
export -f check_override_label add_pr_label remove_pr_label
export -f post_pr_comment generate_status_comment validate_pr

# Made with Bob
