# ui.lua — Renderer Engine

Bridges the layout engine to Defold's GUI system. Owns generic node lifecycle, coordinate conversion, hit-test traversal, input dispatch, and animation dispatch.

`ui` is the renderer/input engine only. Primitive constructors are exposed via `flow.ui.cp.*`, and `flow/flow.lua` is the preferred high-level entrypoint.

Primitive-specific behavior is declared by the primitive module that registers the type. Core traverses the tree and calls the registered hooks; it does not hardcode scroll, button, popup, or bottom-sheet behavior.

For normal app code, prefer the top-level lifecycle facade:

```lua
local flow = require "flow/flow"

function init(self)
  flow.init(self, { screens = SCREENS, initial_screen = "home" })
end

function update(self, dt)
  return flow.update(self, dt)
end

function on_input(self, action_id, action)
  return flow.on_input(self, action_id, action)
end

function on_message(self, message_id, message, sender)
  return flow.on_message(self, message_id, message, sender)
end
```

---

## Setup

```lua
local flow = require "flow/flow"

function init(self)
  msg.post(".", "acquire_input_focus")
  flow.ui.mount(self, { debug = false }) -- initialise renderer state
end
```

### `ui.mount(self, opts?)`

Initialises `self.ui` state. Must be called once in `init()` before any other `ui.*` call.

`opts.debug` is optional and defaults to `false`.

`debug` does not print directly. It enables detailed `flow.log` output from the `ui.input` context.

```lua
self.ui = {
  nodes         = {},    -- cache: key → Defold GUI node
  tree          = nil,   -- last rendered tree
  _needs_redraw = true,
  _scroll_changed = false,
  debug         = false,
}
```

---

## Layout Mode

Public rendering is always done in logical GUI space.

```lua
flow.ui.mount(self)  -- GUI-space layout is the default and intended mode
```

An internal escape hatch remains for edge cases:

```lua
flow.ui._set_layout_space_unsafe(self, "window")
```

This is intentionally not part of the public API.

## Colour Values

Flow colour props use `ColorValue`, not Defold `vmath.vector4`.

Supported formats:

- hex strings such as `"#778899"` and `"#778899cc"`
- CSS-like strings such as `"rgb(119, 136, 153)"` and `"rgba(119, 136, 153, 0.5)"`
- helper values from `flow.color.rgb(...)`, `flow.color.rgba(...)`, and `flow.color.hex(...)`
- plain Lua tables such as `{ 119, 136, 153, 255 }` or `{ r = 119, g = 136, b = 153, a = 255 }`

## Logging

Runtime observability is exposed through `flow.log`.

Relevant UI contexts:

- `ui`
- `ui.input`
- `ui.renderer`
- `ui.scroll`

Example:

```lua
local flow = require "flow/flow"

flow.log.set_level("warn")
flow.log.set_context_level("ui.input", "debug")
```

---

## Widgets

Widget constructors no longer live on `ui`. Import them from `flow/components/*` or use the re-exports from `flow/flow`.

Examples:

```lua
local flow = require "flow/flow"
local Box = flow.ui.cp.Box
local Text = flow.ui.cp.Text
local Button = flow.ui.cp.Button
local ButtonImage = flow.ui.cp.ButtonImage
```

The remaining sections describe the primitive element shapes that the renderer understands.

### Primitive Registration

Advanced usage only:

```lua
flow.ui.register("my_type", {
  create_node = function(el) ... end,
})
```

Built-in primitives register themselves from `flow/components/*`.

Common optional hooks/flags on a primitive def:

| Field | Purpose |
|-------|---------|
| `apply(self, el, node, alpha)` | Extra per-frame node updates |
| `is_visible(el)` | Runtime visibility gating for render and key collection |
| `is_hittable(el)` | Runtime visibility gating for hit testing |
| `is_scroll_container` | Marks a primitive as a scroll ancestor |
| `clips_children` | Children are parented under this node for clipping |
| `capture_descendant_hits` | Returns the parent instead of a deeper child hit |
| `is_backdrop_click_target` | Allows backdrop press handling |
| `on_wheel(self, el, delta, deps)` | Mouse-wheel handling |
| `on_drag_start/on_drag_move/on_drag_end` | Drag interaction hooks |
| `press_begin/press_update/press_end` | Button-like press handling |
| `update_anim(el, dt, deps)` | Per-frame animation tick |
| `render_extras(self, el, prefix, alpha, deps)` | Extra nodes such as scrollbars |
| `collect_extra_keys(el, prefix, keys, deps)` | Cache-key collection for extra nodes |
| `get_child_extra_offset_y(el)` | Applies child offset during render |

