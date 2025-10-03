---
description: Execute detailed implementation instructions (/instruct)
---

Execute detailed implementation instructions and adjustments based on the context file.
Process multiple instructions sequentially with thorough analysis and implementation.

## Execution Conditions

You must verify the following file exists before proceeding:

- `./tmp/context.md` - Implementation instructions and requirements

If the file is missing:

- Stop the process immediately
- Notify the user that context.md file is not found
- Do not proceed with implementation

## Execution Process

### Phase 1: Parse Multi-Instruction Context

- Read `./tmp/context.md` and parse content structure only
- Identify individual instructions separated by "=====" or similar delimiters
- Extract file references and requirements (e.g., `src/components/button.tsx:L42`)
- Create instruction list with dependency priority order
- Do not research or analyze instructions yet - only parse and organize

### Phase 2: Initialize Instruction Processing

- Use TodoWrite to create todos for each instruction from Step 1
- Mark first instruction as `in_progress`
- Begin processing loop

### Phase 3: Process Current Instruction (Loop)

**IMPORTANT**: Execute the following cycle for the current `in_progress` instruction:

1. **Research Phase**

   - Use sub-agents to conduct thorough investigation for this instruction
   - Use Task tool with general-purpose agent for complex research
   - Search codebase for patterns, implementations, and context related to this instruction
   - Use Web search tool for external documentation and examples
   - Use Context7 MCP for library/framework usage
   - Use Serena MCP for semantic code search

2. **Problem Identification Phase**

   - Read referenced files and identify current state vs this instruction's requirements
   - Compare existing implementation with expected outcome from this instruction
   - Identify gaps between current codebase state and desired end state
   - Analyze what needs to be added, modified, or removed for this instruction
   - Think harder about the root cause of each gap between expectation and reality
   - Define acceptance criteria to be fulfilled after the successful implementation

3. **Implementation Phase**

   - Apply research findings to solve identified problems
   - Focus on clean, maintainable implementation
   - Follow patterns discovered in research phase

4. **Validation Phase**

   - Run format, lint, and test tools to ensure code quality
   - Fix any failures
   - Acceptance criteria is fulfilled

5. **Clean up AI comments**

   - Review all AI-generated comments in the implemented code
   - Remove redundant comments that simply repeat what the code already expresses
   - Remove commented-out code blocks unless they serve a specific purpose
   - Keep only comments that provide valuable context that cannot be expressed through code structure
   - Ensure code is self-explanatory through clear naming and structure rather than excessive commenting
   - Apply the principle: "Comment what the code cannot say, not simply what it does not say"

   ref: https://github.com/97-things/97-things-every-programmer-should-know/tree/master/en/thing_16

6. **Commit Changes**

   Ask the subagent commit for changes.

7. **Loop Control**
   - If more instructions remain: mark next instruction as `in_progress`, return to phase 1
   - If all instructions completed: proceed to Phase 4

### Phase 4: Completion Report

For multiple instructions, format as:

```
## Instruction 1: [instruction summary]
ref: <commit_hash>
[Implementation details, decisions, and technical explanations]

## Instruction 2: [instruction summary]
ref: <commit_hash>
[Implementation details, decisions, and technical explanations]
```
