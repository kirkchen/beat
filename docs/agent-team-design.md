# Agent Team Design for Beat

## Research: AI Development Pain Points

### Industry Data (2025-2026)

Recent research reveals a striking **productivity paradox** in AI-assisted development:

- **METR RCT Study**: Experienced open-source developers were **19% slower** with AI tools, despite predicting 24% faster. Even after completing the study, developers still believed AI sped them up by 20% — a remarkable perceptual gap.
- **Qodo State of AI Code Quality 2025**: 65% cite **missing context** as the primary cause of poor AI output (more than hallucinations). Only 3.8% of developers experience both low hallucinations and high shipping confidence.
- **Stack Overflow 2025 Survey**: 66% of developers spend extra time fixing "almost-right" AI suggestions.
- **CodeRabbit Analysis** (470 real-world PRs): AI-generated code produces **1.7x more issues** than human code overall.
- **Atlassian Research**: Developers only spend 16% of their time coding. AI coding speed gains are offset by non-coding bottlenecks — developers saved 10 hrs/week from AI but lost 10 hrs/week to other friction.

### Pain Point Taxonomy

Based on industry research and analysis of Beat's existing anti-pattern defenses, here are the 12 core pain points:

#### Category A: Context & Memory

| # | Pain Point | Evidence | Severity |
|---|-----------|----------|----------|
| A1 | **Context window saturation** | Agent loses early decisions as window fills; late-pipeline artifacts are weaker | Critical |
| A2 | **Missing project context** | 65% of developers cite this as #1 cause of poor AI output (Qodo) | Critical |
| A3 | **Cross-session amnesia** | Each new session starts blank; prior decisions lost unless explicitly recorded | High |
| A4 | **Architectural amnesia** | Agent forgets cross-cutting concerns (security, conventions, patterns) | High |

#### Category B: Quality & Correctness

| # | Pain Point | Evidence | Severity |
|---|-----------|----------|----------|
| B1 | **"Almost right" code** | 66% of devs spend extra time fixing AI suggestions (SO 2025). Code looks correct, passes cursory review, but has subtle bugs | Critical |
| B2 | **Self-verification bias** | Agent trusts its own output; can't objectively review what it just wrote | Critical |
| B3 | **Test quality illusion** | AI writes tests that pass but don't actually verify behavior (tautological tests, overly mocked) | High |
| B4 | **1.7x more issues** | AI code has more logic errors, security issues, and maintainability problems (CodeRabbit) | High |

#### Category C: Process & Discipline

| # | Pain Point | Evidence | Severity |
|---|-----------|----------|----------|
| C1 | **Rationalization drift** | Agent skips steps when it "seems simple enough"; invents excuses for shortcuts | Critical |
| C2 | **Sycophancy / over-agreement** | Agent agrees with user's flawed assumptions instead of challenging them | High |
| C3 | **Productivity perception gap** | Developers believe AI helps even when measurably slower (METR: -19% actual vs +20% perceived) | High |
| C4 | **Specification-implementation drift** | Implementation diverges from specification without the agent noticing | High |

### How Beat Already Addresses These

Beat's existing architecture provides defenses for many of these pain points:

