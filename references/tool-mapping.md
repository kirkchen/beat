# Tool Mapping Reference

Beat skills are written using Claude Code tool names as the canonical reference. If you are using Beat on a different platform, use this table to translate tool references in SKILL.md files to your platform's equivalents.

## Core Tools

| Skill references | Claude Code | Gemini CLI | Codex | GitHub Copilot |
|-----------------|-------------|------------|-------|----------------|
| Ask user a question | `AskUserQuestion` | `ask_user` | prompt user directly | prompt user directly |
| Read a file | `Read` | `read_file` | native file tools | native file tools |
| Write a file | `Write` | `write_file` | native file tools | native file tools |
| Edit a file | `Edit` | `replace` | native file tools | native file tools |
| Run a shell command | `Bash` | `run_shell_command` | native shell tools | native shell tools |
| Search file contents | `Grep` | `grep_search` | native search | native search |
| Search file names | `Glob` | `glob` | native search | native search |

## Skill & Agent Tools

| Skill references | Claude Code | Gemini CLI | Codex | Notes |
|-----------------|-------------|------------|-------|-------|
| Invoke another skill | `Skill` tool | `activate_skill` | loads natively | Used for `superpowers:*` prerequisites |
| Dispatch independent subagent | `Agent` tool (`subagent_type`) | no equivalent | `spawn_agent` | Used by `verify` and `distill` for unbiased verification |
| Track tasks | `TodoWrite` | `write_todos` | `update_plan` | — |

## Platform-Specific Notes

### Subagent Fallback

`verify` and `distill` use independent subagents (`Agent` tool with `subagent_type: Explore`) to avoid context bias during verification. On platforms without subagent support:

- **Run verification in a fresh session** — start a new conversation with only the artifacts and code as context, achieving the same bias isolation manually.
- The key requirement is that the verifier has **no access to the implementation conversation history**.

### Superpowers Integration

Beat skills reference `superpowers:*` skills as prerequisites (e.g., `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`). These are invoked via the Skill/activate_skill mechanism.

- If Superpowers is installed on your platform, the skill invocation works automatically.
- If Superpowers is not available, Beat skills include built-in fallbacks (e.g., simple checklist instead of `writing-plans`, direct implementation instead of TDD discipline).

### Hooks

Beat includes a Claude Code SessionStart hook (`hooks/`) that auto-detects Beat projects and injects workflow context. This is a convenience feature — on platforms without hooks, invoke Beat skills directly (e.g., `/beat:design`).
