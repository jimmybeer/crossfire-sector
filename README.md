# Crossfire Sector

## Overview
- Digital adaptation of the Crossfire Sector tabletop skirmish game for two-player local play on desktop and mobile, with future-ready online support.
- Godot 4 project with deterministic, data-driven rules that match the tabletop probabilities and sequencing in `docs/rules.md`.
- Core goals: enforce GR/DA/CP/AQ/MP requirements, keep content configurable (factions, missions, terrain, optional rules), and preserve replayable, seeded command logs.

## Project Layout
- `/docs` – Source of truth for rules, requirements, architecture, tech stack, data dictionary, audits, plans, and project overview (`docs/project.md`).
- `/project` – Codex agent workspace utilities and tooling contract (Godot/GDScript/C# guidance).
- `/icon.svg` – Project icon assets.
- `.godot/` – Godot editor cache (do not edit by hand).

## Quick Start
- Open the project with Godot 4.x (root contains `project.godot`).
- Use the docs below to align gameplay behavior, architecture, and data schemas before implementing features.

## Key References
- Rules: `docs/rules.md`
- Requirements: `docs/requirements/requirements.md`
- Architecture: `docs/architecture/architecture.md`
- Tech stack: `docs/architecture/tech-stack.md`
- Data dictionary: `docs/data-definition/data-dictionary.md`
- Project summary: `docs/project.md`