| Pain Point | Beat Defense | Coverage |
|-----------|-------------|----------|
| A1 Context saturation | Artifact chain distills context at each phase | Partial — no fresh-session guidance |
| A2 Missing project context | `config.yaml` context injection into every skill | Complete |
| A3 Cross-session amnesia | `status.yaml` + artifacts carry full state | Complete |
| A4 Architectural amnesia | `design.md` + `config.yaml` context | Partial — no enforcement |
| B1 "Almost right" code | TDD (test before implementation) catches bugs at write time | Strong |
| B2 Self-verification bias | Verify subagent has NO implementation context | Complete |
| B3 Test quality illusion | Verify checks tests are executable, annotations are valid | Partial — doesn't check test logic |
| B4 1.7x more issues | 4-dimension verification + code-reviewer subagent | Strong |
| C1 Rationalization drift | Hard Gates + Rationalization Prevention Tables + Red Flags + Pressure Tests | Complete |
| C2 Sycophancy | `explore` skill has "curious, not prescriptive" stance | Partial — only in explore |
| C3 Productivity perception gap | Not addressed (Beat doesn't track metrics) | Gap |
| C4 Spec-implementation drift | Verify Dimension 1 (gherkin coverage) + Dimension 2 (proposal alignment) | Strong |

### Beat's Anti-Pattern Defense System (Deep Dive)

Beat has a sophisticated, multi-layered defense system against AI anti-patterns:

**Layer 1: Hard Gates** — Unconditional prerequisites that cannot be skipped.

```
"MUST" means unconditional. Not "if complex enough". Not "if time permits". Always.
```

| Skill | Hard Gate | What It Prevents |
|-------|----------|------------------|
| apply | `using-git-worktrees` | Implementing on main branch, polluting working tree |
| apply | `test-driven-development` | Writing code without tests, reversing TDD order |
| continue/ff | `brainstorming` | Shallow thinking on proposal/design |
| continue/ff | `writing-plans` | Unstructured task decomposition |
| explore | `brainstorming` | Jumping to solutions without understanding problem |
| archive | `finishing-a-development-branch` | Leaving branches unfinished |

**Layer 2: Rationalization Prevention Tables** — Pre-documented rebuttals to common AI excuses.

| AI Excuse | Rebuttal (from Beat skills) |
|-----------|---------------------------|
| "This change is simple enough to skip writing-plans" | Simple changes finish writing-plans quickly. Complex changes need it most. No middle ground where skipping helps. |
| "I already understand the scope from proposal" | Understanding scope ≠ having decomposed tasks. Writing-plans forces decomposition. |
| "I'll write tests after the implementation" | TDD is about design feedback, not coverage. Writing test first reveals API design issues. |
| "This is a refactor, TDD doesn't apply" | Refactors are exactly when TDD proves behavior preservation. |
| "I'll batch @covered-by annotations at the end" | You will forget. Add annotations when writing each test. |
| "I'll set up the worktree after this one file" | That "one file" becomes five. Worktree first, always. |

**Layer 3: Red Flags** — Behavioral signals that indicate the agent is drifting.

- Writing code before invoking worktrees
- Implementing before a failing test exists (in TDD mode)
- Generating proposal without brainstorming
- Writing task checkboxes before writing-plans
- Judging prerequisites "unnecessary for this case"
- Planning to "compensate later"

**Layer 4: Pressure Tests** — Automated tests that simulate hostile scenarios:

- `apply-time-pressure.txt`: "Demo in an hour, implement quickly, add tests later"
- `apply-simple-change.txt`: "Just a one-function module, no elaborate testing"
- `ff-time-pressure.txt`: "I'm in a rush, just fast-forward everything"
- `ff-simple-change.txt`: "One-line config fix, skip brainstorming"

These tests assert the agent still invokes Hard Gate prerequisites under pressure.

### Remaining Gaps (Agent Team Opportunities)

| Gap | Description | Agent Team Solution |
|-----|-------------|-------------------|
| **Fresh-context guidance** | No mechanism to suggest "start a new session" when context is saturated | SessionStart hook tracks session depth, suggests handoff |
| **Test logic verification** | Verify checks test existence and annotations, not whether tests actually verify behavior | Dedicated test-quality review subagent |
| **Productivity metrics** | No way to measure if the pipeline actually improves quality | Quality scorecard tracked across pipeline |
| **Sycophancy in implementation** | Agent follows flawed design without questioning | Cross-phase review where verifier checks design decisions |
| **Parallel task coordination** | `subagent-driven-development` exists but no Beat-specific parallel protocol | Structured parallel implementation with merge strategy |

---

## Problem Statement

The agent team design addresses the **remaining gaps** not covered by Beat's existing defenses:

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

This section maps each pain point from the taxonomy to a concrete solution in the agent team model.

### A1: Context Window Saturation → Fresh-Context Pipeline

**Pattern**: Pattern 2 (Fresh-Context Pipeline)

Each session starts with a clean context window. Artifacts carry all necessary context. The SessionStart hook ensures the new session knows where to pick up.

**Mechanism**: Beat's artifact chain (proposal → gherkin → design → tasks) naturally distills context at each phase. A fresh session reading these artifacts has better context than a saturated session that wrote them.

**New**: The enhanced SessionStart hook detects context depth and suggests: "This change has been in progress for N interactions. Consider starting a fresh session — artifacts carry your full context."

### A2: Missing Project Context → config.yaml + Context Injection

**Beat already solves this** via `config.yaml` context field. Every skill reads it.

**Enhancement**: Provide a `/beat:setup` guided wizard that thoroughly scans the project and generates rich context (tech stack, architecture patterns, testing conventions, naming standards).

### A3-A4: Cross-Session & Architectural Amnesia → Artifact-Based Memory

**Beat already solves cross-session** via `status.yaml` + artifacts.

**Enhancement for architectural amnesia**: The `config.yaml` context field should include cross-cutting concerns. Example:

```yaml
context: |
  Security: All user input must be validated. SQL uses parameterized queries.
  Error handling: All API errors return RFC 7807 format.
  Naming: React components use PascalCase, utilities use camelCase.
  Testing: Every public API endpoint needs an integration test.
```

This context is injected into EVERY skill invocation, preventing any session from forgetting these concerns.

### B1: "Almost Right" Code → TDD + Independent Verification

**Beat's layered defense**:
1. **TDD** (test-driven-development prerequisite) catches bugs at write time by requiring test BEFORE implementation
2. **Verify subagent** catches what TDD missed by independently checking against specification
3. **Code-reviewer subagent** catches quality issues

**Enhancement**: In the team model, the Implementer and Verifier are always different sessions (or subagents). The Verifier has zero context about implementation struggles, workarounds, or "temporary" decisions.

### B2: Self-Verification Bias → Independent Subagent Architecture

**Beat already solves this completely**. The verification subagent receives ONLY artifacts and code — no conversation history, no implementation rationale.

**Enhancement**: In Pattern 2, verification happens in a completely separate Claude session, adding an additional layer of independence beyond subagent isolation.

### B3: Test Quality Illusion → Verify Dimension Enhancement

**Current state**: Verify checks test existence, executability, and annotation format — but not whether tests actually verify meaningful behavior.

**Enhancement opportunity**: Add a test-quality check to the verification subagent:
- Are tests tautological (always pass regardless of implementation)?
- Are tests over-mocked (testing mocks instead of behavior)?
- Do tests exercise the scenario's Given/When/Then, not just call the function?

### B4: 1.7x More Issues → 4-Dimension Verification

**Beat already addresses this** through 4-dimension verification:
1. Gherkin Coverage & Quality
2. Proposal Alignment
3. Design Adherence
4. Code Quality (via code-reviewer)

**Enhancement**: Track verify findings over time to identify recurring issue patterns. If "security validation missing" appears in 3 consecutive changes, add it to `config.yaml` rules.

### C1: Rationalization Drift → Hard Gate System

**Beat already solves this completely** with the 4-layer defense:
1. Hard Gates (unconditional prerequisites)
2. Rationalization Prevention Tables (pre-documented rebuttals)
3. Red Flags (behavioral signals)
4. Pressure Tests (automated validation)

**Enhancement**: The team model adds human review between phases as an additional rationalization check. The team lead reviews artifacts before approving the next phase.

### C2: Sycophancy / Over-Agreement → Explorer Role + Cross-Phase Review

**Current state**: The explore skill has a "curious, not prescriptive" stance but other phases don't challenge assumptions.

**Enhancement**: Add a "Devil's Advocate" check to the Architect role — before creating design.md, briefly list assumptions from the proposal/gherkin and flag any that seem risky or unvalidated.

### C3: Productivity Perception Gap → Quality Scorecard

**Current gap**: Beat doesn't track whether its pipeline actually improves quality.

**Enhancement**: Track metrics across the pipeline:

| Metric | Where Measured | What It Reveals |
|--------|---------------|-----------------|
| Verify first-pass rate | After first verify | How often implementation is right on first try |
| Fix cycle count | Verify-fix loop | How many iterations to pass verification |
| CRITICAL issue density | Verify report | Quality of the implementation phase |
| Annotation completeness | Verify Dimension 1 | Whether TDD discipline is maintained |
| Spec-to-code ratio | After apply | How well specs translate to implementation |

### C4: Specification-Implementation Drift → Verify Dimensions 1-2

**Beat already addresses this** through:
- Dimension 1: Every scenario has a test (coverage)
- Dimension 2: Every proposal goal is implemented (alignment)

**Enhancement**: In the team model, the Fresh-Context Pipeline ensures the Implementer reads specs with fresh eyes (no "I wrote these specs so I know what they mean" bias).

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
