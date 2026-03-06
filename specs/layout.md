# layout.lua — Layout Engine

Pure Lua flexbox layout engine. No Defold dependencies. Given a tree of nodes with style properties, it computes absolute `{x, y, w, h}` rectangles for every node. Origin is bottom-left.

---

## Entry Point

```lua
local layout = require "flow/layout"
layout.compute(node, x, y, w, h)
```

Recursively walks `node` and its `children`, writing `node.layout = { x, y, w, h }` to each element in-place.

| Parameter | Type   | Description                           |
|-----------|--------|---------------------------------------|
| `node`    | table  | Root element (must have `.style`, optional `.children`) |
| `x`       | number | Left edge of this node in layout space |
| `y`       | number | Bottom edge in layout space           |
| `w`       | number | Available width                       |
| `h`       | number | Available height                      |

---

## Style Properties

All properties live in `node.style = {}`. Pixel values are numbers; percentage values are strings ending in `%` (e.g. `"50%"`).

### Sizing

| Property  | Type          | Default | Description                  |
|-----------|---------------|---------|------------------------------|
| `width`   | number or `%` | —       | Fixed width. Omit to use flex_grow or stretch. |
| `height`  | number or `%` | —       | Fixed height. Omit to use flex_grow or stretch. |

Percentage values are resolved against the **inner** dimension of the parent (after padding is removed).

### Padding

All padding values are numbers or `%` strings resolved against the relevant parent dimension.

| Property         | Description                       |
|------------------|-----------------------------------|
| `padding`        | Uniform padding on all four sides |
| `padding_left`   | Left padding (overrides `padding`) |
| `padding_right`  | Right padding                     |
| `padding_top`    | Top padding                       |
| `padding_bottom` | Bottom padding                    |

Resolution order: specific side → `padding` → 0.

### Flex Container Properties

| Property          | Values                                                        | Default    |
|-------------------|---------------------------------------------------------------|------------|
| `flex_direction`  | `"column"` / `"row"`                                         | `"column"` |
| `justify_content` | `"start"` `"center"` `"end"` `"space-between"` `"space-around"` `"space-evenly"` | `"start"` |
| `align_items`     | `"start"` `"center"` `"end"` `"stretch"`                     | `"stretch"` |
| `gap`             | number (pixels)                                               | `0`        |

### Flex Item Properties

| Property      | Type   | Default | Description                                               |
|---------------|--------|---------|-----------------------------------------------------------|
| `flex_grow`   | number | `0`     | Proportion of remaining free space this child takes       |
| `align_self`  | string | —       | Per-child override for the parent's `align_items`         |

---

## Layout Algorithm

### Step 1 — Inner box

```
inner_x = x + padding_left
inner_y = y + padding_bottom
inner_w = w - padding_left - padding_right
inner_h = h - padding_top  - padding_bottom
```

### Step 2 — Separate overlays

Children with `child._is_overlay == true` are pulled out of normal flex flow and laid out in a final overlay pass. Built-in `popup` and `bottom_sheet` primitives set this flag.

Overlay children receive the full parent bounds (`x, y, w, h`) regardless of padding or direction.

### Step 3 — Measure regular children

For each regular child:
- If the child has an explicit `width` (column) / `height` (row) → contributes to `fixed`.
- Otherwise → its `flex_grow` value contributes to `grow_sum`.

```
fixed     = sum of resolved fixed sizes + gap * (n-1)
free      = inner_main_axis - fixed
```

When `free` is negative, flex-grow distribution clamps to `max(0, free)` instead of allocating negative sizes to flex children.

### Step 4 — Justify-content offsets

When `grow_sum == 0` (no flex children), `justify_free = max(0, free)`. Otherwise `justify_free = 0` (flex children absorb the space).

| `justify_content` | `start_offset`             | `gap_extra`                           |
|-------------------|----------------------------|---------------------------------------|
| `"start"`         | 0                          | 0                                     |
| `"center"`        | `justify_free * 0.5`       | 0                                     |
| `"end"`           | `justify_free`             | 0                                     |
| `"space-between"` | 0                          | `justify_free / (n-1)` (n > 1)        |
| `"space-around"`  | `gap_extra * 0.5`          | `justify_free / n`                    |
| `"space-evenly"`  | `gap_extra`                | `justify_free / (n+1)`                |

### Step 5 — Place regular children

A `cursor` starts at `start_offset` and advances along the main axis.

**Column direction** (top-to-bottom in layout, but y-axis is bottom-up):
```
child_h = resolved height  OR  free * flex_grow / grow_sum
child_w = resolved width   OR  inner_w  (stretch)
child_y = inner_y + inner_h - cursor - child_h
child_x = inner_x  (adjusted by align_items / align_self)
cursor  += child_h + gap + gap_extra
```

**Row direction** (left-to-right):
```
child_w = resolved width   OR  free * flex_grow / grow_sum
child_h = resolved height  OR  inner_h  (stretch)
child_x = inner_x + cursor
child_y = inner_y + inner_h - child_h  (adjusted by align_items / align_self)
cursor  += child_w + gap + gap_extra
```

### Step 6 — Cross-axis alignment

Applied when a child does **not** have an explicit cross-axis size (it defaults to stretch). `align` = `child.style.align_self or parent.style.align_items or "stretch"`.

| `align`      | Column: `child_x`             | Row: `child_y`                  |
|--------------|-------------------------------|----------------------------------|
| `"start"`    | `inner_x`                     | `inner_y + inner_h - child_h`   |
| `"center"`   | `inner_x + (iw-cw)/2`         | `inner_y + (ih-ch)/2`           |
| `"end"`      | `inner_x + (iw-cw)`           | `inner_y`                       |
| `"stretch"`  | `inner_x` (cw = iw)           | `inner_y + inner_h - child_h` (ch = ih) |

### Step 7 — Overlay children

Each overlay is computed with `layout.compute(overlay, x, y, w, h)` — the **outer** bounds of the current node (before padding). This gives popups and bottom sheets full coverage.

---

## Output

After `layout.compute()`, every node (and descendant) has:

```lua
node.layout = {
  x = number,  -- left edge in layout space
  y = number,  -- bottom edge in layout space
  w = number,  -- width
  h = number,  -- height
}
```

---

## Constraints & Limitations

- **No auto/intrinsic size**: There is no content-driven size calculation. Nodes without explicit size and without `flex_grow` get a size of `0` in the main axis.
- **No wrapping**: `flex_wrap` is not implemented. All children are placed on a single line.
- **No min/max clamping**: `min_width`, `max_width`, etc. are parsed by `flow/flex.lua` but not enforced by this engine.
- **No nested percentage resolution chains**: Percentages are resolved against the immediate parent's inner dimension only.
- **No margins**: Use `gap` or `padding` instead.
- **Overflow layout is permissive**: fixed-size content may overflow the container; justify offsets clamp to non-negative free space, but children are still laid out with their resolved sizes.
