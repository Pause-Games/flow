# Specs

Current module reference for the Flow library.
These files are the authoritative public contract for shipped behavior.
`docs/planning/` is implementation history and design rationale only.

| File | Module | Description |
|------|--------|-------------|
| [layout.md](layout.md) | `flow/layout.lua` | Pure Lua flexbox layout engine |
| [ui.md](ui.md) | `flow/ui.lua` | Low-level renderer/input/animation engine exposed via `flow.ui` |
| [navigation.md](navigation.md) | `flow/navigation/init.lua` | App-wide navigation core exposed via `flow.nav`, with message/proxy/runtime helpers nested under the same facade |
| [flex.md](flex.md) | `flow/flex.lua` | Flex-compatible imperative API |
| [markdown.md](markdown.md) | `flow/components/markdown.lua` | Composite markdown component |
| [log.md](log.md) | `flow/log.lua` | Centralized logging and observability API |

## Architecture

```text
screens.lua or your own screen modules
    |
    v
flow/flow.lua        <- preferred entrypoint
    |
    +-- flow/log.lua
    +-- flow/navigation/init.lua
    +-- flow/navigation/messages.lua
    +-- flow/navigation/proxy.lua
    +-- flow/navigation/runtime.lua
    +-- flow/ui.lua
    +-- flow/components/*

flow/ui.lua             <- generic renderer/input/animation dispatch only
    |
    +-- flow/layout.lua
    +-- Defold GUI APIs

flow/components/*       <- primitive and composite components; primitive behavior lives here
flow/flex.lua           <- optional imperative tree builder
flow/components/markdown.lua       <- markdown parser and viewer component
```

## Rules

1. Every element needs a stable `key`.
2. Use `flow.ui.cp.*` from `require "flow/flow"` for primitive constructors.
3. Prefer `require "flow/flow"` and then use `flow.ui.*` / `flow.ui.cp.*` / `flow.nav.*` / `flow.log.*` instead of split imports.
4. Use `flow.init/flow.update/flow.on_input/flow.on_message` unless you explicitly need the low-level renderer API.
5. Call `flow.nav.mark_dirty()` or `flow.mark_dirty(self)` after mutating screen state that affects the active view tree.
6. Popup and bottom-sheet content still need explicit heights.
7. Use `flow.log.*` for runtime observability instead of adding `print()` calls inside library code.
8. `flow.nav` is app-wide singleton navigation; `flow.ui` state is per-`self` renderer state.
9. If you bypass `flow/flow.lua` and import navigation directly, use `require "flow/navigation/init"`.
