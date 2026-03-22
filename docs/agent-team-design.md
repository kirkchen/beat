# Agent Team Design for Beat

## Problem Statement

AI-driven software development with a single Claude Code session faces fundamental challenges:

| Problem | Symptom | Impact |
|---------|---------|--------|
| **Context saturation** | Agent loses early decisions as context fills | Inconsistent implementations, repeated mistakes |
| **Self-verification bias** | Agent trusts its own output | Missed bugs, rationalized shortcuts |
| **No specialization** | One agent plays every role | Shallow thinking at each phase |
| **Quality degradation** | Quality drops in long sessions | Late-pipeline artifacts are weaker |
| **Rationalization drift** | Agent skips steps under time/context pressure | Incomplete verification, missing tests |
| **Architectural amnesia** | Agent forgets cross-cutting concerns | Security gaps, inconsistent patterns |

Beat already addresses some of these (structured pipeline, independent verification subagents, anti-rationalization gates). This design extends Beat with an **agent team model** that solves the remaining gaps.

## Design Constraints

Claude Code's execution model constrains what "agent team" means:

1. **No persistent agents** — Each Claude session is independent; agents don't run continuously
2. **Subagents are ephemeral** — Agent tool spawns one-shot subagents that return a result and terminate
3. **No shared memory** — Sessions share state only through the file system
4. **Single orchestrator** — One main agent per session; subagents can't spawn their own subagents
5. **Hooks inject context** — SessionStart hooks can set up agent role awareness

**Implication**: The "team" is not multiple persistent agents. It's a **role-based protocol** where different Claude sessions (or subagents) assume specialized roles, coordinating through Beat's file-based state machine.

## Architecture: Role-Based Agent Protocol

### Core Idea

Each Beat pipeline phase maps to a specialized **agent role**. The human developer acts as **team lead**, invoking the right role at the right time through Beat skills. The file system (status.yaml, artifacts, config.yaml) is the shared coordination layer.

```
                    ┌─────────────────────────────────────────────┐
                    │              Human (Team Lead)              │
                    │  Invokes skills, reviews artifacts, decides │
                    └──────┬──────────────┬──────────────┬────────┘
                           │              │              │
                    ┌──────▼──────┐ ┌─────▼──────┐ ┌────▼───────┐
                    │  Explorer   │ │ Specifier  │ │ Architect  │
                    │ /beat:explore│ │/beat:continue│ │/beat:continue│
                    │             │ │ (gherkin)  │ │ (design)   │
                    └─────────────┘ └────────────┘ └────────────┘
                                                         │
                    ┌─────────────┐ ┌────────────┐ ┌─────▼──────┐
                    │  Verifier   │ │  Reviewer  │ │Implementer │
                    │/beat:verify │ │ (subagent) │ │ /beat:apply │
                    │ (subagent)  │ │            │ │             │
                    └─────────────┘ └────────────┘ └─────────────┘
                           │
                    ┌──────▼──────┐
                    │ Integrator  │
                    │/beat:sync   │
                    │/beat:archive│
                    └─────────────┘
```

### Agent Roles

#### 1. Explorer (探索者)

**When**: Before creating a change, or when direction is unclear
**Beat skill**: `/beat:explore`
**Superpowers**: `brainstorming`

**Responsibilities**:
- Understand the problem space deeply
- Map existing codebase architecture
- Surface risks, unknowns, and alternatives
- Produce clarity, not artifacts

**Quality contribution**: Prevents building the wrong thing.

#### 2. Specifier (規格者)

**When**: Creating proposal and gherkin artifacts
**Beat skills**: `/beat:continue` (proposal, gherkin), `/beat:ff`
**Superpowers**: `brainstorming`

**Responsibilities**:
- Articulate WHY (proposal) and WHAT (gherkin)
- Write behavior-level scenarios (not function-level)
- Assign testing layer tags (@e2e, @behavior)
- Apply granularity assessment

**Quality contribution**: Forces specificity. Vague requirements become concrete scenarios.

#### 3. Architect (設計者)

**When**: Creating design and tasks artifacts
**Beat skills**: `/beat:continue` (design, tasks), `/beat:ff`
**Superpowers**: `brainstorming`, `writing-plans`

**Responsibilities**:
- Make technical decisions constrained by known behavior (gherkin)
- Plan implementation order
- Identify architectural impacts
- Create actionable task breakdown

**Quality contribution**: Implementation follows a plan instead of improvising.

