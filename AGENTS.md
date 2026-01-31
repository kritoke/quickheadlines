# Agent Instructions

This project uses **OpenSpec** for change tracking and specification management.
All work must be structured as an OpenSpec Change within `openspec/changes/`.

## OpenSpec Workflow

1. **New Change:** Use `/opsx:new <name>` or `/opsx:ff <name>` to start a task.
2. **Implementation:** Use `/opsx:apply <name>` to work through tasks.
3. **Verification:** Use `/opsx:verify <name>` to ensure implementation matches specs.
4. **Archival:** Use `/opsx:archive <name>` to finalize work and sync specs.

## Critical Directives

### 1. The Core Agent Directive

> Execution Context:
> This project is a Nix Spoke. You are running inside a persistent Hub, but the project-specific tools (Crystal 1.19.1, Elm, Shards) are isolated.
> Rule: For ANY shell command execution (compiling, testing, formatting), you MUST prefix the command with `nix develop . --command`.
> - Incorrect: `crystal spec`
> - Correct: `nix develop . --command crystal spec`
> - Incorrect: `shards install`
> - Correct: `nix develop . --command shards install`

### 2. The Library/Linker Workaround

Because Crystal 1.19.1 is manually derived and requires specific library paths:

> Library Path Handling:
> If a command fails with a "library not found" error (e.g., libgc.so.1 or libevent), do not attempt to install packages via apt. Instead, verify that the command is being run through the nix develop wrapper, as the flake handles the LD_LIBRARY_PATH internally.

### 3. OpenSpec Discipline

> Task Discipline:
> Agents must create a Change Proposal (`/opsx:new`) before writing code. Archival (`/opsx:archive`) is mandatory for all completed tasks to merge changes into the permanent specs in `openspec/specs/`.

### 4. Why This Is Necessary

OpenCode agents often try to be "helpful" by running commands directly in the shell they find themselves in. In this setup:
- The Base Shell is your "Hub" (which has Go, Node, but NOT Crystal 1.19.1)
- The Sub-Shell created by `nix develop . --command` has the "Spoke" tools

If you don't use the prefix, you will get a `command not found: crystal` error, even though the file is right there in the project.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Verify Work:** Run `nix develop . --command npx playwright test` and any relevant Crystal specs.
2. **Archival:** Use `/opsx:archive <name>` for all completed changes.
3. **PUSH TO REMOTE:**
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
4. **Clean up:** Clear stashes, prune remote branches.
5. **Hand off:** Provide context for next session.

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds.
- NEVER stop before pushing - that leaves work stranded locally.
- NEVER say "ready to push when you are" - YOU must push.
- If push fails, resolve and retry until it succeeds.


