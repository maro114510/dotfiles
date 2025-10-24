## Premise

1. Before starting the task, be sure to use Serena MCP to gain a structural understanding of the project.If Serena MCP is not available, please suspend the task.
2. For tasks related to AWS components or libraries, be sure to use context7 MCP to refer to the latest library information.
  - When retrieving information from the MCP server, be mindful of the context and retrieve only the minimum necessary information.
3. Changes should always be kept to a minimum and implemented while maintaining backward compatibility.

# AI-Driven Development Common Guidelines

## Core Development Principles
- Always prioritize quality, maintainability, and safety, not just writing functional code
- Strike an appropriate balance based on the project phase (prototype, MVP, production environment)
- Never ignore issues; always address them or explicitly document them
- Boy Scout Rule: Leave code in better shape than you found it

## Error Handling Principles
- Resolve even seemingly unrelated errors
- Fix root causes instead of suppressing errors (e.g., @ts-ignore, swallowing with try-catch)
- Detect errors early and provide clear error messages
- Always cover error cases in tests
- Always account for potential failures in external APIs and network communications

## Code Quality Standards
- DRY Principle: Avoid duplication and maintain a single source of truth
- Use meaningful variable and function names to clearly convey intent
- Maintain consistent coding style across the entire project
- Fix even minor issues immediately upon discovery (Broken Windows Theory)
- Comments explain “why”; code expresses “what”

## Testing Discipline
- Never skip tests; fix issues when detected
- Test behavior, not implementation details
- Avoid dependencies between tests to enable execution in any order
- Ensure tests are fast and consistently produce the same results
- Treat coverage as a metric; prioritize high-quality tests

## Maintainability and Refactoring
- Consider improving existing code when adding new features
- Break large changes into small steps
- Actively remove unused code
- Regularly update dependencies (for security and compatibility)
- Explicitly document technical debt in comments or documentation

## Security Mindset
- Manage API keys, passwords, etc. via environment variables (no hardcoding)
- Validate all external inputs
- Operate with the minimum necessary permissions (principle of least privilege)
- Avoid unnecessary dependencies
- Run security audit tools regularly

## Performance Awareness
- Optimize based on measurement, not guesswork
- Consider scalability from the initial stages
- Delay loading resources until needed
- Clearly define cache expiration and invalidation strategies
- Avoid N+1 problems and overfetching

## Ensuring Reliability
- Properly configure timeout handling
- Implement retry mechanisms (consider exponential backoff)
- Utilize circuit breaker patterns
- Build resilience against transient failures
- Ensure observability through appropriate logging and metrics

## Understanding Project Context
- Balance business requirements with technical requirements
- Determine the truly necessary quality level for the current phase
- Maintain minimum quality standards even under time constraints
- Choose implementations aligned with the team's overall technical level

## Recognizing Tradeoffs
- Perfection is impossible (no silver bullet exists)
- Find the optimal balance within constraints
- Prioritize simplicity for prototypes, robustness for production
- Clearly document tradeoffs and their rationale

## Git Operations Fundamentals
- Use conventional commit formats (feat:, fix:, docs:, test:, refactor:, chore:)
- Commits should be atomic, focusing on a single change
- Write clear, descriptive commit messages in English
- Avoid direct commits to main/master branches

## Code Review Attitude
- Receive review comments as constructive improvement suggestions
- Focus on the code, not the individual
- Clearly explain the reason for and impact of the change
- Welcome feedback as a learning opportunity

## Debugging Best Practices
- Establish steps to reliably reproduce the issue
- Narrow down the scope of the problem using binary search
- Start investigation from recent changes
- Utilize appropriate tools like debuggers and profilers
- Document findings and solutions to share knowledge

## Dependency Management
- Add only dependencies that are truly necessary
- Always commit lock files like package-lock.json
- Verify licenses, size, and maintenance status before adding new dependencies
- Update regularly for security patches and bug fixes

## Documentation Standards
- Clearly document project overview, setup, and usage in the README
- Update documentation in sync with code changes
- Prioritize providing concrete examples
- Document critical design decisions in ADR (Architecture Decision Records)

## Continuous Improvement
- Apply lessons learned to subsequent projects
- Conduct regular retrospectives to refine processes
- Evaluate and adopt new tools and methodologies appropriately
- Document knowledge for the team and future developers

Translated with DeepL.com (free version)
