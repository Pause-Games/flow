# Tutorial 5 — Scroll & Lists

This tutorial covers two things: the `Scroll` component for scrollable content, and virtual scrolling for lists that would otherwise exceed Defold's 512-node limit.

---

## Basic Scroll

Wrap any content in `Scroll` to make it scrollable:

```lua
local Scroll = flow.ui.cp.Scroll

Scroll({
  key   = "feed",
  style = { flex_grow = 1, flex_direction = "column", gap = 8, padding = 16 },
  children = {
    -- any elements here
  }
})
```

`Scroll` clips its children and handles mouse wheel and touch drag automatically.

### Scroll direction

Direction is set by `flex_direction`:
- `"column"` (default) → vertical scroll
- `"row"` → horizontal scroll

### Scroll options

| Field | Default | Description |
|-------|---------|-------------|
| `_scrollbar` | `true` | Show the scrollbar indicator |
| `_bounce` | `true` | Rubber-band resistance + spring-back when dragging past bounds |
| `_momentum` | `true` | Inertial scrolling after drag release |

---

## A Scrollable List

Typical pattern: a screen with a fixed header and a scrollable body.

```lua
view = function(params, nav)
  local items = {}
  for i = 1, 30 do
    table.insert(items, Box({
      key   = "item_" .. i,
      color = "#2e3340",
      style = { height = 60, width = "100%", padding_left = 16, align_items = "center" },
      children = {
        Text({ key = "lbl_" .. i, text = "Item " .. i, style = { height = 28 } }),
      }
    }))
  end

  return Box({
    key   = "root",
    style = { width = "100%", height = "100%", flex_direction = "column" },
    children = {
      Box({
        key   = "header",
        color = "#1a1f26",
        style = { height = 56, padding_left = 16, align_items = "center" },
        children = { Text({ key = "title", text = "My List", style = { height = 32 } }) }
      }),
      Scroll({
        key   = "list",
        style = { flex_grow = 1, flex_direction = "column", gap = 4, padding = 8 },
        children = items,
      }),
    }
  })
end
```

---

## The 512 Node Limit

Defold allows at most **512 GUI nodes** per scene. Each `Box`, `Text`, `Button`, and internal scrollbar node counts against this limit. A list of 100 items with 3 nodes each = 300 nodes — close to the limit. A list of 200 items will crash.

**Virtual scrolling** solves this by only rendering the items currently visible on screen, replacing off-screen items with transparent spacer boxes.

---

## Virtual Scrolling

### How it works

Instead of creating nodes for all 1000 items, you:
1. Declare the total logical height with `_virtual_height`.
2. Calculate which items are visible based on the current scroll offset.
3. Render only those items, with spacer boxes above and below.

The scroll system uses `_virtual_height` for bounds and scrollbar sizing, so the scrollbar reflects the full list even though only a fraction is rendered.

### Getting the scroll offset

```lua
local scroll_offset = flow.nav.get_scroll_offset("list") or 0
```

`get_scroll_offset` returns the current `_scroll_y` for the scroll container with that key.

### The spacer pattern

```lua
view = function(params, nav)
  local ITEM_H     = 60
  local TOTAL      = 1000
  local VIEWPORT_H = 580    -- approximate visible height
  local BUFFER     = 3      -- extra items above/below visible range

  local scroll_y = flow.nav.get_scroll_offset("list") or 0

  local first_visible = math.floor(scroll_y / ITEM_H) + 1
  local last_visible  = math.ceil((scroll_y + VIEWPORT_H) / ITEM_H)
  local first_render  = math.max(1, first_visible - BUFFER)
  local last_render   = math.min(TOTAL, last_visible + BUFFER)

  local items = {}

  -- Top spacer: invisible box representing off-screen items above
  if first_render > 1 then
    table.insert(items, Box({
      key   = "top_spacer",
      color = "transparent",
      style = { height = (first_render - 1) * ITEM_H, width = "100%" },
    }))
  end

  -- Visible items
  for i = first_render, last_render do
    table.insert(items, Box({
      key   = "item_" .. i,
      color = "#2e3340",
      style = { height = ITEM_H, width = "100%", padding_left = 16, align_items = "center" },
      children = { Text({ key = "lbl_" .. i, text = "Item " .. i, style = { height = 28 } }) }
    }))
  end

  -- Bottom spacer: invisible box representing off-screen items below
  if last_render < TOTAL then
    table.insert(items, Box({
      key   = "bottom_spacer",
      color = "transparent",
      style = { height = (TOTAL - last_render) * ITEM_H, width = "100%" },
    }))
  end

  return Box({
    key   = "root",
    style = { width = "100%", height = "100%", flex_direction = "column" },
    children = {
      Scroll({
        key            = "list",
        style          = { flex_grow = 1, flex_direction = "column", gap = 0 },
        _virtual_height = TOTAL * ITEM_H,   -- total logical height
        children       = items,
      })
    }
  })
end
```

### Node count comparison

| Approach | 1000 items | Nodes |
|----------|-----------|-------|
| Naive | all rendered | ~3000 (crashes) |
| Virtual | ~18 visible + 2 spacers | ~60 |

### Re-render on scroll

With `flow.init` / `flow.update`, the framework automatically persists scroll state and rebuilds the active screen tree when the scroll position changes. No extra work needed — the next `view()` call will see the updated offset from `get_scroll_offset`.

For fine-grained control over when to regenerate (e.g., only when crossing an item boundary), you can track the previous offset yourself:

```lua
params.last_scroll = params.last_scroll or 0

local curr = flow.nav.get_scroll_offset("list") or 0
local boundary_changed = math.floor(params.last_scroll / ITEM_H) ~= math.floor(curr / ITEM_H)
params.last_scroll = curr

-- Only rebuild items table if a new item boundary was crossed
```

---

## Horizontal Scroll

Set `flex_direction = "row"` and use `_virtual_width` for horizontal virtual scrolling:

```lua
Scroll({
  key           = "h_list",
  style         = { width = "100%", height = 120, flex_direction = "row", gap = 8 },
  _virtual_width = TOTAL * ITEM_W,
  children      = items,
})
```

Use `flow.nav.get_scroll_offset("h_list")` to get the horizontal offset (`_scroll_x`).

---

## Tips

- **Consistent item heights** make virtual scrolling simple. Variable heights require a cumulative offset array.
- **Key stability**: use `"item_" .. i` — deterministic, never random.
- **Buffer size**: 3 items above/below visible range prevents flashing when scrolling fast.
- **Don't store state inside items**: items are created and destroyed frequently. Store all state in `params`.

---

## Next

[Tutorial 6 — Overlays](06-overlays.md): add modal popups and animated bottom sheets to your app.
