###############################################################################
# 🧠 Codex Agent Workspace – Tooling Contract & Guide
# Godot 4.4.1 · Headless · CI-safe · .NET 8 SDK + Godot-mono included
###############################################################################

## Agent Behavior & Operating Mode

**CODING AGENT BEHAVIOR:** VERBOSE · STEPWISE · SAFE · LINT-COMPLIANT
Always start responses with `[DEVELOPER]:`.
Agents operating in this workspace must:
- Maximize reasoning time and provide detailed explanations
- Work step-by-step through complex tasks
- Follow all validation and lint requirements
- Communicate progress and decisions clearly

**PULL REQUEST POLICY:**
- NO BINARIES – binary files may not be added, staged, or committed
- NO AUTOCOMPLETE – only confirmed, validated code
- ONLY VERIFIED – all code must pass validation before commit

**VARIABLE NAMING CONVENTION:**
- Format: `<scriptPrefix>_<name>_<ownerFn>`
- Style: lowercase_snake_case
- Be consistent within each file

**TYPE ANNOTATIONS:** Do not rely on inferred types in code. Always declare explicit types for variables and callables in GDScript and other typed contexts.

**TASK SEQUENCE RULE:**
Foundation first → utilities → scenes → features

**COMMIT MESSAGE STYLE:**
Conventional Commits format (e.g., `fix(boids): stabilize swim`, `feat(ai): add pathfinding`)

**BUG & ERROR POLICY:**
1. Validate scripts → detect errors → fix → revalidate → repeat
2. Only commit when zero errors exist
3. Warnings may pass unless CI blocks them
4. NO bypassing errors via `.gdignore`, fake returns, or suppression
5. Placeholders and minimal stubs allowed only for tracked, planned features
6. Placeholders must NOT hide script-validation failures

───────────────────────────────────────────────────────────────────────────

## Project Context & Documentation

[!NOTE]
Before beginning work, review:
- `docs/project.md` for concise, AI-focused project context and design intent
- Directory `README.md` files for module-specific documentation
- `TODO.md`, `CHANGE_LOG.md`, `STYLE_GUIDE.md`, `VARIABLE_NAMING.md` in project root

───────────────────────────────────────────────────────────────────────────

## Core Requirements

[!IMPORTANT]
**Indentation:** Always 4 spaces in `.gd`, `.gdshader`, `.cs`. Never use tabs.

[!IMPORTANT]
**Class order:** `gdlint` expects `class_name` **before** `extends`.

[!IMPORTANT]
**Binary files:** Your tools might let you create a PR that includes a binary file,
but the user will be unable to merge it. **All PRs must exclude binary files.**

[!IMPORTANT]
**Error handling:** You are NOT allowed to use `.gdignore` to silence errors.
**Fix them correctly** instead.

[!IMPORTANT]
**Folder restrictions:** Respect folders listed in `.codexignore`. These folders
are closed for editing. You may read but not alter files in those folders.

───────────────────────────────────────────────────────────────────────────

## Section: First-Time Setup

1. **Use the built-in Godot CLI**: `/usr/local/bin/godot` (default in this image).
   To override, export `GODOT=/full/path/to/godot`.

2. **Import pass** – warm caches & create `global_script_class_cache.cfg`:

   ```bash
   godot --headless --editor --import --quit --path . --verbose
   ```

3. **Parse all GDScript**:

   ```bash
   godot --headless --check-only --quit --path . --verbose
   ```

4. **Build C#/Mono** (optional – auto-skips if no `*.sln` exists):

   ```bash
   dotnet build --nologo > /tmp/dotnet_build.log
   tail -n 20 /tmp/dotnet_build.log
   ```

   - **Exit 0** ⇒ project is clean
   - **Non-zero** ⇒ inspect error lines and fix

**Repeat steps 2-4 after every edit until all return 0.**

For stubborn errors, increase verbosity:

```bash
dotnet build --verbosity diagnostic
godot --headless --check-only --quit --path . --verbose
```

───────────────────────────────────────────────────────────────────────────

## Section: Patch Hygiene & Format

```bash
# Auto-format changed .gd files
.codex/fix_indent.sh $(git diff --name-only --cached -- '*.gd') >/dev/null

# Report lint warnings (non-blocking)
gdlint $(git diff --name-only --cached -- '*.gd') || true

# C# style check (optional – fail on real violations only)
dotnet format --verify-no-changes --nologo --severity hidden || {
  echo '🛑 C# style violations'; exit 1;
}
```