### `box` primitive

Generic container. Renders as a Defold box node.

| Field      | Type            | Description               |
|------------|-----------------|---------------------------|
| `key`      | string          | **Required.** Unique stable identifier for node caching |
| `style`    | table           | Layout properties (see `layout.md`) |
| `color`    | ColorValue      | Fill colour. Accepts CSS-like strings or plain Lua colour tables |
| `children` | table           | Ordered list of child elements |

### `text` primitive

Text label. Renders as a Defold text node using the `.gui` font named by `font`, or `"default"` when `font` is omitted.

| Field   | Type    | Description                                              |
|---------|---------|----------------------------------------------------------|
| `key`   | string  | Required                                                 |
| `text`  | string  | Text content. Updated every frame via `gui.set_text()`  |
| `style` | table   | `width`, `height`, `flex_grow`, etc.                    |
| `color` | ColorValue | Text colour                                           |
| `align` | string  | `"left"` (default), `"center"`, `"right"`               |
| `font`  | string  | GUI font name registered in the `.gui` file. Defaults to `"default"` |

**Important**: Text nodes have 0 layout width unless you provide `width` or `flex_grow`. Center/end alignment on a text node only works when it is the sole child of an explicit-width parent, or when the text itself has a width.

### `icon` primitive

Box node with a texture atlas animation. The atlas must be registered in the `.gui` file.

| Field     | Type   | Description                                         |
|-----------|--------|-----------------------------------------------------|
| `key`     | string | Required                                            |
| `image`   | string | Animation ID within the atlas (e.g. `"icon_star"`) |
| `texture` | string | Atlas name as declared in `.gui` (default `"icons"`) |
| `style`   | table  | `width`, `height`                                   |

### `button` primitive

Clickable element. Internally a box node with press-state tracking.

| Field           | Type     | Description                                       |
|-----------------|----------|---------------------------------------------------|
| `key`           | string   | Required                                          |
| `style`         | table    | Layout properties                                 |
| `color`         | ColorValue  | Normal colour                                  |
| `pressed_color` | ColorValue  | Colour while pressed (defaults to 70% of `color`) |
| `image`         | string   | Optional atlas animation id for an image-backed button background |
| `texture`       | string   | GUI texture name for `image` (default `"icons"`) |
| `border`        | number or table | Optional slice-9 inset for image-backed buttons |
| `on_click`      | function | `function(btn)` — called on release over the button |
| `children`      | table    | Visual children (e.g. text label, icon)          |

`button` remains the main interactive primitive. Setting `image` turns the background into a textured box node while keeping the same button input behavior and pressed-state visuals.

When pointer-move events are available, `button` also supports hover enter/leave visuals by scaling the node up slightly while hovered.

`border` maps to `gui.set_slice9(...)`. It accepts:

- a single number for uniform insets
- `{ left, top, right, bottom }` for explicit per-edge values

For rounded or curved button backgrounds, add horizontal padding in `style` such as `padding_left` / `padding_right` so labels and icons do not sit against the sliced corners.

### `button_image` convenience constructor

Preferred access:

```lua
local flow = require "flow/flow"
local ButtonImage = flow.ui.cp.ButtonImage
```

`ButtonImage(opts)` is a thin wrapper over `button`:

- `image` is required
- `texture` defaults to `"icons"`
- `color` defaults to white so the texture is not tinted unintentionally

Use `ButtonImage` when the image itself is the button. Use `Button` with `image` and `border` when you want a shaped button background behind labels or icons.

### `scroll` primitive

Scrollable container. Clips children using Defold stencil clipping. Supports vertical and horizontal scrolling.

| Field             | Type    | Default | Description                                      |
|-------------------|---------|---------|--------------------------------------------------|
| `key`             | string  | —       | Required                                         |
| `style`           | table   | —       | `flex_direction = "row"` makes it horizontal     |
| `children`        | table   | —       | Scrollable content                               |
| `_scrollbar`      | bool    | `true`  | Show/hide the scrollbar indicator                |
| `_bounce`         | bool    | `true`  | Enable rubber-banding and spring-back            |
| `_momentum`       | bool    | `true`  | Enable inertial scrolling after drag release     |
| `_virtual_height` | number  | —       | Declares total virtual content height (vertical) |
| `_virtual_width`  | number  | —       | Declares total virtual content width (horizontal)|

