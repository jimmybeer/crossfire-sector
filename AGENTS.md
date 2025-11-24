# Repository Guidelines

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
