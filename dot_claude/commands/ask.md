---
description: Answer questions (/ask)
---

Answer the user's questions by conducting thorough research and investigation.

**IMPORTANT**: Never modify files - only provide answers based on research

## Execution Conditions

You must verify the following file exists before proceeding:

- `./tmp/context.md` - User's questions

If the file is missing:

- Stop the process immediately
- Notify the user which condition failed
- Do not proceed with implementation

## Execution Process

### Phase 1. Load Questions

- Read the questions from `./tmp/context.md`
- Parse the content to identify individual questions
- Each question may be separated by "=====" or similar delimiters
- Extract file references and context (e.g., `tmp/plan.md:L144`)

### Phase 2. Research

- For each question, use sub-agents to conduct thorough investigation
- Use Task tool with general-purpose agent for complex research
- Search codebase for patterns, implementations, and context related to the questions
- Use Web search tool for external documentation and examples
- Use Context7 MCP for library/framework usage
- Use Serena MCP for semantic code search

### Phase 3. Investigation & Analysis

- Read referenced files and understand context
- Search for related code patterns and implementations
- Look for documentation and examples
- Prevent hallucination by following these strict guidelines:
  - Only use information directly found in the codebase, documentation, or research results
  - Use direct quotes from source files when making claims about code or documentation
  - If no supporting evidence exists for a claim, explicitly say "I don't know" or "No evidence found"
  - Clearly distinguish between verified findings and any speculation
- Think harder before you answer the questions

### Phase 4. Answer The Questions

- **IMPORTANT**: Apply critical thinking to question assumptions before finalizing answers

Provide answers to user:

- Provide clear, concise answers to each question
- Reference specific files and line numbers when relevant (format: `file_path:line_number`)
- Reference specific URLs based on the answers
- Include code snippets or examples when helpful
- Separate answers for multiple questions clearly
- Be specific about what was found vs. what is speculation

For multiple questions, format as:

```
## Question 1: [question summary]
[Answer with specific references and findings]

## Question 2: [question summary]
[Answer with specific references and findings]
```
