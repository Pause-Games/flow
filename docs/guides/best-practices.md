# Best Practices

Rules and patterns that keep Flow apps correct, performant, and easy to maintain.

---

## Keys

**Every element must have a unique, stable `key`.**

The renderer caches Defold GUI nodes by key. An unstable key (e.g. based on `math.random()` or `os.time()`) creates a new GUI node every frame and leaks the old one.

```lua
-- Good: deterministic, based on data
key = "item_" .. index
key = "user_" .. user.id
key = "tab_settings"

-- Bad: random or time-based
key = "item_" .. math.random()   -- leaks nodes every frame
key = "node_" .. os.time()       -- changes every second
```

In virtual scrolling, keys also control which nodes get deleted when items scroll off-screen. A stable key ensures the right node is removed.

---

## Always Provide `height`

Flow does not support intrinsic / auto height. A node without an explicit `height` and without `flex_grow` gets a height of **0** in the main axis, making it invisible and unhittable.

This is especially critical for:

- `Text` nodes — always set `height`.
- Overlay content boxes (`Popup`, `BottomSheet` children) — always set `height`.
- Intermediate wrapper boxes that don't fill the full parent.

```lua
-- Bad: text is invisible
Text({ key = "t", text = "Hello" })

-- Good
Text({ key = "t", text = "Hello", style = { height = 32 } })
```

---

## Calling `mark_dirty()`

Re-renders only happen when the renderer is marked dirty. After mutating any state that affects the UI, call:

```lua
flow.nav.mark_dirty()    -- from anywhere (preferred)
flow.mark_dirty(self)    -- from inside the gui_script (alternative)
```

Multiple calls in the same frame are collapsed — no penalty for calling it more than once.

**Do not** rely on passing a new tree object to trigger a re-render without marking dirty. Use `mark_dirty()` explicitly.

---

## State Lives in `params`

Each screen's `params` table persists for the lifetime of that screen on the navigation stack. Use it for all screen-local state.

```lua
view = function(params, nav)
  -- Initialize with defaults (runs only once per value)
  params.page      = params.page or 1
  params.selected  = params.selected or nil
  params.show_menu = params.show_menu ~= false  -- default true

  ...
end
```

Do not store state in module-level variables unless it needs to be shared across multiple screens.

---

## Watch the Node Budget

Defold limits you to **512 GUI nodes per scene**. Each `Box`, `Text`, `Button`, `Icon` = 1 node. Scroll containers add 1–2 extra nodes for the clip and scrollbar.

Rough guidance:

| Node count | Status |
|------------|--------|
| < 200 | Safe |
| 200–400 | Monitor |
| 400–512 | Danger zone |
| > 512 | Crash |

For lists with many items, use virtual scrolling. See [Tutorial 5](../tutorials/05-scroll-and-lists.md).

---

## Prefer `flow/flow.lua`

Always import from `flow/flow.lua` rather than individual modules:

```lua
-- Preferred
local flow   = require "flow/flow"
local Box    = flow.ui.cp.Box
local Button = flow.ui.cp.Button

-- Avoid splitting imports unless you have a specific reason
local ui  = require "flow/ui"
local nav = require "flow/navigation/init"
```

`flow/flow.lua` wires all modules together correctly and exposes the right API surface.

---

## Use the Lifecycle Facade

Prefer the high-level lifecycle functions over low-level calls:

```lua
-- Preferred
flow.init(self, { screens = SCREENS, initial_screen = "home" })
flow.update(self, dt)
flow.on_input(self, action_id, action)
flow.on_message(self, message_id, message, sender)
flow.final(self)

-- Only drop to the low-level API when you specifically need it
flow.ui.mount(self, opts)
flow.ui.render(self, tree, w, h)
```

---

## Overlay Content Needs Explicit Height

Popup and BottomSheet children are positioned by flex inside the overlay's full-screen bounds. The overlay itself takes up the full screen, but its content box needs an explicit height to be visible.

```lua
-- Bad: dialog is 0px tall, invisible
Popup({
  children = {
    Box({ key = "dialog", style = { width = 300 } })  -- no height!
  }
})

-- Good
Popup({
  children = {
    Box({ key = "dialog", style = { width = 300, height = 200 } })
  }
})
```

---

## Keep `view()` Pure

`view()` is called every time the screen is re-rendered. Keep it free of side effects:

```lua
-- Bad: side effects in view()
view = function(params, nav)
  http.request(...)   -- triggers a network call every frame!
  ...
end

-- Good: trigger side effects in lifecycle hooks or button callbacks
on_enter = function(params, nav)
  -- fetch data once when screen opens
end,
view = function(params, nav)
  -- only read params, build tree
end,
```

---

## Children Table Reuse

Build the `children` table fresh each `view()` call — do not reuse a captured table across calls. Each call to `view()` should return a fully new tree (Lua tables are cheap):

```lua
-- Bad: shared mutable table
local shared_children = {}
view = function(params, nav)
  -- appending to same table across calls
  table.insert(shared_children, Box({ ... }))
  return Box({ children = shared_children })
end

-- Good: build fresh each call
view = function(params, nav)
  local children = {}
  for i = 1, #data do
    table.insert(children, Box({ key = "item_" .. i, ... }))
  end
  return Box({ children = children })
end
```

---

## Logging Over Printing

Use `flow.log` instead of `print()` for runtime observability. This lets you control log level without touching code:

```lua
-- Bad: always prints, pollutes console in production
print("scroll_y = " .. scroll_y)

-- Good: only prints when debug level is active
flow.log.debug("ui.scroll", "scroll_y = %d", scroll_y)
```

See [Debugging](debugging.md) for log level configuration.

---

## Virtual Scrolling Checklist

When implementing a virtual list:

- [ ] Set `_virtual_height` (or `_virtual_width`) on the `Scroll` node
- [ ] Use `flow.nav.get_scroll_offset(key)` to get the current offset
- [ ] Add a top spacer box before visible items
- [ ] Add a bottom spacer box after visible items
- [ ] Use stable, index-based keys: `"item_" .. i`
- [ ] Do not store any state inside item elements — use `params` or an external table
- [ ] Choose a re-render trigger (e.g. item boundary) to avoid regenerating on every pixel
