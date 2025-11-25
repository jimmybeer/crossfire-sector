# Technology Stack

## Chosen Stack

[ARCHITECT]: Zero-cost, actively maintained, cross-platform 3D stack optimized for rapid iteration, deterministic logic, and AI-assisted development.

- **Game Engine:** Godot 4.x (MIT). Cross-platform exporter for Windows/macOS/Linux/iOS/Android, modern 3D renderer (Forward+/Mobile), physics (Godot Physics), animation/state machines, scene graph, and editor tooling with predictable `.tscn`/`.tres` text assets.
- **UI Framework:** Godot Control/Theme system with reusable scenes; supports responsive layouts, localization, accessibility hooks, and minimal lock-in via open text resources and scripted widgets.
- **Persistence Layer:** Local saves via Godot `FileAccess` + JSON/ConfigFile + optional gzip compression; future backend via open-source PostgreSQL with Supabase/PostgREST compatibility for zero-cost self-hosting and easy schema migration.
- **Logging System:** Godot built-in logging (`print_rich`, `push_error`, per-category `Logger` autoload) writing to rotating text logs for replay/debug; integrates with editor debugger and CI-friendly plain text.
- **Future Networking Layer:** Godot Multiplayer API (ENet/UDP + WebSocket) supporting authoritative server or lockstep with determinism helpers; compatible with Nakama or open-source ENet servers when scaling.

<!-- AI SHOULD IGNORE ALL CONTENT BELOW THIS LINE -->
## Trade-offs and Evaluated Options
[ARCHITECT]: Summary of alternatives and rationale for the chosen stack.

- **Godot vs Unity/Unreal:** Unity’s licensing/runtime fees and package lock-in violate zero-cost/low-lock-in goals; Unreal’s footprint and C++-heavy workflow slow iteration for small teams. Godot remains fully open-source, lightweight, and scriptable while maintaining active releases and mobile exporters.
- **Godot vs Bevy/MonoGame/Stride:** Bevy (Rust) is promising but still maturing (ecosystem and tooling gaps for mobile). MonoGame lacks modern 3D/editor pipelines. Stride is strong for C# but smaller community and fewer mobile proofs. Godot provides a larger ecosystem, mature editor, scene tooling, and predictable text assets ideal for AI agents.
- **UI Alternatives:** Dear ImGui and web-based UIs (React/Flutter) add integration overhead for mobile/console exports; Godot’s Control nodes keep a single pipeline with themeable widgets and hot-reloadable scenes.
- **Persistence Alternatives:** Pure SQLite is solid for local, but JSON-based saves align with Godot’s hot-reload workflow and human-readable diffs; PostgreSQL/Supabase compatibility keeps a migration path for cloud features without vendor lock-in or costs.
- **Networking Alternatives:** Mirror/Photon or PlayFab add costs and proprietary SDKs; Godot’s built-in ENet/WebSocket stack supports deterministic turn-based loops and later server authority without licensing friction.
- **Web-Based Stack Assessment (Babylon.js/TypeScript + React + Supabase + Colyseus/Socket.IO):**
  - **Strengths:** Zero-cost OSS, runs in browsers with PWA support for desktop/mobile; TypeScript + modular NPM ecosystem aid AI tooling; WebGL2/WebGPU roadmaps cover 3D; React/JSX + scene graph bindings (React Three Fiber-style patterns) keep UI/component structure predictable; JSON/SQL backends (Supabase/Postgres) remain open; Colyseus/Socket.IO enable deterministic/authoritative patterns.
  - **Weaknesses:** Mobile/native performance and battery may trail engine-level renderers; asset pipelines (import, animation, physics) and editor tooling less integrated than Godot; offline persistence and filesystem access more constrained in browsers; more glue code to meet AQ-001/AQ-007 separation and CP-006 efficiency goals.
  - **Fit vs Godot Choice:** Satisfies zero-cost and cross-platform via web/PWA, but weaker turnkey 3D/editor tooling, physics importers, and offline save ergonomics; Godot remains preferred for richer 3D pipelines, deterministic scene assets, and unified export targets while keeping browser builds viable via Godot HTML5 exporter if needed.
