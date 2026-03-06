# markdown.lua — Markdown Component

Primary module: `flow/components/markdown.lua`

The markdown module is now a composite component. It builds a scrollable tree out of standard primitives (`Box`, `Text`, `Scroll`) rather than extending the renderer.
Preferred access in app code is through `require "flow/flow"` and `flow.ui.cp.Markdown`.

## API

### `Markdown(opts)`

Preferred API:

```lua
local flow = require "flow/flow"
local Markdown = flow.ui.cp.Markdown

local viewer = Markdown({
  key = "docs",
  text = my_text,
  style = { flex_grow = 1 },
})
```

Fields:

- `key`: root key for the scroll container
- `text`: markdown source
- `style`: scroll container style override
- `_scrollbar`: defaults to `true`
- `_bounce`: defaults to `true`
- `_momentum`: defaults to `true`

### `Markdown.parse(text, key_prefix)`

Returns an array of rendered element subtrees.

```lua
local Markdown = require "flow/components/markdown"
local elements = Markdown.parse(my_text, "guide")
```

### `Markdown.viewer(text, key, style_override)`

Convenience wrapper around `Markdown({ ... })`.

```lua
local Markdown = require "flow/components/markdown"
local viewer = Markdown.viewer(my_text, "docs", { padding = 10 })
```

## Rendering Model

Markdown returns a `Scroll` root whose children are built from primitive components.

Supported block types:

- headings
- horizontal rules
- bullet lists
- numbered lists
- blockquotes
- fenced code blocks
- atlas-backed images
- image placeholders
- paragraphs
- blank-line spacers

Supported inline formatting:

- bold via `**text**`
- inline code via `` `code` ``

Behavior details:

- blank lines are preserved and emitted as transparent spacer rows
- fenced code blocks accumulate raw inner lines and emit a single dark code box on closing fence
- bold is rendered as a highlighted background span; it does not switch Defold font weight
- `![alt](icon:icon_star)` renders a real image using the default `icons` GUI texture
- `![alt](atlas:texture_name:image_name)` renders a real image using an explicit GUI texture
- atlas images accept inline modifiers after `|`, for example:
  `![alt](atlas:guide:castle_siege|width=80%|height=220|scale=fit|aspect=634:768)`
- supported modifiers are `width=`, `height=`, `scale=stretch|fit`, and `aspect=` / `ratio=`
- `fit` uses the provided aspect ratio; without `aspect`, it falls back to the stretched box size
- other image URLs still render a placeholder box
- image URLs may include a `color:r,g,b` hint to tint the placeholder

## Keys

Generated child keys are namespaced under the component key or explicit parse prefix, so multiple markdown viewers can coexist without collisions.

The outer viewer uses the same `key` as the `Scroll` root, and parsed descendants derive stable line-based keys from it.

## Viewer Defaults

The viewer starts from this default scroll style:

- `flex_grow = 1`
- `flex_direction = "column"`
- `gap = 5`
- `padding = 20`

Style overrides are copied into a fresh table per viewer call, so one markdown instance does not mutate another instance's defaults.

## Limitations

- Fixed-height rows; no intrinsic text measurement
- No wrapping for long lines
- Width estimation uses `8 * #text`
- No nested formatting parser
- No tables
- No file-path or remote image loading; real images must come from a GUI texture/atlas already registered in the `.gui`
- No link interaction yet
- Unclosed fenced code blocks do not emit a block at EOF; only closed fences produce output
