# AGENTS Workflow

This repository expects future agents to follow a consistent working pattern.

## Required Workflow

When a new request arrives, follow this order:

1. Read the relevant project documents first.
   - Start with `README.md`
   - Read `docs/project-overview.md`
   - Read `docs/development-log.md`
   - Read any other directly relevant files before editing

2. Explore the project freely before proposing changes.
   - Inspect the current code path
   - Confirm key files, dependencies, entrypoints, and runtime behavior
   - Verify assumptions from the actual repository state

3. Write an implementation plan before making substantial changes.
   - Keep the plan concrete
   - Base it on the codebase as it currently exists
   - Use the plan to guide the implementation, not as a placeholder

4. Implement according to the plan.
   - Prefer small, coherent changes
   - Preserve existing behavior unless the task requires changing it
   - Validate the affected flow as much as the environment allows

5. Record the work in the development log.
   - Update `docs/development-log.md`
   - Summarize what changed, how it was verified, and any known follow-up items

6. Sync the project documentation.
   - Update `docs/project-overview.md` when architecture, workflow, or operating assumptions change
   - Update `README.md` when user-facing behavior or usage changes

7. Do not forget to create a git commit.
   - Commit the relevant source and documentation changes
   - Do not include unrelated local artifacts such as `xcuserdata`

## Practical Notes

- Treat `ocr/main.swift` as the main implementation entrypoint unless the repository is restructured later.
- Treat the local Ollama HTTP API as authoritative for backend validation on this machine.
- Prefer repository documentation plus direct code inspection over guesswork.
