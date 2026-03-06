# Architecture

Flow is structured in three independent layers. Understanding the separation makes it easier to reason about layout bugs, performance, and extensibility.

---

## The Three Layers

```
Your screen view() functions
        │
        ▼
┌─────────────────────────┐
│   flow/flow.lua          │  ← preferred entrypoint (wires everything)
└────────────┬────────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
┌──────────┐   ┌─────────────────┐
│ ui.lua   │   │ navigation/     │
│ renderer │   │ router + GUI    │
└────┬─────┘   └─────────────────┘
     │
     ▼
┌──────────────┐
│  layout.lua  │  ← pure Lua, zero Defold dependencies
└──────────────┘
```

### Layer 1 — Layout Engine (`flow/layout.lua`)

The layout engine is a self-contained flex layout calculator. It has **no Defold dependencies** — it can run in a plain Lua environment or tests.

**Input**: a tree of nodes, each with a `style` table.
**Output**: `node.layout = { x, y, w, h }` written in-place on every node.

The coordinate system is **bottom-left origin** — `(0, 0)` is the bottom-left corner of the available area, y increases upward.

Entry point:
```lua
layout.compute(root_node, x, y, width, height)
```

### Layer 2 — Renderer (`flow/ui.lua`)

The renderer bridges layout space to Defold's GUI system. It owns:

- **Node lifecycle**: creating, reusing, and deleting Defold GUI nodes.
- **Coordinate conversion**: layout space (bottom-left) → Defold GUI space (center-origin).
- **Hit testing**: maps input coordinates back to layout-space elements.
- **Animation dispatch**: calls per-primitive animation hooks each frame.

The renderer is generic — it doesn't know about buttons, scrollbars, or popups. Primitive-specific behavior is registered by component modules in `flow/components/`.

### Layer 3 — Components (`flow/components/`)

Each component (`box`, `text`, `button`, `scroll`, `popup`, `bottom_sheet`, `icon`, `markdown`) registers itself with the renderer. Registration provides hooks like `create_node`, `apply`, `press_begin`, `on_drag_start`, `update_anim`, and more.

This means the core renderer never hardcodes scroll or button behavior — it calls registered hooks.

---

## The Rendering Pipeline

Each frame, the pipeline runs in this order:

```
1. screen.view(params, nav)       → returns a new element tree (Lua tables)
2. layout.compute(tree, ...)      → writes x/y/w/h onto every node in-place
3. apply(tree)                    → create/update Defold GUI nodes from layout
4. collect_node_keys(tree)        → build set of expected cache keys
5. delete orphaned nodes          → remove GUI nodes whose keys left the tree
6. update_anim(tree, dt)          → tick per-primitive physics/animations
```

Steps 1–5 only run when the renderer is **dirty** (window resized, `mark_dirty()` called, or a new tree is passed). Step 6 runs every frame and calls `mark_dirty()` automatically when any animation is active.

---

## Node Caching

Every element has a `key`. The renderer maintains a `nodes` table mapping `key → Defold GUI node`. On each render:

- If the key exists → reuse the node (update position, color, text).
- If the key is new → create a new Defold GUI node.
- After rendering → delete any node whose key is no longer in the tree.

**Keys must be stable and unique.** Random or time-based keys prevent reuse and cause leaks.

---

## Coordinate Systems

```
Layout space              Defold GUI space         Input space
─────────────             ────────────────         ───────────
origin: bottom-left       origin: top-left         Delivered as GUI coords
y: increases upward       nodes: center-positioned by Defold's on_input
used by: layout.lua       used by: gui.set_position
```

Conversion (layout → GUI center point):
```lua
gui_x = layout.x + layout.w / 2
gui_y = layout.y + layout.h / 2
```

Input coordinates from `on_input` go through `screen_to_layout()` before hit testing, which corrects for letterboxing.

---

## Navigation

The navigation system is stack-based and lives in `flow/navigation/`. It is separate from the renderer — the renderer renders one tree at a time; navigation decides which screen's `view()` produces that tree.

```
nav.push("screen_id", params)   → push a new screen on top
nav.pop(result_data)            → return to previous screen
nav.replace("screen_id", params) → swap current screen
nav.reset("screen_id", params)  → clear stack and start fresh
```

Navigation is a **singleton** (`flow.nav`). Screens are registered once, then referenced by string ID.

Transitions (fade, slide_left, slide_right) work by rendering both the outgoing and incoming trees simultaneously with animated `_alpha` and `_offset_x` properties applied by the renderer.

---

## Dirty Tracking

Flow avoids re-running layout every frame. A render only happens when:

- The window size changed.
- `flow.mark_dirty(self)` or `flow.nav.mark_dirty()` is called.
- A new tree instance is passed to `ui.update()`.
- An active animation marks the renderer dirty automatically.

The common pattern for state-driven UIs:

```lua
-- In a button's on_click:
on_click = function()
  params.count = params.count + 1
  flow.nav.mark_dirty()   -- schedules a re-render next frame
end
```

---

## The 512 Node Limit

Defold enforces a hard limit of **512 GUI nodes per scene**. Each `Box`, `Text`, `Button`, `Icon`, and internal scrollbar/backdrop node counts toward this limit.

For long lists, use **virtual scrolling**: render only the visible rows plus a small buffer, and use spacer boxes to represent the off-screen rows. See [Tutorial 5 — Scroll & Lists](tutorials/05-scroll-and-lists.md).

---

## File Map

```
flow/
  flow.lua              Main facade — wires all modules together
  layout.lua            Pure flex layout engine (no Defold deps)
  ui.lua                Renderer, input, animation dispatcher
  flex.lua              Optional Yoga-compatible imperative API
  types.lua             LuaLS type definitions
  log.lua               Leveled, context-aware logging
  navigation/
    init.lua            Singleton facade (flow.nav)
    core.lua            Pure router — push/pop/replace/reset
    gui.lua             GUI adapter — tree building, transitions, scroll state
    messages.lua        Message-driven navigation transport
    proxy.lua           Collection-proxy runtime helper
    runtime.lua         Non-GUI bootstrap for plain .script integration
  components/
    box.lua             Generic container
    text.lua            Text label
    button.lua          Clickable element with press state
    icon.lua            Sprite / atlas image
    scroll.lua          Scrollable container (momentum + bounce)
    popup.lua           Full-screen modal overlay
    bottom_sheet.lua    Spring-animated bottom panel
    markdown.lua        Markdown parser and viewer
```