#### 4. Implementer (實作者)

**When**: TDD implementation phase
**Beat skill**: `/beat:apply`
**Superpowers**: `using-git-worktrees`, `test-driven-development`, `systematic-debugging`, `subagent-driven-development`

**Responsibilities**:
- Work in isolated git worktree
- Follow TDD: test first, then implement
- Follow design decisions exactly
- Add @covered-by annotations for traceability
- Mark tasks complete as they're done

**Quality contribution**: TDD ensures every scenario has a passing test. Worktree isolation prevents breaking main.

#### 5. Verifier (驗證者)

**When**: After implementation, before archive
**Beat skill**: `/beat:verify`
**Superpowers**: `code-reviewer`

**Responsibilities**:
- Independent verification (subagent with no implementation context)
- 4-dimension check: gherkin coverage, proposal alignment, design adherence, code quality
- Classify issues: CRITICAL / WARNING / SUGGESTION
- Run automated tests

**Quality contribution**: Eliminates self-verification bias. The verifier has never seen the implementation conversation.

#### 6. Integrator (整合者)

**When**: After verification passes
**Beat skills**: `/beat:sync`, `/beat:archive`
**Superpowers**: `finishing-a-development-branch`

**Responsibilities**:
- Sync features to living documentation
- Archive completed change
- Finish development branch (merge/PR)

**Quality contribution**: Ensures documentation stays current and branches are properly closed.

## Coordination Protocol

### Phase Handoff via Artifacts

Each role produces artifacts that become input for the next role. The file system IS the coordination layer:

```
Explorer                    Specifier                 Architect
  │                           │                          │
  │ (clarity, direction)      │ proposal.md              │ design.md
  │                           │ features/*.feature       │ tasks.md
  └──── verbal/explore ──────►└──── status.yaml ────────►└──── status.yaml ─────►
                                                                                  │
Integrator                  Verifier                  Implementer                │
  │                           │                          │                        │
  │ beat/features/            │ verify-report            │ code + tests           │
  │ archive/                  │ (CRITICAL/WARN/SUGGEST)  │ @covered-by            │
  ◄──── status.yaml ─────────◄──── status.yaml ─────────◄──── status.yaml ───────┘
```

### Context Distillation

**Problem**: When a new session picks up where a previous session left off, it has no context about prior decisions.

**Solution**: Each artifact serves as a **context distillation document**. When a new session starts:

1. SessionStart hook detects active changes (`beat/changes/`)
2. Agent reads `status.yaml` to understand current phase
3. Agent reads all completed artifacts for full context
4. Agent has everything needed to continue from current phase

This is already how Beat works — but making it explicit as a team coordination protocol strengthens it.

### Handoff Checklist

When transitioning between roles (sessions), verify:

```
□ status.yaml phase is current
□ All completed artifacts are committed to git
□ Any decisions not captured in artifacts are added (to design.md or proposal.md)
□ config.yaml is up to date
```

## Team Workflow Patterns

### Pattern 1: Solo Developer (Single Session)

The simplest pattern — one developer, one Claude session, all roles played sequentially:

```
/beat:explore → /beat:ff → /beat:apply → /beat:verify → /beat:archive
```

**Best for**: Small to medium changes where context window isn't a concern.

### Pattern 2: Fresh-Context Pipeline (Multiple Sessions)

Each pipeline phase runs in a fresh Claude session to avoid context saturation:

```
Session 1: /beat:explore → /beat:new → /beat:continue (proposal)
Session 2: /beat:continue (gherkin) → /beat:continue (design)
Session 3: /beat:continue (tasks)
Session 4: /beat:apply
Session 5: /beat:verify → /beat:sync → /beat:archive
```

**Best for**: Large features where context would saturate in a single session. Each session starts fresh with full context from artifacts.

**Key benefit**: The implementer (Session 4) reads the gherkin, design, and tasks with completely fresh context — no bias from the specification-writing process.

### Pattern 3: Parallel Implementation (Subagent Team)

When `tasks.md` contains multiple independent tasks, `/beat:apply` can invoke `superpowers:subagent-driven-development` to parallelize:

```
Session: /beat:apply
  ├── Subagent 1: Task 1 (independent feature A)
  ├── Subagent 2: Task 2 (independent feature B)
  └── Subagent 3: Task 3 (independent feature C)
```

**Best for**: Changes with clearly independent implementation units. Beat already supports this via the conditional `subagent-driven-development` prerequisite in `/beat:apply`.