**Scroll direction**: determined by `style.flex_direction`. `"row"` → horizontal; anything else → vertical.

**Mouse wheel**: 50 px per notch. Hard-clamped (no bounce).

**Drag**: `touch` action drag. Rubber-band resistance (0.3) when beyond bounds.

**Momentum**: Released with velocity > 100 px/s triggers momentum. Deceleration 1500 px/s² in-bounds, 5000 px/s² out-of-bounds.

**Bounce-back spring**: stiffness = 1200, damping = 35. Stops when within 1 px and velocity < 10 px/s.

**Scrollbar**: 6 px wide (vertical) or 6 px tall (horizontal). Thumb size proportional to `container / content`. Hidden when content fits.

**Virtual scrolling contract**:

- `_virtual_height` / `_virtual_width` define the logical content extent
- the tree should render only the currently visible rows plus a small buffer
- rows outside the render window should be replaced by spacer boxes
- when scroll state changes, the renderer sets `_scroll_changed`
- the higher-level flow integration persists scroll state and regenerates the active screen view on the next update

This is what allows large lists without exhausting the GUI node budget.

### `popup` primitive

Full-screen modal overlay. Does not participate in flex layout — always receives full parent bounds.

| Field              | Type     | Default                   | Description                               |
|--------------------|----------|---------------------------|-------------------------------------------|
| `key`              | string   | —                         | Required                                  |
| `style`            | table    | —                         | Controls how children are positioned within the full-screen area |
| `backdrop_color`   | ColorValue  | `"rgba(0, 0, 0, 0.7)"` | Backdrop fill colour                   |
| `_visible`         | bool     | `true`                    | When `false`, no nodes are created        |
| `on_backdrop_click`| function | —                         | Called when user taps the backdrop node   |
| `children`         | table    | —                         | Dialog content                            |

**Overlay layout patterns**:
- Centred dialog: `align_items="center", justify_content="center"`
- Top-anchored panel: `align_items="stretch", justify_content="start"`
- Bottom-anchored panel: `align_items="stretch", justify_content="end"`

**Important**: Child content boxes must have an explicit `height`. Auto/intrinsic heights are not supported.

### `bottom_sheet` primitive

Full-screen overlay anchored to the bottom. Two operating modes:

**Legacy mode** (`_open` not set): `_visible` toggles node creation on/off. No animation.

**Animated mode** (`_open = true/false`): Nodes always present. Spring animation drives a vertical slide offset (`_anim_y`). Backdrop fades proportionally.

| Field              | Type     | Default        | Description                                           |
|--------------------|----------|----------------|-------------------------------------------------------|
| `key`              | string   | —              | Required                                              |
| `backdrop_color`   | ColorValue  | `"rgba(0, 0, 0, 0.5)"` | Backdrop colour                                |
| `_visible`         | bool     | `true`         | Legacy mode visibility                                |
| `_open`            | bool     | —              | Animated mode: `true` = slide open, `false` = close  |
| `_on_anim_update`  | function | —              | `function(anim_y, velocity)` — called each animation tick so state survives tree regeneration |
| `on_backdrop_click`| function | —              | Called on backdrop tap                                |
| `children`         | table    | —              | Sheet content                                         |

Default style: `justify_content = "end"`, `align_items = "center"`.

Spring constants: stiffness = 600, damping = 28. Overshoot clamped to ±30 px.

---

## Rendering

### `ui.render(self, tree, w, h)`

Full render: computes layout and applies all nodes. Called automatically by `ui.update()`.

- Calls `layout.compute(tree, 0, 0, w, h)`.
- Calls `apply()` recursively to create/update Defold GUI nodes.
- Deletes GUI nodes whose keys are no longer in the tree (supports virtual scrolling).
- In `"window"` layout space, applies `_scale_x/_scale_y` to node positions and sizes.

### `ui.update(self, tree)`

Redraw-gating wrapper around `render`. Re-renders only when:
- A new tree is passed.
- Window size has changed.
- `self.ui._needs_redraw` is `true`.
- `tree._needs_redraw` is `true`.

Use this in the `update()` loop instead of calling `render()` manually.

In high-level flow integration, `flow.update()` also:

- advances primitive animations
- handles `_scroll_changed`
- rebuilds the active navigation tree when scroll state, transitions, or data changes require it