**Pre-Commit Requirements:**
- No tabs in code files
- No syntax errors
- No style violations
- Binary files may not be staged or committed
- Review and update project documentation as needed:
  - `TODO.md` – track planned work
  - `CHANGE_LOG.md` – document changes
  - `STYLE_GUIDE.md` – maintain conventions
  - `VARIABLE_NAMING.md` – naming patterns
  - `README.md` – project overview

───────────────────────────────────────────────────────────────────────────

## Section: Validation Loop (CI)

```bash
# CI validates quietly and only emits errors
godot --headless --editor --import --quit --path . --quiet
godot --headless --check-only --quit --path . --quiet
dotnet build --no-restore --nologo  # optional if .NET present
```

**Optional tests:**

```bash
# GDScript tests
godot --headless -s res://tests/ --quiet || true

# C# tests (optional)
dotnet test --logger "console;verbosity=quiet" || true

# Other language tests (if present)
cargo test || true
go test ./... || true
bun test || true
```

───────────────────────────────────────────────────────────────────────────

## Section: Quick Checklist

```text
apply_patch
├─ gdformat --use-spaces=4 <changed.gd>
├─ gdlint   <changed.gd>     (non-blocking)
├─ godot  --headless --editor --import --quit --path . --quiet
├─ godot  --headless --check-only      --quit --path . --quiet
└─ dotnet build --no-restore --nologo  (optional)
```

**Exit 0 ⇒ ✔ commit**  
**Non-zero ⇒ ✘ fix & rerun**

───────────────────────────────────────────────────────────────────────────

## Section: Why This Matters

- `--import` is the **only** way to build Godot's script-class cache
- CI skips the import when no `main_scene` is set, so fresh repos won't fail
- `--check-only` finds GDScript errors; `dotnet build` compiles C#
- Together, these guarantee the project builds headlessly on any clean machine

**Efficiency note:** You don't need to run .NET and Godot verify commands if you
haven't changed any `.gd`/`.cs` files or their dependencies; pre-commit hooks
will catch issues automatically.

───────────────────────────────────────────────────────────────────────────

## Addendum: Build-Plan Rule Set

1. **Foundation first** – build scaffolding (data models, interfaces, utils)
   before high-level features. CI fails fast if missing.

2. **Design principles** – data-driven, modular, extensible, compartmentalized.
   Follow each language's canonical formatter:
   - Python: PEP 8
   - Rust: rustfmt
   - Go: go fmt
   - GDScript: gdformat
   - C#: dotnet format

3. **Indentation** – spaces-only except in languages that **require** tabs
   (e.g., `Makefile`). Keep tabs localized to that file type.

4. **Header comment block** – for files that support comments, prepend:

   ```text
   ###############################################################
   # <file path>
   # Key Classes      • Foo – does something important
   # Key Functions    • bar() – handles a critical step
   # Critical Consts  • BAZ – tuning value
   # Editor Exports   • bum: float – Range(0.0 .. 1.0)
   # Dependencies     • foo_bar.gd, utils/foo.gd
   # Last Major Rev   • YY-MM-DD – overhauled bar() for clarity
   ###############################################################
   ```

   Skip for formats with no comments (JSON, minified assets).

5. **Language-specific tests** – run appropriate test commands when present:
   - `cargo test` for Rust
   - `go test ./...` for Go
   - `bun test` for TypeScript/JavaScript
   - `dotnet test` for C#
   - `godot --headless -s res://tests/` for GDScript

───────────────────────────────────────────────────────────────────────────

## Addendum: gdlint Class-Order Warnings

`gdlint` 4.x enforces **class-definitions-order**:
tool → `class_name` → `extends` → signals → enums → consts → exports → vars

If warnings become noisy:
- Re-order clauses to match the list, **or**
- Suppress in file: `# gdlint:ignore = class-definitions-order`, **or**
- Customize via `.gdlintrc`, **or**
- Pin `gdtoolkit==4.0.1`

CI runs gdlint **non-blocking**; treat warnings as advice until you decide to
enforce them strictly.

───────────────────────────────────────────────────────────────────────────

###############################################################################
# End of Codex Agent Workspace Guide
###############################################################################
