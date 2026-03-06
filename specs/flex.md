# flex.lua — Flex API

Optional wrapper that exposes a fluent node-builder API over `layout.lua`. It keeps a broadly Yoga-style constant set for compatibility, while the current layout engine consumes a smaller flexbox-style subset of the stored style fields.

Use this module when you want to build the layout tree imperatively (method calls on node objects) rather than declaratively (plain Lua tables). Both styles produce identical input for `layout.compute()`.

---

## Constants

### Flex Direction

```lua
FL.FLEX_DIRECTION_COLUMN  -- "column"
FL.FLEX_DIRECTION_ROW     -- "row"
```

### Justify Content

```lua
FL.JUSTIFY_FLEX_START    -- "start"
FL.JUSTIFY_CENTER        -- "center"
FL.JUSTIFY_FLEX_END      -- "end"
FL.JUSTIFY_SPACE_BETWEEN -- "space-between"
FL.JUSTIFY_SPACE_AROUND  -- "space-around"
FL.JUSTIFY_SPACE_EVENLY  -- "space-evenly"
```

### Align Items / Self

```lua
FL.ALIGN_AUTO       -- "auto"
FL.ALIGN_FLEX_START -- "start"
FL.ALIGN_CENTER     -- "center"
FL.ALIGN_FLEX_END   -- "end"
FL.ALIGN_STRETCH    -- "stretch"
```

### Edge (for padding)

```lua
FL.EDGE_LEFT   -- "left"
FL.EDGE_TOP    -- "top"
FL.EDGE_RIGHT  -- "right"
FL.EDGE_BOTTOM -- "bottom"
FL.EDGE_ALL    -- "all"  (sets uniform padding)
FL.EDGE_HORIZONTAL -- "horizontal"
FL.EDGE_VERTICAL   -- "vertical"
FL.EDGE_START      -- "start"
FL.EDGE_END        -- "end"
```

### Additional Yoga-style Constants

```lua
FL.DISPLAY_FLEX / FL.DISPLAY_NONE
FL.OVERFLOW_VISIBLE / FL.OVERFLOW_HIDDEN / FL.OVERFLOW_SCROLL
FL.WRAP_NO_WRAP / FL.WRAP_WRAP / FL.WRAP_WRAP_REVERSE
FL.POSITION_TYPE_STATIC / FL.POSITION_TYPE_RELATIVE / FL.POSITION_TYPE_ABSOLUTE
FL.DIRECTION_INHERIT / FL.DIRECTION_LTR / FL.DIRECTION_RTL
```

---

## Node Class

### Creating a Node

```lua
local FL = require "flow/flex"
local node = FL.Node.new()
```

Each node is a table with Yoga style state plus optional UI fields:

```lua
FL.Node.new({
  key = "root",          -- optional
  type = "box",          -- default "box"
  color = some_color,    -- optional
  style = {},
  children = {},
})
```

All setter methods are fluent (`return self`) and can be chained.

### Child Management

```lua
node:insert_child(child, index)
-- Inserts child at position index+1 (1-based). Appends if index omitted.

node:remove_child(child)
-- Removes child by reference (searches from end).

node:get_child(index)
-- Returns child at 0-based index.

node:get_child_count()
-- Returns number of children.
```

### Style Setters

All setters write into `node.style`:

```lua
node:set_width(value)          -- pixels
node:set_height(value)

node:set_width_percent(value)  -- stores "N%"
node:set_height_percent(value)

node:set_min_width(value)      -- stored but not enforced by layout engine
node:set_min_height(value)
node:set_max_width(value)
node:set_max_height(value)

node:set_flex_direction(value) -- use FL.FLEX_DIRECTION_* constants
node:set_flex_grow(value)
node:set_flex_shrink(value)    -- stored but not enforced by layout engine
node:set_flex_basis(value)     -- stored but not enforced by layout engine

node:set_justify_content(value)  -- use FL.JUSTIFY_* constants
node:set_align_items(value)      -- use FL.ALIGN_* constants
node:set_align_self(value)

node:set_gap(value)

node:set_padding(edge, value)          -- edge: FL.EDGE_*
node:set_padding_percent(edge, value)  -- stores "N%"
node:set_margin(edge, value)
node:set_margin_percent(edge, value)
node:set_border(edge, value)
node:set_position(edge, value)
node:set_position_type(value)

node:set_flex_wrap(value)
node:set_overflow(value)
node:set_display(value)
node:set_aspect_ratio(value)
node:set_direction(value)

node:set_style(key, value)   -- generic setter
node:get_style(key)          -- generic getter
```

### Layout Computation

```lua
node:calculate_layout(width, height)
-- Calls layout.compute(node, 0, 0, width, height)
-- width/height default to node.style.width/height or 0
```

```lua
FL.calculate_layout(root, width, height)
-- Module-level convenience; same as node:calculate_layout()
```

### Reading Results

```lua
node:get_layout()
-- Returns node.layout = { x, y, w, h } after calculate_layout()

node:get_computed_left()
node:get_computed_top()
node:get_computed_width()
node:get_computed_height()
```

### Measure Function

```lua
node:set_measure_func(fn)
-- Stores fn in node.measure. Not called by layout.lua currently.
-- Reserved for future content-driven size measurement.
```

---

## Usage Example

```lua
local FL = require "flow/flex"

local root = FL.Node.new()
root:set_width(960)
root:set_height(640)
root:set_flex_direction(FL.FLEX_DIRECTION_COLUMN)
root:set_justify_content(FL.JUSTIFY_CENTER)
root:set_align_items(FL.ALIGN_CENTER)
root:set_gap(16)

local child = FL.Node.new()
child:set_width(200)
child:set_height(50)
root:insert_child(child)

root:calculate_layout(960, 640)

local l = root:get_layout()   -- { x=0, y=0, w=960, h=640 }
local cl = child:get_layout() -- { x=380, y=295, w=200, h=50 }
```

---

## Notes

- `min_width`, `max_width`, `min_height`, `max_height`, `flex_shrink`, and `flex_basis` are **stored** in the style table but **not enforced** by `layout.lua`. They are available for forward compatibility.
- `margin`, `border`, `position`, `position_type`, `display`, `overflow`, `direction`, `flex_wrap`, and `aspect_ratio` are stored for API compatibility; the current `layout.lua` may ignore them.
- The `measure` function field (`set_measure_func`) is stored but never invoked by the current layout engine.
- `Node.new(opts)` now accepts optional `type`, `key`, and `color` fields for easier interoperability with `ui.lua`.
