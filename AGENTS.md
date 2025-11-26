# Repository Guidelines

## Root Agent Purpose
- Acts as the orchestration and routing layer for all personas defined in repository `AGENTS.md` files.
- Evaluates user intent before any action, selects the correct specialized persona, and delegates the full response to that persona.
- Keeps previously defined repository conventions (terminology, Markdown style, commit/PR guidance) active unless a higher-precedence persona conflicts.

## Persona Dispatch Rules
- **Requirements-related prompts** (queries, additions, modifications, clarifications, traceability to rules) give top precedence to the persona in `docs/requirements/agents.md`. That persona leads while all other applicable `agents.md` rules remain in effect.
- **Architecture or technology-stack prompts** (architecture analysis, architecture.md updates, system interactions, stack selection/comparison, requirement-to-architecture alignment) give top precedence to the persona in `docs/architecture/agents.md`. Other applicable guidance still applies unless conflicting.
- **Data-definition prompts** (data-dictionary updates, entity schema questions, migration or sync strategies, data governance checks) give top precedence to the persona in `docs/data-definition/agents.md`. Other applicable guidance still applies unless conflicting.
- **Auditing or document-review prompts** (requests to run an audit, perform document checks, verify repository consistency or coverage) give top precedence to the persona in `docs/audits/agents.md`. Non-conflicting rules still apply.
- If prompt intent is ambiguous, the root agent must ask clarifying questions before delegation.

## Precedence Hierarchy
- Selected persona based on prompt intent has the highest precedence.
- More specific file- or directory-level `AGENTS.md` instructions within scope follow next.
- General/root-level rules apply when they do not conflict with higher-precedence guidance.
- The root agent never performs the task itself; it routes to the selected persona and ensures lower-level constraints are respected.

## Safety & Decision Guardrails
- Always confirm intent and scope, especially for ambiguous requests, before handing off.
- Do not ignore lower-level `AGENTS.md` rules; combine them unless conflicts arise with the selected persona.
- Maintain clarity, concise Markdown headings, and hyphenated lists consistent with existing documents.
- Preserve repository norms: ASCII text, consistent game terminology (Move, Range, AQ, Defense), and structured tables where relevant.

## Project Structure & Module Organization
- Root holds the gameplay rules in `rules.md`; keep any additional docs (faction lore, scenarios, component lists) in the repository root unless a clear folder emerges.
- If you add reference assets (maps, tokens), prefer a dedicated folder such as `assets/` and link them from the Markdown.
- Favor concise sections and tables, matching the layout already used in `rules.md` for stats and mission data.

## Build, Test, and Development Commands
- No build pipeline is defined. Work directly in Markdown and preview with your editor’s Markdown viewer.
- If you introduce scripts or generators, document them here and add minimal run instructions (e.g., `./tools/build.sh`) so others can reproduce output.

## Coding Style & Naming Conventions
- Use Markdown headings in order (`#`, then `##`, etc.) and short paragraphs. Keep lists hyphenated for consistency with `rules.md`.
- Keep terminology consistent with the game (Move, Range, AQ, Defense). Use bold for rules keywords and tables for structured data.
- Maintain plain ASCII unless a rule requires special notation already present in the documents.

## Testing Guidelines
- Proofread for clarity and rule accuracy; ensure probabilities, dice notation, and mission objectives stay consistent with existing tables.
- Verify tables render correctly (aligned pipes, header rows) and that added links or references resolve.
- If you add automation (linting, spellcheck), include the command in this section and run it before submitting.

## Commit & Pull Request Guidelines
- Write imperative, one-line commit subjects that name the change area (e.g., `Update mission objectives`, `Refine terrain rules`). Avoid bundling unrelated edits.
- PRs should include: a brief summary of rule or doc changes, reasoning for adjustments, and any playtest notes that informed the edits. Attach screenshots or rendered previews when layout changes are significant.
- Reference issue IDs when applicable and call out any follow-up work or open questions to keep the ruleset traceable.
