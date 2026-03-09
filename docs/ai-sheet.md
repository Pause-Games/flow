# Flow — AI Reference Sheet

> **Purpose:** Single-source reference for AI agents working with the Flow UI library.
> Covers architecture, every public API, type signatures, constants, component specs, navigation, layout algorithm, and usage patterns.

---

## 1. What Is Flow

Flow is a **pure-Lua, CSS Flexbox-inspired UI framework** for the [Defold](https://defold.com) game engine. It provides declarative UI trees, a flexbox layout engine, a renderer that bridges to Defold GUI nodes, stack-based navigation, scrolling, overlays, markdown rendering, and centralized logging — all without native extensions.

- **Language:** Lua 5.1 (Defold runtime)
- **No external dependencies** — distributed as a Defold library dependency
- **Coordinate system:** Bottom-left origin (0,0 at bottom-left, Y increases upward)

---

## 2. Project Structure

```
flow/
├── flow/                        # Library source
│   ├── flow.lua                 # Main facade (preferred entrypoint)
│   ├── ui.lua                   # Renderer, input dispatcher, animation engine
│   ├── layout.lua               # Pure flexbox layout computation (no Defold deps)
│   ├── flex.lua                 # Yoga-compatible imperative node-builder API
│   ├── color.lua                # Color parsing & conversion
│   ├── log.lua                  # Centralized leveled logging
│   ├── types.lua                # EmmyLua / LuaLS type annotations (not runtime)
│   ├── bottom_sheet.lua         # Bottom sheet facade (re-exports bottom_sheet/)
│   ├── ui/
│   │   ├── renderer.lua         # Core render loop (layout → Defold GUI nodes)
│   │   ├── animation.lua        # Per-frame animation ticker
│   │   └── input.lua            # Input routing (touch, scroll, hover)
│   ├── navigation/
│   │   ├── init.lua             # Singleton navigation facade
│   │   ├── core.lua             # Pure stack-based router (no Defold deps)
│   │   ├── gui.lua              # GUI adapter (transitions, scroll state)
│   │   ├── messages.lua         # Message-based navigation API
│   │   ├── proxy.lua            # Collection proxy manager
│   │   └── runtime.lua          # Non-GUI navigation bootstrap
│   ├── components/
│   │   ├── box.lua              # Rectangle container
│   │   ├── text.lua             # Text label
│   │   ├── button.lua           # Interactive button
│   │   ├── button_image.lua     # Image button convenience wrapper
│   │   ├── icon.lua             # Atlas icon display
│   │   ├── scroll.lua           # Scrollable container
│   │   ├── popup.lua            # Modal overlay
│   │   └── markdown.lua         # Markdown parser & viewer
│   └── bottom_sheet/
│       ├── init.lua             # Bottom sheet public module
│       ├── host.lua             # Hosted bottom sheet runtime
│       └── component.lua        # Bottom sheet visual element
├── sample/                      # Sample app with 16 demo screens
├── tests/
│   ├── smoke.lua                # 28 unit tests
│   └── perf_probe.lua           # Performance benchmark
├── specs/                       # Detailed API specification docs
├── docs/                        # Tutorials and guides
└── game.project                 # Defold project config (960×640, high_dpi)
```

---

## 3. Installation & Minimal Setup

### game.project dependency

```ini
[project]
dependencies#0 = https://github.com/Pause-Games/flow/archive/refs/heads/main.zip
```

### Required input bindings

| Action ID      | Input              |
|----------------|--------------------|
| `touch`        | Mouse Button 1     |
| `scroll_up`    | Mouse Wheel Up     |
| `scroll_down`  | Mouse Wheel Down   |

### Minimal GUI script

```lua
local flow = require "flow/flow"

local SCREENS = {
  home = { view = function(params, nav) return flow.ui.cp.Box({ key = "root", style = { width = 960, height = 640 }, children = { flow.ui.cp.Text({ key = "title", text = "Hello", style = { height = 40 } }) } }) end },
}

function init(self)
  flow.init(self, { screens = SCREENS, initial_screen = "home" })
end

function final(self) flow.final(self) end
function update(self, dt) flow.update(self, dt) end
function on_input(self, action_id, action) return flow.on_input(self, action_id, action) end
function on_message(self, message_id, message, sender) return flow.on_message(self, message_id, message, sender) end
```

---

## 4. Module Exports (via `require "flow/flow"`)

```lua
local flow = require "flow/flow"

-- Facade lifecycle
flow.init(self, config?)          -- → Flow.FlowState
flow.final(self)
flow.set_tree(self, tree)         -- → Flow.Element (static UI, no navigation)
flow.invalidate(self)
flow.update(self, dt)             -- → boolean
flow.on_input(self, action_id, action) -- → boolean
flow.on_message(self, message_id, message?, sender?) -- → boolean

-- Navigation shortcuts (delegate to flow.nav)
flow.push(self, id, params?, options?)
flow.pop(self, result_or_transition?, options?)
flow.replace(self, id, params?, options?)
flow.reset(self, id, params?, options?)
flow.get_scroll_offset(self, key) -- → number

-- Sub-modules
flow.ui           -- Renderer, input, animation, component registry
flow.nav          -- Navigation singleton
flow.bottom_sheet -- Bottom sheet API
flow.log          -- Logging
flow.color        -- Color parsing
```

### Component constructors

```lua
local Box         = flow.ui.cp.Box
local Text        = flow.ui.cp.Text
local Button      = flow.ui.cp.Button
local ButtonImage = flow.ui.cp.ButtonImage
local Icon        = flow.ui.cp.Icon
local Scroll      = flow.ui.cp.Scroll
local Popup       = flow.ui.cp.Popup
local Markdown    = flow.ui.cp.Markdown
local BottomSheet = flow.ui.cp.BottomSheet
```

---

## 5. Element Structure

Every UI node is a plain Lua table:

```lua
{
  key      = "unique_stable_id",   -- REQUIRED, must be unique among siblings
  type     = "box",                -- Primitive type name
  style    = { ... },              -- Flexbox style properties
  color    = "#rrggbb",            -- Optional color string
  children = { ... },              -- Optional child elements
  layout   = { x, y, w, h },      -- Written by layout engine (read-only)
  -- ... type-specific fields
}
```

### Key rules

- Every element **must** have a unique, stable `key`
- Good: `"item_" .. index`, `"user_" .. user.id`
- Bad: `"item_" .. math.random()` → leaks GUI nodes every frame

---

## 6. Style Properties (Flexbox)

| Property           | Type                  | Default     | Description                                          |
|--------------------|-----------------------|-------------|------------------------------------------------------|
| `width`            | `number \| string`    | 0           | Pixels or `"50%"` of parent inner width              |
| `height`           | `number \| string`    | 0           | Pixels or `"50%"` of parent inner height             |
| `flex_direction`   | `"column" \| "row"`   | `"column"`  | Main axis direction                                  |
| `flex_grow`        | `number`              | 0           | Proportion of remaining free space                   |
| `justify_content`  | `string`              | `"start"`   | Main-axis alignment (see values below)               |
| `align_items`      | `string`              | `"stretch"` | Cross-axis alignment for children                    |
| `align_self`       | `string`              | —           | Per-child override of parent's `align_items`         |
| `gap`              | `number`              | 0           | Pixels between children (not before first/after last)|
| `padding`          | `number`              | 0           | Uniform padding all sides                            |
| `padding_left`     | `number`              | —           | Left padding (overrides `padding`)                   |
| `padding_right`    | `number`              | —           | Right padding                                        |
| `padding_top`      | `number`              | —           | Top padding                                          |
| `padding_bottom`   | `number`              | —           | Bottom padding                                       |

### `justify_content` values

| Value              | Behavior                                              |
|--------------------|-------------------------------------------------------|
| `"start"`          | Pack children at start (default)                      |
| `"end"`            | Pack children at end                                  |
| `"center"`         | Center children                                       |
| `"space-between"`  | Equal space between, none at edges                    |
| `"space-around"`   | Equal space around each child (half at edges)         |
| `"space-evenly"`   | Equal space between all, including edges              |

### `align_items` / `align_self` values

| Value       | Behavior                                                    |
|-------------|-------------------------------------------------------------|
| `"start"`   | Align to cross-axis start                                   |
| `"center"`  | Center on cross-axis                                        |
| `"end"`     | Align to cross-axis end                                     |
| `"stretch"` | Stretch to fill cross-axis (default for `align_items`)      |

### Important constraints

- **No auto/intrinsic height** — elements without explicit `height` and without `flex_grow` get height **0** (invisible)
- **No wrapping** — single line only, no `flex_wrap`
- **No margins** — use `gap` or `padding` instead
- **No min/max enforcement** — parsed but not applied
- **Percentages** resolve against immediate parent's inner dimension only

---

## 7. Components API

### 7.1 Box

Basic rectangular flex container.

```lua
Box({
  key      = "container",
  color    = "#334455",            -- optional solid background
  style    = { width = 300, height = 200, flex_direction = "row", gap = 10 },
  children = { ... },
})
```

### 7.2 Text

Text label. **Must have explicit `height`.**

```lua
Text({
  key        = "label",
  text       = "Hello World",
  color      = "#ffffff",
  align      = "left",            -- "left" | "center" | "right"
  font       = "default",         -- GUI font name
  scale      = 1.0,               -- number or {x, y, z}
  line_break = false,             -- enable line breaking
  style      = { height = 32 },   -- REQUIRED for visibility
})
```

Pivot mapping: `"left"` → `PIVOT_W`, `"center"` → `PIVOT_CENTER`, `"right"` → `PIVOT_E`

### 7.3 Button

Clickable box with press/hover visual feedback.

```lua
Button({
  key           = "btn_submit",
  color         = "#4488ff",
  pressed_color = "#2266cc",      -- optional (default: 70% brightness)
  on_click      = function(el) end,
  image         = "btn_round",    -- optional atlas frame
  texture       = "buttons",      -- atlas name (default "icons")
  border        = 24,             -- slice-9 border (number or {left, top, right, bottom})
  style         = { width = 200, height = 48 },
  children      = { Text({ key = "btn_label", text = "Submit", style = { height = 32 } }) },
})
```

- Captures descendant hits (tapping child text triggers button)
- Hover scales to 103% on desktop
- Press darkens color 30%
- `on_click` fires only when released over same button

### 7.4 ButtonImage

Convenience wrapper over Button with `image` required.

```lua
ButtonImage({
  key      = "btn_star",
  image    = "icon_star",          -- REQUIRED
  texture  = "icons",             -- default "icons"
  on_click = function(el) end,
  style    = { width = 48, height = 48 },
})
```

### 7.5 Icon

Display a single atlas frame.

```lua
Icon({
  key          = "star",
  image        = "icon_star",      -- animation frame name in atlas
  texture      = "icons",          -- atlas name (default "icons")
  scale        = 1.0,             -- number or {x, y, z}
  scale_mode   = "fit",           -- "stretch" | "fit"
  image_aspect = 1.0,             -- width/height ratio for "fit" mode
  style        = { width = 32, height = 32 },
})
```

### 7.6 Scroll

Scrollable container with stencil clipping.

```lua
Scroll({
  key             = "my_scroll",
  _scrollbar      = true,          -- show scrollbar (default true)
  _bounce         = true,          -- rubber-band at limits (default true)
  _momentum       = true,          -- inertial scrolling (default true)
  _scroll_y       = 0,             -- initial vertical offset
  _scroll_x       = 0,             -- initial horizontal offset
  _virtual_height = 5000,          -- total content height (virtual scrolling)
  _virtual_width  = nil,           -- total content width (virtual scrolling)
  style           = { flex_grow = 1, flex_direction = "column", gap = 4 },
  children        = { ... },
})
```

- Direction inferred from `flex_direction`: `"column"` = vertical, `"row"` = horizontal
- Scroll state auto-persisted by navigation adapter in `params.scroll_state`
- Scrollbar: 6px track, proportional thumb
- Momentum: velocity > 100 px/s triggers, deceleration 1500–5000 px/s²
- Bounce spring: stiffness 1200, damping 35

### 7.7 Popup

Full-screen modal overlay. Content **must have explicit `height`**.

```lua
Popup({
  key              = "confirm_popup",
  backdrop_color   = "#000000b3",  -- default semi-transparent black
  on_backdrop_click = function(el) end,
  _visible         = true,         -- default true
  style            = { justify_content = "center", align_items = "center" },
  children         = {
    Box({ key = "dialog", style = { width = 300, height = 200 }, children = { ... } }),
  },
})
```

- `_is_overlay = true` — does not participate in normal flex flow
- Receives full parent bounds
- Popup should be a sibling, not a child of the flex container

### 7.8 Markdown

Parse and render markdown as a scrollable Flow element tree.

```lua
-- Full viewer (returns Scroll element)
Markdown({
  key                = "guide",
  text               = md_string,
  font               = "default",
  scale              = 1.0,
  auto_wrap          = true,
  wrap_width         = 520,        -- default 520
  flatten_formatting = false,
  _scrollbar         = true,
  _bounce            = true,
  _momentum          = true,
  style              = { flex_grow = 1 },
})

-- Parse only (returns element array)
local elements = Markdown.parse(text, "prefix", { font = "default", auto_wrap = true })

-- Viewer with style override
local viewer = Markdown.viewer(text, "docs", { padding = 10 })
```

**Supported markdown:**
- Headings: `# h1` through `###### h6`
- Horizontal rules: `---`
- Lists: `- item` (unordered), `1. item` (ordered)
- Blockquotes: `> text`
- Fenced code blocks: `` ```code``` ``
- Bold: `**text**` (highlighted background)
- Inline code: `` `code` `` (darker background)
- Images: `![alt](icon:name)`, `![alt](atlas:texture:image)`, `![alt](url)`
- Image modifiers: `|width=80%|height=220|scale=fit|aspect=634:768`

**Not supported:** tables, nested formatting, links, remote images

---

## 8. Color API

```lua
local color = flow.color  -- or require "flow/color"

color.rgb(r, g, b)                   -- → hex string "#rrggbb"
color.rgba(r, g, b, a)               -- → hex string "#rrggbbaa"
color.hex("#RGB" | "#RGBA" | "#RRGGBB" | "#RRGGBBAA") -- → normalized hex
color.with_alpha("#rrggbb", 0.5)     -- → "#rrggbb80"
color.parse("#ff0000")               -- → {r=1, g=0, b=0, a=1} (0..1 range)
color.resolve("#ff0000")             -- → vmath.vector4(1, 0, 0, 1)
```

**Accepted color formats anywhere in Flow:**
- Hex strings: `"#778899"`, `"#778899cc"`, `"#789"`, `"#789c"`
- CSS named colors: `"white"`, `"black"`, `"red"`, `"rebeccapurple"`, `"transparent"`, etc.
- Color helper results: `color.rgb(...)`, `color.rgba(...)`

---

## 9. Navigation System

### 9.1 Core Operations

```lua
local nav = flow.nav  -- app-wide singleton

-- Screen registration
nav.register(id, screen_def)     -- → RegisteredScreen

-- Stack operations
nav.push(id, params?, options?)  -- push new screen
nav.pop(result?, options?)       -- pop to previous
nav.replace(id, params?, options?) -- swap current screen
nav.reset(id, params?, options?) -- clear stack, go to screen
nav.back(result?, options?)      -- alias for pop

-- State access
nav.current()                    -- → StackEntry | nil
nav.peek(offset?)                -- → StackEntry at depth offset
nav.stack_depth()                -- → number
nav.get_data(key?, opts?)        -- → params or field
nav.set_data(key, value, opts?)  -- → previous value
nav.get_scroll_offset(key, opts?) -- → number

-- Invalidation (triggers re-render)
nav.invalidate()
nav.is_invalidated()             -- → boolean
nav.clear_invalidation()

-- Transitions
nav.is_busy()                    -- → boolean
nav.get_transition()             -- → TransitionMeta | nil
nav.begin_transition(meta)       -- → TransitionMeta
nav.complete_transition()        -- → boolean

-- Event system
nav.on(event, fn)                -- → unsubscribe function
nav.off(event, fn)
```

### 9.2 Options

```lua
-- options parameter (string or table)
"fade"                           -- shorthand for { transition = "fade" }
{ transition = "slide_left", duration = 0.3, on_result = function(result) end }
```

**Transition types:** `"none"`, `"fade"` (default), `"slide_left"`, `"slide_right"`

### 9.3 Screen Definition

```lua
-- GUI screen (most common)
{
  view = function(params, navigation)
    return Box({ ... })  -- return element tree
  end,
  on_enter  = function(params, nav) end,  -- optional
  on_exit   = function(params, nav) end,  -- optional
  on_pause  = function(params, nav) end,  -- optional
  on_resume = function(params, nav) end,  -- optional
}

-- Non-GUI screen (collection proxy)
{
  url       = msg.url("main:/controller#script"),
  proxy_url = msg.url("main:/proxy#collectionproxy"),
  focus_url = msg.url("main:/input#script"),
  preload   = true,
}

-- Hybrid (has both view and url)
{
  view = function(params, nav) return Box({ ... }) end,
  url  = msg.url("main:/controller#script"),
}
```

### 9.4 Params & Results

```lua
-- Passing params
nav.push("profile", { user_id = 42 }, {
  transition = "slide_left",
  on_result = function(result)
    if result and result.saved then
      nav.invalidate()
    end
  end,
})

-- Receiving params in view
view = function(params, nav)
  local user_id = params.user_id
  -- ...
end

-- Returning results
nav.pop({ saved = true, data = edited_data }, "slide_right")

-- Message-based results
nav.push("editor", params, {
  result_url = msg.url("main:/settings#script"),
  result_message_id = hash("navigation_result"),
})
```

### 9.5 Events

| Event                  | Payload                                    |
|------------------------|--------------------------------------------|
| `"changed"`            | `{ action, from, to, stack }`              |
| `"push"`               | `{ entry, stack }`                         |
| `"pop"`                | `{ entry, result, stack }`                 |
| `"replace"`            | `{ old_entry, new_entry, stack }`          |
| `"reset"`              | `{ entry, stack }`                         |
| `"registered"`         | `{ id, screen }`                           |
| `"preload"`            | `{ id, screen }`                           |
| `"transition_begin"`   | `TransitionMeta`                           |
| `"transition_complete"`| `TransitionMeta`                           |

### 9.6 Message Transport

Send navigation commands from any script via Defold messages:

```lua
msg.post("main:/gui#script", "navigation_push", {
  id = "inventory",
  params = { tab = "equipment" },
  options = { transition = "slide_left" },
})
```

| Message ID               | Payload fields                        |
|--------------------------|---------------------------------------|
| `navigation_push`        | `id`, `params?`, `options?`           |
| `navigation_pop`         | `result?`, `options?`                 |
| `navigation_replace`     | `id`, `params?`, `options?`           |
| `navigation_reset`       | `id`, `params?`, `options?`           |
| `navigation_back`        | `result?`, `options?`                 |
| `navigation_invalidate`  | (no payload)                          |

### 9.7 Lifecycle Messages (sent to screen `url`)

| Hash                       | When                              |
|----------------------------|-----------------------------------|
| `hash("navigation_enter")` | Screen pushed/replaced/reset to   |
| `hash("navigation_exit")`  | Screen popped/replaced/reset from |
| `hash("navigation_pause")` | Screen covered by new push        |
| `hash("navigation_resume")`| Screen uncovered by pop           |

### 9.8 Proxy Runtime

Auto-load/enable/disable collections as screens navigate:

```lua
-- In a .script (not gui_script)
function init(self)
  self.proxy = flow.nav.proxy.attach(flow.nav)
end
function final(self)
  self.proxy:detach()
end
```

Screen with proxy:
```lua
nav.register("gameplay", {
  url       = msg.url("main:/gameplay#script"),
  proxy_url = msg.url("main:/gameplay_proxy#collectionproxy"),
  preload   = true,  -- async_load on register
})
```

### 9.9 Non-GUI Runtime

Bootstrap navigation in `.script` files (no GUI rendering):

```lua
function init(self)
  flow.nav.runtime.init(self, {
    screens = { ... },
    initial_screen = "gameplay",
    initial_params = { level = 1 },
  })
end
function final(self) flow.nav.runtime.final(self) end
function on_message(self, message_id, message, sender)
  if flow.nav.runtime.on_message(self, message_id, message, sender) then return end
end
```

---

## 10. Bottom Sheet (Hosted API)

Bottom sheets run in a **separate gui_script** with their own render context.

### Host setup (dedicated gui_script)

```lua
local flow = require "flow/flow"

function init(self)
  flow.bottom_sheet.init(self, {
    id = "main_sheet",
    sheet = {
      view = function(params, api)
        return Box({ key = "sheet_root", style = { height = 300 }, children = {
          Button({ key = "close", on_click = function() api.dismiss() end,
            style = { height = 48 }, children = {
              Text({ key = "close_label", text = "Close", style = { height = 32 } })
            }
          }),
        }})
      end,
      backdrop_color = "#000000b3",
      dismiss_on_backdrop = true,   -- default true
      on_dismiss = function(params, result, api) end,
    },
    open_message_id  = hash("open_sheet"),   -- optional trigger
    close_message_id = hash("close_sheet"),  -- optional trigger
    background_focus_url = msg.url("main:/gui#script"), -- optional
    render_order = 15,             -- 0..15, default 15
  })
end

function final(self) flow.bottom_sheet.final(self) end
function update(self, dt) flow.bottom_sheet.update(self, dt) end
function on_input(self, action_id, action) return flow.bottom_sheet.on_input(self, action_id, action) end
function on_message(self, message_id, message, sender) return flow.bottom_sheet.on_message(self, message_id, message, sender) end
```

### Programmatic control

```lua
flow.bottom_sheet.present(self, { title = "Settings" })
flow.bottom_sheet.dismiss(self, { saved = true })
flow.bottom_sheet.invalidate(self)
```

### Inside `sheet.view(params, api)`

```lua
api.dismiss(result?)    -- close the sheet
api.invalidate()        -- rebuild after params change
```

### Multi-step sheet (nested navigation)

```lua
sheet = {
  screens = {
    step1 = { view = function(params, api) ... end },
    step2 = { view = function(params, api) ... end },
  },
  initial_screen = "step1",
}
```

---

## 11. Renderer API (`flow.ui`)

```lua
local ui = flow.ui

ui.mount(self, opts?)                -- Initialize renderer; creates self.ui
ui.render(self, tree, w?, h?)        -- Force full layout + render
ui.update(self, tree?)               -- Render only if redraw needed → boolean
ui.update_animations(self, dt)       -- Tick animations → boolean
ui.request_redraw(self)              -- Force re-render next update
ui.request_tree_redraw(tree)         -- Set tree._needs_redraw = true
ui.render_if_size_changed(self, tree?) -- Re-render only if display changed → boolean
ui.hit_test(self, x, y)             -- Point hit test → Element | nil
ui.on_input(self, action_id, action) -- Route input → boolean
ui.set_debug(self, enabled)          -- Enable input debug logging → boolean
ui.get_size()                        -- → (width, height) from game.project
```

### Registering custom element types

```lua
ui.register("my_widget", {
  create_node = function(el) ... end,           -- REQUIRED: return Defold gui node
  apply       = function(self, el, node, alpha) ... end, -- update node properties
  is_visible  = function(el) ... end,           -- visibility check
  is_hittable = function(el) ... end,           -- hit-test eligibility
  press_begin = function(self, el, deps) ... end,
  press_end   = function(self, el, deps) ... end,
  on_wheel    = function(self, el, deps) ... end,
  on_drag_start = function(self, el, deps) ... end,
  on_drag_move  = function(self, el, deps) ... end,
  on_drag_end   = function(self, el, deps) ... end,
  update_anim   = function(el, dt, deps) ... end,
  hover_begin   = function(self, el, deps) ... end,
  hover_end     = function(self, el, deps) ... end,
  -- ... more optional hooks
})
```

### Node caching

- Cache key = `(node_prefix or "") .. element.key`
- Existing key → reuse Defold GUI node (update position/size/color)
- New key → create new GUI node
- After render: delete nodes whose keys are not in the new tree
- **Critical:** Unstable keys cause node leaks (512 node limit per GUI scene)

### Rendering pipeline per frame

1. `screen.view(params, nav)` → returns element tree (Lua tables)
2. `layout.compute(tree, ...)` → writes `{x, y, w, h}` onto every node
3. `apply(tree)` → create/update Defold GUI nodes from layout
4. `collect_node_keys(tree)` → build set of expected cache keys
5. Delete orphaned nodes → remove GUI nodes whose keys left tree
6. `update_anim(tree, dt)` → tick per-primitive physics/animations

Steps 1–5 run only when redraw is needed. Step 6 runs every frame.

---

## 12. Layout Algorithm Detail

### Inner box calculation

```
inner_x = x + padding_left
inner_y = y + padding_bottom
inner_w = w - padding_left - padding_right
inner_h = h - padding_top - padding_bottom
```

### Main axis distribution

1. Separate overlay children (`_is_overlay = true`) from normal flow
2. Measure children: explicit size → `fixed`; no size → `flex_grow` → `grow_sum`
3. `fixed = sum_of_sizes + gap * (n - 1)`; `free = inner_main - fixed`; clamp `free ≥ 0`
4. Apply `justify_content` offsets when `grow_sum == 0`
5. Place children along main axis, distribute `free` space to `flex_grow` children
6. Apply cross-axis `align_items` / `align_self`
7. Recurse into each child
8. Layout overlay children at full parent (outer) bounds

### Column direction specifics

- Y axis is bottom-up; children placed top-to-bottom logically
- `child_y = inner_y + inner_h - cursor - child_h`

### Row direction specifics

- X axis left-to-right
- `child_x = inner_x + cursor`

---

## 13. Logging System

```lua
local log = flow.log  -- or require "flow/log"

-- Log levels
log.levels = { none = 0, error = 1, warn = 2, info = 3, debug = 4 }

-- Global level (library starts at "none")
log.set_level("debug")           -- → previous level
log.get_level()                  -- → current level

-- Per-context override
log.set_context_level("ui.input", "debug")
log.clear_context_level("ui.input")
log.get_context_level("ui.input")

-- Logging functions
log.debug("my_context", "value = %d", 42)
log.info("my_context", "started")
log.warn("my_context", "deprecated")
log.error("my_context", "failed: %s", err)

-- Query
log.is_enabled("debug", "ui.input") -- → boolean

-- Custom sink
log.set_sink(function(entry)
  -- entry.level, entry.context, entry.message, entry.line
end)
log.set_sink(nil)  -- restore default
```

### Built-in contexts

`flow`, `ui`, `ui.input`, `ui.renderer`, `ui.scroll`, `nav`, `nav.messages`, `nav.proxy`, `nav.runtime`

### Default log format

```
[flow][DEBUG][nav] push id=inventory from=home depth=2 transition=slide_left
```

---

## 14. Flex Imperative API (`flow/flex.lua`)

Optional Yoga-compatible wrapper for building trees imperatively. Produces identical input for `layout.compute()`.

```lua
local FL = require "flow/flex"

local root = FL.Node.new({ key = "root", type = "box" })
  :set_width(960)
  :set_height(640)
  :set_flex_direction(FL.FLEX_DIRECTION_COLUMN)
  :set_justify_content(FL.JUSTIFY_CENTER)
  :set_padding(FL.EDGE_ALL, 20)

local child = FL.Node.new({ key = "child", type = "box" })
  :set_height(100)
  :set_align_self(FL.ALIGN_CENTER)

root:insert_child(child)
root:calculate_layout()

print(child:get_layout())  -- { x, y, w, h }
```

### Constants

```lua
-- Flex Direction
FL.FLEX_DIRECTION_COLUMN          -- "column"
FL.FLEX_DIRECTION_ROW             -- "row"

-- Justify Content
FL.JUSTIFY_FLEX_START             -- "start"
FL.JUSTIFY_CENTER                 -- "center"
FL.JUSTIFY_FLEX_END               -- "end"
FL.JUSTIFY_SPACE_BETWEEN          -- "space-between"
FL.JUSTIFY_SPACE_AROUND           -- "space-around"
FL.JUSTIFY_SPACE_EVENLY           -- "space-evenly"

-- Align
FL.ALIGN_AUTO                     -- "auto"
FL.ALIGN_FLEX_START               -- "start"
FL.ALIGN_CENTER                   -- "center"
FL.ALIGN_FLEX_END                 -- "end"
FL.ALIGN_STRETCH                  -- "stretch"

-- Edges (for padding, margin, border, position)
FL.EDGE_LEFT, FL.EDGE_RIGHT, FL.EDGE_TOP, FL.EDGE_BOTTOM
FL.EDGE_ALL, FL.EDGE_HORIZONTAL, FL.EDGE_VERTICAL
FL.EDGE_START, FL.EDGE_END

-- Display
FL.DISPLAY_FLEX                   -- "flex"
FL.DISPLAY_NONE                   -- "none"

-- Overflow
FL.OVERFLOW_VISIBLE, FL.OVERFLOW_HIDDEN, FL.OVERFLOW_SCROLL

-- Position Type
FL.POSITION_TYPE_STATIC, FL.POSITION_TYPE_RELATIVE, FL.POSITION_TYPE_ABSOLUTE

-- Wrap
FL.WRAP_NO_WRAP, FL.WRAP_WRAP, FL.WRAP_WRAP_REVERSE

-- Direction
FL.DIRECTION_INHERIT, FL.DIRECTION_LTR, FL.DIRECTION_RTL
```

### Node methods (all setters are chainable)

```lua
-- Child management
node:insert_child(child, index?)  -- 1-based index
node:remove_child(child)
node:get_child(index)             -- 0-based index
node:get_child_count()

-- Sizing
node:set_width(px) / :set_height(px)
node:set_width_percent(pct) / :set_height_percent(pct)
node:set_min_width(px) / :set_min_height(px) / :set_max_width(px) / :set_max_height(px)

-- Flex
node:set_flex_direction(dir)
node:set_flex_grow(factor) / :set_flex_shrink(factor) / :set_flex_basis(size)
node:set_justify_content(align) / :set_align_items(align) / :set_align_self(align)
node:set_gap(px)

-- Spacing
node:set_padding(edge, value) / :set_padding_percent(edge, pct)
node:set_margin(edge, value) / :set_margin_percent(edge, pct)
node:set_border(edge, value)

-- Position
node:set_position(edge, value) / :set_position_type(type)

-- Other
node:set_flex_wrap(wrap) / :set_overflow(overflow) / :set_display(mode)
node:set_aspect_ratio(ratio) / :set_direction(dir)
node:set_measure_func(fn)
node:set_style(key, value) / :get_style(key)

-- Layout
node:calculate_layout(width?, height?)
FL.calculate_layout(root, w, h)
node:get_layout()                 -- → { x, y, w, h }
node:get_computed_left() / :get_computed_top() / :get_computed_width() / :get_computed_height()
```

---

## 15. Virtual Scrolling Pattern

For large lists (> ~100 items), render only visible items:

```lua
view = function(params, nav)
  local ITEM_H = 60
  local data = params.items  -- e.g., 1000 items
  local total_h = #data * ITEM_H
  local scroll_y = nav.get_scroll_offset("list") or 0
  local visible_h = 500  -- viewport height
  local buffer = 2

  local first = math.max(1, math.floor(scroll_y / ITEM_H) + 1 - buffer)
  local last  = math.min(#data, math.ceil((scroll_y + visible_h) / ITEM_H) + buffer)

  local children = {}
  -- Top spacer
  if first > 1 then
    table.insert(children, Box({ key = "spacer_top", style = { height = (first - 1) * ITEM_H } }))
  end
  -- Visible items
  for i = first, last do
    table.insert(children, Box({ key = "item_" .. i, style = { height = ITEM_H }, children = {
      Text({ key = "item_text_" .. i, text = data[i].name, style = { height = 32 } })
    }}))
  end
  -- Bottom spacer
  if last < #data then
    table.insert(children, Box({ key = "spacer_bottom", style = { height = (#data - last) * ITEM_H } }))
  end

  return Scroll({
    key = "list",
    _virtual_height = total_h,
    style = { flex_grow = 1 },
    children = children,
  })
end
```

**Node budget:** Defold limits 512 GUI nodes per scene. Virtual scrolling reduces ~3000 nodes → ~60.

---

## 16. Common Patterns

### Full-screen layout

```lua
Box({ key = "root", style = { width = 960, height = 640, flex_direction = "column" }, children = {
  Box({ key = "header", style = { height = 60 }, color = "#333" }),
  Scroll({ key = "content", style = { flex_grow = 1 }, children = { ... } }),
  Box({ key = "footer", style = { height = 50 }, color = "#333" }),
}})
```

### Centered dialog

```lua
Box({ key = "root", style = { width = 960, height = 640, justify_content = "center", align_items = "center" }, children = {
  Box({ key = "dialog", style = { width = 400, height = 300, padding = 20, gap = 10 }, color = "#fff", children = { ... } }),
}})
```

### Toolbar row

```lua
Box({ key = "toolbar", style = { height = 48, flex_direction = "row", align_items = "center", gap = 8, padding_left = 12, padding_right = 12 }, children = {
  Button({ key = "back", on_click = function() nav.pop() end, style = { width = 32, height = 32 } }),
  Text({ key = "title", text = "Settings", style = { flex_grow = 1, height = 32 } }),
  ButtonImage({ key = "save", image = "icon_save", style = { width = 32, height = 32 } }),
}})
```

### State mutation with invalidation

```lua
view = function(params, nav)
  params.count = params.count or 0
  return Box({ key = "root", style = { width = 960, height = 640, justify_content = "center", align_items = "center", gap = 10 }, children = {
    Text({ key = "count", text = "Count: " .. params.count, style = { height = 32 } }),
    Button({ key = "inc", on_click = function()
      params.count = params.count + 1
      nav.invalidate()
    end, style = { width = 120, height = 40 }, color = "#4488ff", children = {
      Text({ key = "inc_label", text = "+1", style = { height = 32 }, color = "#fff" }),
    }}),
  }})
end
```

### Conditional rendering (disabled button)

```lua
local can_submit = params.name and #params.name > 0
Button({
  key = "submit",
  color = can_submit and "#4488ff" or "#888888",
  on_click = function()
    if not can_submit then return end
    -- proceed
  end,
  style = { width = 200, height = 48 },
})
```

---

## 17. Debugging

### Enable debug mode

```lua
flow.ui.set_debug(self, true)
```

Output on every touch:
```
[flow][DEBUG][ui.input] touch pressed
  gui:    (234.0, 410.0)
  layout: (234.0, 230.0)
  window: (960, 640)  gui: (960, 640)  scale: (1.0, 1.0)
  hit:    "item_7"  bounds: {x=16, y=218, w=928, h=60}
```

### Targeted logging

```lua
flow.log.set_level("warn")                      -- global
flow.log.set_context_level("ui.input", "debug") -- specific context
flow.log.set_context_level("nav", "debug")      -- navigation detail
```

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Element invisible | No `height` and no `flex_grow` | Add explicit `height` or `flex_grow = 1` |
| Button not responding | Parent has height 0 or overlay covering | Check ancestor heights; enable debug |
| Nodes accumulating | Unstable keys (random/time-based) | Use stable, deterministic keys |
| Scroll resets | `nav.reset()` called or screen replaced | Use `nav.push()` / `nav.pop()` instead |
| Popup content invisible | No explicit height on popup children | Add `height` to popup content |
| Layout wrong | Missing `width` on ancestors | Ensure root and containers have dimensions |

---

## 18. Key Rules Summary

1. **Always `require "flow/flow"`** — never import sub-modules directly unless needed
2. **Every element needs a unique, stable `key`**
3. **Always provide explicit `height`** on Text, Popup content, and leaf nodes
4. **State lives in `params`** — mutate then call `nav.invalidate()`
5. **`view()` must be pure** — no side effects, return element tree only
6. **Build fresh `children` tables** each call — never reuse captured tables
7. **Watch the 512 node budget** — use virtual scrolling for long lists
8. **Popup/BottomSheet are overlays** — they bypass normal flex flow
9. **`flow.nav` is app-wide singleton; `flow.ui` is per-renderer instance**
10. **Use `flow.log.*`** instead of `print()` for debugging
