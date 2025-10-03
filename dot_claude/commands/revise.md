---
description: Revise an implementation plan based on user feedback (/revise)
---

Revise the existing implementation plan based on user feedback and requirements changes.
This command bridges the gap between initial design and implementation by incorporating user insights.

**IMPORTANT**: Only modify `./tmp/plan.md`. Do not create or modify any other files.

## Execution Conditions

You must verify the following file exists before proceeding:

- `./tmp/plan.md` - Implementation plan
- `./tmp/context.md` - User feedback and requirements

If any file is missing:

- Stop the process immediately
- Notify the user which condition failed
- Do not proceed with implementation

## Execution Process

### Phase 1: Load Current Plan

- Read the existing implementation plan from `./tmp/plan.md`
- Understand the current structure, requirements, and approach
- Identify key components and implementation strategies

### Phase 2: Load User Feedback

- Read the feedback from `./tmp/context.md`
- Parse the content to identify specific revision requests
- Each feedback item may be separated by "=====" or similar delimiters
- Extract file references and context (e.g., `tmp/plan.md:L144`)
- Categorize feedback such as requirements changes, technical concerns, approach modifications

### Phase 3: User Clarification (if needed)

**IMPORTANT**: If any of the following issues are detected, stop the process immediately and report to the user:

- Ambiguous feedback items that need clarification:
  - Stop execution and provide specific questions to the user
  - List which feedback items are unclear or open to multiple interpretations
- Conflicting requirements that need prioritization:
  - Stop execution and present the conflicts clearly to the user
  - Ask the user to prioritize or resolve conflicting demands
- Technical constraints or preferences not specified in feedback:
  - Stop execution and ask for missing technical details
  - Request specific implementation preferences or constraints

For multiple issues, format as:

```
## Issue 1: [issue summary]
[What is the problem in relevant feedback item]

## Issue 2: [issue summary]
[What is the problem in relevant feedback item]
```

### Phase 4: Research & Analysis

- For each feedback item, use sub-agents to conduct thorough investigation
- Use Task tool with general-purpose agent for complex research
- Search codebase for patterns, implementations, and context related to the feedback
- Use Web search tool for external documentation and examples
- Use Context7 MCP for library/framework usage
- Use Serena MCP for semantic code search

### Phase 5: Revision

- Think harder about how to incorporate each piece of feedback effectively
- Validate feasibility of requested changes
- Identify conflicts between feedback items and resolve them
- Maintain coherence of the overall implementation plan
- Preserve successful aspects of the original plan while addressing concerns

### Phase 6: Plan Update

- Overwrite `./tmp/plan.md` with revised implementation plan
- Incorporate all valid feedback while maintaining original structure
- Update outdated information with current findings from research (steps for implementation, documentation URLs, file paths, code examples, etc.)
- Keep plan focused on implementation without revision history

### Phase 7: Commit Changes

Ask the subagent commit for implementation plan.

### Phase 8: Completion Report

Provide summary to user:

- Key changes made to the implementation plan
- Feedback items addressed and how they were resolved

For multiple feedback items, format as:

```
## Feedback 1: [feedback summary]
[How this feedback was addressed in the revised plan]

## Feedback 2: [feedback summary]
[How this feedback was addressed in the revised plan]
```
