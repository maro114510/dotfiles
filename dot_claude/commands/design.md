---
description: Create an implementation plan based on a context file (/design <path_to_context_file>)
---

Generate a complete implementation plan for general feature implementation with thorough research. Ensure context is passed to the AI agent to enable self-validation and iterative refinement. Read the feature file first to understand what needs to be created, how the examples provided help, and any other considerations.

The AI agent only gets the context you are appending to the implementation plan and training data. Assume the AI agent has access to the codebase and the same knowledge cutoff as you, so its important that your research findings are included or referenced in the implementation plan. The Agent has web search capabilities, so pass urls to documentation and examples.

## Context

Refer to $ARGUMENTS.

## Research Process

### Phase 1: Codebase Analysis

- Search for similar features/patterns in the codebase
- Identify files to reference in the implementation plan
- Note existing conventions to follow
- Check test patterns for validation approach
- Use Serena MCP for semantic code search

### Phase 2: External Research

- Search for similar features/patterns in the Web
- Library documentation (include specific URLs)
- Implementation examples (Official Documents / GitHub / Stack Overflow / Blogs)
- Best practices and common pitfalls
- Use web search tool for external documentation and examples
- Use Context7 MCP for library/framework usage

### Phase 3: User Clarification (if needed)

- Specific patterns to mirror and where to find them?
- Integration requirements and where to find them?

## Implementation Plan Generation

### Critical Context

Critical context to include and pass to the AI agent as part of the implementation plan is the following:

- **Documentation**: URLs with specific sections
- **Code Examples**: Real snippets from codebase
- **Gotchas**: Library quirks, version issues
- **Patterns**: Existing approaches to follow

### Implementation Blueprint

- Start with pseudocode showing approach
- Reference real files for patterns
- Include error handling strategy
- List tasks to be completed to fulfill the implementation plan in the order they should be completed

**_ CRITICAL AFTER YOU ARE DONE RESEARCHING AND EXPLORING THE CODEBASE BEFORE YOU START WRITING THE IMPLEMENTATION PLAN _**

**_ ULTRATHINK ABOUT THE IMPLEMENTATION PLAN AND PLAN YOUR APPROACH THEN START WRITING THE IMPLEMENTATION PLAN _**

### Save and Commit Implementation Plan

- Save an implementation plan as `./tmp/plan.md`
- Ask the subagent commit for implementation plan
