---
description: Recap a task (/recap <session-id>)
---

Perform comprehensive recap by analyzing local files, Claude Code session, and comments on Pull Request.

## Execution Conditions

You must verify all of the following conditions before proceeding:

- `session_id` argument is provided by the user (e.g. 2553e5ed-62fd-4b2e-897c-911ab22128ae)
- Template file exists at `~/obsidian/templates/recap.md`
- Context file exists at `./tmp/context.md`
- Implementation plan file exists at `./tmp/plan.md`

If any condition is not met:

- Stop the process immediately
- Notify the user which condition failed
- Do not proceed with any operations

## Execution Phases

### Phase 1: Parse The Template

Read `~/obsidian/templates/recap.md` and understand what information should you collect.

### Phase 2: Understand The Task

Specify task title and overview that described by three lines.

- Read `./tmp/context.md` - Initial requirements that user provided
- Read `./tmp/plan.md` - Implementation plan that served as the basis for actual implementation

### Phase 3: Understand File Changes

Collect file changes from Git to understand key features and technical decisions.

```bash
# Get current branch
current_branch=$(git branch --show-current)

# Check if Pull Request exists for current branch
pr_number=$(gh pr list --head "$current_branch" --state all --json number --jq '.[0].number')

# Verify Pull Request exists
if [ "$pr_number" = "null" ] || [ -z "$pr_number" ]; then
    exit 1
fi

# Get base branch
base_branch=$(gh pr view "$pr_number" --json baseRefName --jq '.baseRefName')

# Get commits since diverging from base branch
git log --oneline "$base_branch..$current_branch"

# Get diff
changed_files=$(git diff --name-only ${base_branch}...HEAD)
git_diff=$(git diff ${base_branch}...HEAD)
```

### Step 4: Analyze Claude Code Session

Specify the session file path based on Claude Code's storage pattern:

```bash
# Get current working directory and encode it
current_dir=$(pwd)
encoded_dir=$(echo "$current_dir" | sed 's/\//-/g')
session_file="~/.claude/projects/${encoded_dir}/${session_id}.jsonl"
```

Check if session file exists:

```bash
if [[ -f "$session_file" ]]; then
    echo "Session file found: $session_file"
else
    echo "Error: No session file found for ID: ${session_id}"
fi
```

Read the session file (JSONL format) to understand:

- Instructions that user said repeatedly
- Issues that AI-agent tried to solve over and over again, and how to solve it

### Step 5: Analyze Feedback On Pull Request

If Pull Request exists, gather feedback using GitHub CLI.

```bash
# View Pull Request details
gh pr view

# Get Pull Request comments and review feedback
repo=$(gh repo view --json owner,name)
owner=$(echo "$repo" | jq -r '.owner.login')
repo_name=$(echo "$repo" | jq -r '.name')
gh api repos/${owner}/${repo_name}/pulls/${pr_number}/comments
gh api repos/${owner}/${repo_name}/pulls/${pr_number}/reviews
```

Extract:

- Reviewer (@<github_accounts>)
- Review comment
- (If answer exists) Response to the comment
- How did it turned out?

### Step 6: Generate Report

Create comprehensive recap report in `./tmp/recap.md`.
Structure your findings in the following format: `~/obsidian/templates/recap.md`.

**IMPORTANT: Follow Template Structure exactly**

### Phase 7: Completion Report

Provide summary to user:

- Summarize the task
- Output file
