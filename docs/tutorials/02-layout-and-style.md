# Tutorial 2 — Layout & Style

Flow's layout engine is a subset of CSS Flexbox. If you know Flexbox, most of this will feel familiar. If you don't, this tutorial covers everything you need.

---

## The Box Model

Every element has:

```
┌─────────────────────────────┐
│           padding           │
│   ┌─────────────────────┐   │
│   │      content        │   │
│   └─────────────────────┘   │
└─────────────────────────────┘
```

- `width` / `height` — the **outer** dimensions of the element.
- `padding` — inset from outer edges to content area.
- There are no margins. Use `gap` on the parent instead.

---

## Sizing

### Fixed sizes

```lua
style = { width = 200, height = 50 }
```

### Percentage sizes

Percentages resolve against the parent's **inner** dimension (after its padding).

```lua
style = { width = "100%", height = "50%" }
```

### Flexible sizes

`flex_grow` distributes remaining free space among siblings that declare it.

```lua
-- Two siblings share the remaining height equally:
Box({ key = "a", style = { flex_grow = 1 } })
Box({ key = "b", style = { flex_grow = 1 } })

-- One sibling takes twice as much:
Box({ key = "a", style = { flex_grow = 2 } })
Box({ key = "b", style = { flex_grow = 1 } })
```

A child with no explicit size and no `flex_grow` gets a size of **0** in the main axis.

---

## Flex Direction

`flex_direction` controls which axis children are stacked along.

### Column (default)

Children stack **top-to-bottom**. Main axis = vertical.

```lua
style = { flex_direction = "column" }
```

```
┌──────────┐
│ child A  │
├──────────┤
│ child B  │
├──────────┤
│ child C  │
└──────────┘
```

### Row

Children stack **left-to-right**. Main axis = horizontal.

```lua
style = { flex_direction = "row" }
```

```
┌────────┬────────┬────────┐
│child A │child B │child C │
└────────┴────────┴────────┘
```

---

## Gap

`gap` adds uniform space **between** children (not before the first or after the last).

```lua
style = { flex_direction = "column", gap = 16 }
```

---

## Padding

```lua
style = { padding = 20 }                       -- all four sides
style = { padding_left = 16, padding_right = 16 } -- specific sides
style = { padding_top = 8, padding_bottom = 8 }
```

Per-side values override `padding` when both are set.

---

## Justify Content

`justify_content` controls distribution along the **main axis** (the stacking direction).

```lua
style = { flex_direction = "column", justify_content = "center" }
```

| Value | Effect |
|-------|--------|
| `"start"` (default) | Pack children at the beginning |
| `"end"` | Pack children at the end |
| `"center"` | Center children as a group |
| `"space-between"` | Equal gaps between children, none at edges |
| `"space-around"` | Equal gaps around each child (half-gap at edges) |
| `"space-evenly"` | Equal gaps everywhere including edges |

`justify_content` only takes effect when there is free space — i.e., when children don't fill the container. If any child has `flex_grow`, it absorbs the free space first and `justify_content` has no effect.

---

## Align Items

`align_items` controls alignment on the **cross axis** (perpendicular to stacking direction).

```lua
style = { flex_direction = "column", align_items = "center" }
```

| Value | Column (cross = horizontal) | Row (cross = vertical) |
|-------|-----------------------------|------------------------|
| `"stretch"` (default) | Child fills full width | Child fills full height |
| `"start"` | Child hugs left edge | Child hugs top edge |
| `"center"` | Child centered horizontally | Child centered vertically |
| `"end"` | Child hugs right edge | Child hugs bottom edge |

### Per-child override

Use `align_self` on a child to override the parent's `align_items` for that one child:

```lua
Box({ key = "outlier", style = { align_self = "end", height = 40 } })
```

---

## Common Patterns

### Full-screen container

```lua
style = { width = "100%", height = "100%" }
```

### Centered dialog

```lua
-- Parent: full screen
style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" }

-- Child: fixed-size card
style = { width = 320, height = 200 }
```

### Horizontal toolbar

```lua
style = { flex_direction = "row", height = 56, align_items = "center", padding = 12, gap = 8 }
```

### Sidebar + content area

```lua
-- Outer row
style = { flex_direction = "row", width = "100%", height = "100%" }
children = {
  -- Fixed sidebar
  Box({ key = "sidebar", style = { width = 200 } }),
  -- Flexible content fills remainder
  Box({ key = "content", style = { flex_grow = 1 } }),
}
```

### Header + scrollable body + footer

```lua
style = { flex_direction = "column", width = "100%", height = "100%" }
children = {
  Box({ key = "header", style = { height = 56 } }),
  Scroll({ key = "body", style = { flex_grow = 1 } }), -- stretches to fill
  Box({ key = "footer", style = { height = 48 } }),
}
```

---

## What Is Not Supported

| Feature | Status |
|---------|--------|
| `flex_wrap` | Not implemented (single line only) |
| `min_width` / `max_width` | Stored by `flex.lua` API, not enforced by layout engine |
| Margins | Not implemented; use `gap` or `padding` |
| Auto / intrinsic height | Not implemented; always provide explicit `height` |
| Nested percentage chains | Percentages resolve against immediate parent only |

---

## Next

[Tutorial 3 — Navigation](03-navigation.md): register multiple screens and navigate between them with push/pop and animated transitions.