### Pattern 4: Review Loop (Verify-Fix Cycle)

When verification finds CRITICAL issues, loop between implementer and verifier:

```
/beat:apply → /beat:verify → [CRITICAL issues found]
  → fix issues → /beat:verify → [all clear]
  → /beat:archive
```

**Best for**: Complex changes where first implementation rarely passes verification. The verify-fix loop is the agent team equivalent of code review.

### Pattern 5: Distill-First Adoption

For existing codebases adopting Beat:

```
Session 1: /beat:distill (scope: auth module)
Session 2: /beat:distill (scope: billing module)
Session 3: /beat:verify → /beat:sync → /beat:archive (for each)
```

**Best for**: Bringing an established codebase under Beat's specification coverage. Each distill session is independent.

## Solving AI Development Problems

### Problem 1: Context Saturation

**Solution**: Fresh-Context Pipeline (Pattern 2)

Each session starts with a clean context window. Artifacts carry all necessary context. The SessionStart hook ensures the new session knows where to pick up.

**Mechanism**: Beat's artifact chain (proposal → gherkin → design → tasks) naturally distills context at each phase. A fresh session reading these artifacts has better context than a saturated session that wrote them.

### Problem 2: Self-Verification Bias

**Solution**: Already solved by Beat's verify subagent architecture

The verification subagent receives ONLY artifacts and code — no conversation history, no implementation rationale. It verifies objectively against the specification.

**Enhancement**: In the team model, verification can happen in a completely separate session (Pattern 2, Session 5), adding an additional layer of independence.

### Problem 3: Quality Degradation in Long Sessions

**Solution**: Fresh-Context Pipeline + Subagent Parallelization

Break long sessions into focused, short sessions. Each role-session has a clear, bounded scope:
- Specifier: only write specs (30-60 min)
- Architect: only design (30-60 min)
- Implementer: only code (variable, but scoped by tasks)
- Verifier: only verify (15-30 min)

### Problem 4: Rationalization Drift

**Solution**: Already solved by Beat's Hard Gate system

Every MUST prerequisite has:
- Unconditional invocation (no "this is too simple" escape)
- Rationalization Prevention Table (documents common excuses)
- Red Flags (patterns that indicate skipping)

**Enhancement**: In the team model, the human acts as team lead and can catch rationalization by reviewing artifacts between phases.

### Problem 5: Architectural Amnesia

**Solution**: Design artifact + config.yaml context injection

The `design.md` artifact captures architectural decisions. The `config.yaml` context field injects project-wide architectural guidelines into every skill invocation. These persist across sessions.

**Enhancement**: Add a `beat/architecture.md` or use `config.yaml` context to document cross-cutting concerns (security patterns, error handling conventions, naming standards) that every implementer session inherits.

### Problem 6: No Peer Review Equivalent

**Solution**: Verify-Fix Loop (Pattern 4)

Beat's verify skill IS the peer review. It:
- Uses an independent subagent (different "person" reviewing)
- Checks against specification (not just "does it look right")
- Dispatches code-reviewer for quality checks
- Produces actionable findings with severity classification

## Recommended Team Configurations

### For Small Teams (1-2 developers)

```yaml
# beat/config.yaml
context: |
  Team protocol: Solo Developer (Pattern 1)
  Use /beat:ff for small changes, /beat:explore + /beat:continue for larger ones
  Always run /beat:verify before /beat:archive
```

Workflow:
1. Developer uses Beat skills directly
2. Single session for small changes
3. Fresh-context pipeline for large changes
4. Verification is mandatory (never skip)

### For Medium Teams (3-5 developers)

```yaml
# beat/config.yaml
context: |
  Team protocol: Fresh-Context Pipeline (Pattern 2)
  Specification and implementation are separate sessions
  Verify-fix loop until all CRITICAL issues resolved

  Cross-cutting concerns:
  - All API endpoints must have input validation
  - Error responses follow RFC 7807
  - Database queries must use parameterized statements
```

Workflow:
1. One developer explores and specifies (Sessions 1-2)
2. Same or different developer implements (Session 3-4)
3. Verification in fresh session (Session 5)
4. Human reviews verify report and decides on archive

### For AI-Heavy Teams (Automated pipeline)

