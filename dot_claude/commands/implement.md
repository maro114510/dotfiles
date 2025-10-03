---
description: Write code based on a plan file (/implement <path_to_plan_file>)
---

## Implementation Plan File

Refer to $ARGUMENTS.

## Execution Process

### Phase 1: Load implementation plan

- Read the implementation plan file
- Understand all context and requirements from both files
- Follow all instructions in the implementation plan and extend the research if needed
- Ensure you have all needed context to implement the implementation plan fully
- Do more Web searches and codebase exploration as needed
- Use Serena MCP for semantic code search
- Use Web search tool for external documentation and examples
- Use Context7 MCP for library/framework usage

### Phase 2: Plan development

- Think harder before you execute the plan. Create a comprehensive plan addressing all requirements
- Break down complex tasks into smaller, manageable phases using your todos tools
- Use the TodoWrite tool to create and track your implementation plan
- Identify implementation patterns from existing code to follow

### Phase 3: Execute the plan

- Execute the implementation plan
- Implement all the code
- Use Serena MCP for semantic code search

### Phase 4: Validate

- Run format, lint, and test tools to ensure code quality.
- Fix any failures
- Acceptance criteria is fulfilled

### Phase 5: Clean up AI comments

- Review all AI-generated comments in the implemented code
- Remove redundant comments that simply repeat what the code already expresses
- Remove commented-out code blocks unless they serve a specific purpose
- Keep only comments that provide valuable context that cannot be expressed through code structure
- Ensure code is self-explanatory through clear naming and structure rather than excessive commenting
- Apply the principle: "Comment what the code cannot say, not simply what it does not say"

ref: https://github.com/97-things/97-things-every-programmer-should-know/tree/master/en/thing_16

### Phase 6: Commit Changes

Ask the subagent commit for changes.

### Phase 7: Complete

- Ensure all checklist items done
- Read the implementation plan again to ensure you have implemented everything
- Report completion status