### `ui.request_redraw(self)`

Forces a re-render on the next `update()` call.

---

## Node Caching

Each element is identified by a **cache key** = `(node_prefix or "") .. element.key`.

When `ensure()` is called for a key that already exists, the existing Defold GUI node is returned and reused (position/size/colour are updated). New GUI nodes are created only for keys not yet seen.

**Stable keys are required.** Using random or time-based keys defeats caching and causes node leaks.

This matters especially for virtual scrolling, transition snapshots, and markdown-generated trees.

---

## Node Cleanup

After each render, `collect_node_keys()` walks the new tree to build the set of expected keys. Any cached key **not** in this set has its GUI node deleted and the cache entry removed. This is the mechanism that enables virtual scrolling without hitting the 512-node limit.

---

## Coordinate Systems

```
Layout space (bottom-left origin)
  (0,0) = bottom-left of screen
  y increases upward

Defold GUI space (center origin)
  Nodes are positioned at their center point
  y increases upward

Input space
  Delivered by Defold in GUI coordinates
  Scaled by screen_to_layout() before hit testing
```

### `screen_to_layout(self, x, y)`

Corrects Defold's input coordinates for letterboxing:

1. Convert GUI coords → window coords: `wx = x * ww/gw`
2. Compute letterbox offsets for the current aspect ratio.
3. Correct for letterbox: `cx = (wx - offset_x) * gw / visible_w`
4. In unsafe window-layout mode only, convert corrected GUI → window: `return cx * ww/gw, cy * wh/gh`
5. In normal public mode, return corrected GUI coords directly.

---

## Input Handling

### `ui.on_input(self, action_id, action)`

Returns `true` if the event was consumed.

`ui` does generic routing only. Primitive-specific behavior such as button press visuals, scroll dragging, wheel scrolling, and backdrop taps is implemented by the registered primitive defs.

**Action IDs handled**:
- `hash("scroll_up")` / `hash("scroll_down")`: mouse wheel scroll on hovered scroll container.
- `hash("touch")`: tap / drag.
- `action_id == nil` with mouse coordinates: Defold desktop mouse-move callback used for hover updates on hoverable elements such as buttons. No extra input-binding action is required.

**Touch priority** (on `action.pressed`):
1. Primitive with `press_begin` under cursor.
2. Primitive with `is_backdrop_click_target` and `on_backdrop_click`.
3. Scroll-ancestor primitive with `on_drag_start`.

**Drag**: While a drag target is active, move/release events are routed back to that primitive's drag hooks.

**Press release**: If released over the same pressed element, the primitive's `press_end` hook receives `activated = true`.

---

## Animation

### `ui.update_animations(self, dt)`

Must be called every frame in `update(self, dt)`. Traverses the tree and calls each primitive's optional `update_anim(el, dt, deps)` hook.

Built-in examples:

- `scroll` owns momentum and bounce-back physics.
- `bottom_sheet` owns its slide animation.

Calls `ui.request_redraw(self)` whenever any animation is active, triggering a re-render.

---

## Hit Testing

### `ui.hit_test(self, x, y)`

Returns the deepest interactive element at `(x, y)`, or `nil`.

- Converts input coordinates through `screen_to_layout()`.
- Walks tree depth-first, children checked in reverse order (last child = topmost).
- Scroll offsets are accumulated through primitives registered with `is_scroll_container`.
- Uses each primitive's `is_hittable(el)` hook when present.
- If a child hit is inside a primitive with `capture_descendant_hits`, the parent is returned instead.

---

## Debug Mode

```lua
ui.set_debug(self, true)
```

When enabled, emits `flow.log` debug entries on each `action.pressed`:
- Input coordinates in GUI space and layout space.
- Window size, GUI size, scale factors.
- Hit element key and its layout bounds.

Debug mode is stored on `self.ui` and is not shared across `.gui_script` instances.

---

## Utility

| Function                         | Description                                               |
|----------------------------------|-----------------------------------------------------------|
| `ui.get_size()`                  | Returns logical GUI size `(w, h)` from `game.project`    |
| `ui.request_redraw(self)`        | Requests a full redraw on the next `update()` call       |
| `ui.request_tree_redraw(tree)`   | Sets `tree._needs_redraw = true` (alternative to `request_redraw`) |
| `ui.render_if_size_changed(self, tree)` | Renders only if GUI size has changed since last render |