```yaml
# beat/config.yaml
context: |
  Team protocol: Automated Pipeline
  Each phase runs in a fresh Claude session
  Verification must pass with zero CRITICAL issues
  Two independent verify passes required for large changes

  Quality gates:
  - Proposal: must identify at least one risk
  - Gherkin: every scenario must have testing layer tag
  - Design: must reference existing module structure
  - Tasks: each task maps to specific scenario(s)
  - Apply: all tests pass, all annotations present
  - Verify: zero CRITICAL, warnings acknowledged
```

Workflow:
1. Automated orchestrator runs Beat skills in sequence
2. Each skill runs in its own Claude session (`claude -p`)
3. Artifacts are committed between phases
4. Human reviews at key checkpoints (after gherkin, after verify)
5. Automated merge after all gates pass

## Implementation: Agent Team Orchestrator

### Option A: Shell Script Orchestrator

A shell script that runs the Beat pipeline with fresh sessions:

```bash
#!/bin/bash
# beat-team.sh — Run Beat pipeline with fresh-context sessions
CHANGE_NAME=$1

# Phase 1: Specify
claude -p "Run /beat:new for change '$CHANGE_NAME', then /beat:ff with Standard preset"

# Phase 2: Review specs (human checkpoint)
echo "Review specifications in beat/changes/$CHANGE_NAME/"
read -p "Continue to implementation? (y/n) " -n 1 -r
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Phase 3: Implement
claude -p "Run /beat:apply for change '$CHANGE_NAME'"

# Phase 4: Verify
claude -p "Run /beat:verify for change '$CHANGE_NAME'"

# Phase 5: Review report (human checkpoint)
echo "Review verify report above"
read -p "Archive? (y/n) " -n 1 -r
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Phase 6: Archive
claude -p "Run /beat:sync then /beat:archive for change '$CHANGE_NAME'"
```

### Option B: New Beat Skill (`/beat:team`)

A new skill that guides the human through the team workflow:

```
/beat:team — Agent team orchestration
```

This skill would:
1. Ask which team pattern to use (Solo, Fresh-Context, Parallel)
2. Guide through each phase with clear handoff points
3. Suggest when to start a new session for fresh context
4. Track team-level metrics (phases completed, issues found, fix cycles)

### Option C: Enhanced SessionStart Hook

Enhance the existing SessionStart hook to be team-aware:

1. Detect active changes and their current phase
2. Suggest the appropriate agent role for the current phase
3. Inject role-specific guidance (e.g., "You are the Implementer for change X. Read design.md and tasks.md before starting.")
4. Track session count per change (suggest fresh session after N interactions)

## Recommendation

**Start with Option C** (Enhanced SessionStart Hook) because:

1. **Zero new skills needed** — Works within existing Beat architecture
2. **Immediate value** — Every session automatically gets role guidance
3. **Non-intrusive** — Doesn't change any existing workflow
4. **Progressive** — Can layer Option B on top later

**Then add Option A** (Shell Script) for teams wanting automated pipeline execution.

**Option B** (/beat:team skill) is the most powerful but also the most complex. Defer until Patterns 1-4 are validated in real usage.

## Appendix: Quality Metrics

Track these metrics across the agent team pipeline to measure effectiveness:

| Metric | Measured At | Target |
|--------|-------------|--------|
| Spec completeness | After gherkin | Every user behavior has a scenario |
| Test coverage | After apply | Every @behavior scenario has @covered-by |
| Verify pass rate | After verify | Zero CRITICAL on first verify |
| Fix cycle count | Verify-fix loop | ≤ 2 cycles to zero CRITICAL |
| Context freshness | Session start | Fresh session for each major phase |
| Annotation accuracy | After verify | All @covered-by point to valid tests |

## Appendix: Comparison with Traditional Multi-Agent Systems

| Aspect | Traditional Multi-Agent | Beat Agent Team |
|--------|------------------------|-----------------|
| Agent lifecycle | Persistent, concurrent | Ephemeral, sequential |
| Communication | Message passing, shared memory | File system (artifacts) |
| Coordination | Centralized orchestrator | Human team lead + status.yaml |
| Specialization | Agent type (planner, coder, tester) | Role per pipeline phase |
| Verification | Consensus / voting | Independent subagent (no shared context) |
| State management | In-memory, distributed | File system (git-tracked) |
| Scalability | More agents = more parallelism | More sessions = fresher context |
| Failure recovery | Agent restart, state replay | Read artifacts, continue from current phase |

Beat's approach is better suited to Claude Code's execution model because it leverages the file system as a durable coordination layer, uses git for state tracking, and treats context freshness as a feature rather than a limitation.
