-- flow/flex.lua
-- Flex API — flexbox-compatible Node class and constants for the Flow library.
-- Provides a fluent, object-oriented alternative to plain Lua table style definitions.
-- The current layout engine consumes only a subset of these style fields
-- (width/height, flex_direction, flex_grow, align_items, align_self,
-- justify_content, gap, and padding). Other setters are preserved as stored
-- style fields for API compatibility and future expansion.
--
-- Usage:
--   local Flex = require "flow/flex"
--   local node = Flex.Node.new({ key = "root" })
--     :set_flex_direction(Flex.FLEX_DIRECTION_ROW)
--     :set_justify_content(Flex.JUSTIFY_CENTER)
--     :set_width(300)
--     :set_height(100)
--     :calculate_layout(960, 640)
--   print(node:get_computed_width())  --> 300
local layout = require "flow/layout"

local FL = {}

-- ─── flex_direction ──────────────────────────────────────────────────────────
--- Children are stacked top-to-bottom (default).
FL.FLEX_DIRECTION_COLUMN = "column"
--- Children are arranged left-to-right.
FL.FLEX_DIRECTION_ROW    = "row"

-- ─── justify_content (main-axis alignment) ───────────────────────────────────
--- Children packed toward the start of the main axis.
FL.JUSTIFY_FLEX_START    = "start"
--- Children centered along the main axis.
FL.JUSTIFY_CENTER        = "center"
--- Children packed toward the end of the main axis.
FL.JUSTIFY_FLEX_END      = "end"
--- Children distributed with equal space between them; first and last touch the edges.
FL.JUSTIFY_SPACE_BETWEEN = "space-between"
--- Children distributed with equal space around each child.
FL.JUSTIFY_SPACE_AROUND  = "space-around"
--- Children distributed with equal space between and around all children.
FL.JUSTIFY_SPACE_EVENLY  = "space-evenly"

-- ─── align_items / align_self (cross-axis alignment) ─────────────────────────
--- Inherit alignment from parent (align_self only).
FL.ALIGN_AUTO       = "auto"
--- Children packed at the cross-axis start.
FL.ALIGN_FLEX_START = "start"
--- Children centered on the cross axis.
FL.ALIGN_CENTER     = "center"
--- Children packed at the cross-axis end.
FL.ALIGN_FLEX_END   = "end"
--- Children stretched to fill the cross-axis dimension (default).
FL.ALIGN_STRETCH    = "stretch"

-- ─── edge constants (for set_padding, set_margin, set_border, set_position) ──
--- Apply to the left edge.
FL.EDGE_LEFT       = "left"
--- Apply to the top edge.
FL.EDGE_TOP        = "top"
--- Apply to the right edge.
FL.EDGE_RIGHT      = "right"
--- Apply to the bottom edge.
FL.EDGE_BOTTOM     = "bottom"
--- Apply to all four edges at once.
FL.EDGE_ALL        = "all"
--- Apply to left and right edges simultaneously.
FL.EDGE_HORIZONTAL = "horizontal"
--- Apply to top and bottom edges simultaneously.
FL.EDGE_VERTICAL   = "vertical"
--- Logical start edge (left in LTR, right in RTL).
FL.EDGE_START      = "start"
--- Logical end edge (right in LTR, left in RTL).
FL.EDGE_END        = "end"

-- ─── display ─────────────────────────────────────────────────────────────────
--- Standard flex layout (default).
FL.DISPLAY_FLEX = "flex"
--- Element is hidden and takes no space.
FL.DISPLAY_NONE = "none"

-- ─── overflow ────────────────────────────────────────────────────────────────
--- Children may overflow the container (default).
FL.OVERFLOW_VISIBLE = "visible"
--- Children are clipped to the container bounds.
FL.OVERFLOW_HIDDEN  = "hidden"
--- Container is scrollable (use the Scroll component for full behavior).
FL.OVERFLOW_SCROLL  = "scroll"

-- ─── flex_wrap ───────────────────────────────────────────────────────────────
--- All children stay on one line (default).
FL.WRAP_NO_WRAP      = "no-wrap"
--- Children wrap to additional lines.
FL.WRAP_WRAP         = "wrap"
--- Children wrap in reverse.
FL.WRAP_WRAP_REVERSE = "wrap-reverse"

-- ─── position_type ───────────────────────────────────────────────────────────
--- Positioned in the normal flow (default).
FL.POSITION_TYPE_STATIC   = "static"
--- Offset from normal position without leaving the flow.
FL.POSITION_TYPE_RELATIVE = "relative"
--- Removed from flow; positioned relative to container.
FL.POSITION_TYPE_ABSOLUTE = "absolute"

-- ─── direction ───────────────────────────────────────────────────────────────
--- Inherit text direction from parent.
FL.DIRECTION_INHERIT = "inherit"
--- Left-to-right text direction.
FL.DIRECTION_LTR     = "ltr"
--- Right-to-left text direction.
FL.DIRECTION_RTL     = "rtl"

-- ─── Node class ──────────────────────────────────────────────────────────────

local Node = {}
Node.__index = Node

--- Format a number as a percentage string for use in style width/height fields.
--- Example: to_percent(50) → "50%"
---@param value number   The percentage value (0..100)
---@return string        The percentage string (e.g. "50%")
local function to_percent(value)
	return tostring(value) .. "%"
end

--- Resolve a root layout dimension fallback.
--- Percentage strings cannot be resolved without an explicit parent size, so
--- only numeric style width/height values are used here.
---@param value number|string|nil
---@return number
local function resolve_root_dimension(value)
	return type(value) == "number" and value or 0
end

--- Set a padding, margin, border, or position value on a specific edge.
--- Handles all EDGE_* constants including compound edges (HORIZONTAL, VERTICAL, ALL).
---@param style table          The style table to mutate
---@param prefix string        Field prefix: "padding", "margin", "border", or "position"
---@param edge string          One of the FL.EDGE_* constants
---@param value number|string  The value to apply (pixels or percentage string)
local function set_edge(style, prefix, edge, value)
	if edge == FL.EDGE_ALL then
		style[prefix] = value
	elseif edge == FL.EDGE_LEFT then
		style[prefix .. "_left"] = value
	elseif edge == FL.EDGE_RIGHT then
		style[prefix .. "_right"] = value
	elseif edge == FL.EDGE_TOP then
		style[prefix .. "_top"] = value
	elseif edge == FL.EDGE_BOTTOM then
		style[prefix .. "_bottom"] = value
	elseif edge == FL.EDGE_HORIZONTAL then
		style[prefix .. "_left"] = value
		style[prefix .. "_right"] = value
	elseif edge == FL.EDGE_VERTICAL then
		style[prefix .. "_top"] = value
		style[prefix .. "_bottom"] = value
	elseif edge == FL.EDGE_START then
		style[prefix .. "_start"] = value
	elseif edge == FL.EDGE_END then
		style[prefix .. "_end"] = value
	end
end

--- Create a new FlexNode with initial properties.
--- All fields have sensible defaults; only key is typically required.
---@param opts Flow.FlexNodeOptions|nil  Initial properties
---@return Flow.FlexNode         A new node with the given properties
function Node.new(opts)
	opts = opts or {}
	return setmetatable({
		key = opts.key,
		type = opts.type or "box",
		color = opts.color,
		style = opts.style or {},
		children = opts.children or {},
		layout = nil,
	}, Node)
end

--- Insert a child node at a given index (1-based, default = append).
--- Chainable — returns self.
---@param child Flow.FlexNode   The child node to insert
---@param index number|nil      1-based insertion index; default appends after last child
---@return Flow.FlexNode        self
function Node:insert_child(child, index)
	table.insert(self.children, index or (#self.children + 1), child)
	return self
end

--- Remove a child node by reference. No-op when child is not found.
--- Chainable — returns self.
---@param child Flow.FlexNode   The child node to remove (matched by reference)
---@return Flow.FlexNode        self
function Node:remove_child(child)
	for i = #self.children, 1, -1 do
		if self.children[i] == child then
			table.remove(self.children, i)
			break
		end
	end
	return self
end

--- Return the child at a 0-based index (Yoga API convention).
--- Index 0 returns the first child.
---@param index number  0-based child index
---@return Flow.FlexNode|nil  The child at that index, or nil
function Node:get_child(index)
	return self.children[index + 1]
end

--- Return the total number of children.
---@return number  Child count
function Node:get_child_count()
	return #self.children
end

--- Set an arbitrary style property by key. Chainable.
---@param key string     The style field name (e.g. "flex_direction")
---@param value any      The value to assign
---@return Flow.FlexNode self
function Node:set_style(key, value)
	self.style[key] = value
	return self
end

--- Read an arbitrary style property by key.
---@param key string     The style field name
---@return any           The current value, or nil if not set
function Node:get_style(key)
	return self.style[key]
end

--- Set the fixed width in pixels. Chainable.
---@param value number   Width in pixels
---@return Flow.FlexNode self
function Node:set_width(value) self.style.width = value; return self end

--- Set the fixed height in pixels. Chainable.
---@param value number   Height in pixels
---@return Flow.FlexNode self
function Node:set_height(value) self.style.height = value; return self end

--- Set the width as a percentage of the parent's width. Chainable.
---@param value number   Width percentage (0..100)
---@return Flow.FlexNode self
function Node:set_width_percent(value) self.style.width = to_percent(value); return self end

--- Set the height as a percentage of the parent's height. Chainable.
---@param value number   Height percentage (0..100)
---@return Flow.FlexNode self
function Node:set_height_percent(value) self.style.height = to_percent(value); return self end

--- Store a minimum width constraint in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not enforce it.
---@param value number   Minimum width in pixels
---@return Flow.FlexNode self
function Node:set_min_width(value) self.style.min_width = value; return self end

--- Store a minimum height constraint in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not enforce it.
---@param value number   Minimum height in pixels
---@return Flow.FlexNode self
function Node:set_min_height(value) self.style.min_height = value; return self end

--- Store a maximum width constraint in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not enforce it.
---@param value number   Maximum width in pixels
---@return Flow.FlexNode self
function Node:set_max_width(value) self.style.max_width = value; return self end

--- Store a maximum height constraint in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not enforce it.
---@param value number   Maximum height in pixels
---@return Flow.FlexNode self
function Node:set_max_height(value) self.style.max_height = value; return self end

--- Set the main-axis direction for children. Chainable.
---@param value "column"|"row"  Use FLEX_DIRECTION_* constants
---@return Flow.FlexNode        self
function Node:set_flex_direction(value) self.style.flex_direction = value; return self end

--- Set how much this node grows to fill available space on the main axis. Chainable.
---@param value number   Growth factor (0 = no growth, 1 = equal share, >1 = larger share)
---@return Flow.FlexNode self
function Node:set_flex_grow(value) self.style.flex_grow = value; return self end

--- Store the flex shrink factor. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value number   Shrink factor (default 1; 0 = do not shrink)
---@return Flow.FlexNode self
function Node:set_flex_shrink(value) self.style.flex_shrink = value; return self end

--- Store the flex basis value. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value number|string  Size in pixels or percentage string
---@return Flow.FlexNode       self
function Node:set_flex_basis(value) self.style.flex_basis = value; return self end

--- Set how children are distributed along the main axis. Chainable.
---@param value string   Use JUSTIFY_* constants
---@return Flow.FlexNode self
function Node:set_justify_content(value) self.style.justify_content = value; return self end

--- Set how children are aligned on the cross axis. Chainable.
---@param value string   Use ALIGN_* constants
---@return Flow.FlexNode self
function Node:set_align_items(value) self.style.align_items = value; return self end

--- Override the parent's align_items for this node only. Chainable.
---@param value string   Use ALIGN_* constants
---@return Flow.FlexNode self
function Node:set_align_self(value) self.style.align_self = value; return self end

--- Set the gap between children in pixels. Chainable.
---@param value number   Gap size in pixels
---@return Flow.FlexNode self
function Node:set_gap(value) self.style.gap = value; return self end

--- Set padding on one or more edges. Chainable.
---@param edge string    Use EDGE_* constants (EDGE_ALL sets uniform padding)
---@param value number   Padding in pixels
---@return Flow.FlexNode self
function Node:set_padding(edge, value)
	set_edge(self.style, "padding", edge, value)
	return self
end

--- Set padding on one or more edges as a percentage of parent size. Chainable.
---@param edge string    Use EDGE_* constants
---@param value number   Padding as percentage (0..100)
---@return Flow.FlexNode self
function Node:set_padding_percent(edge, value)
	set_edge(self.style, "padding", edge, to_percent(value))
	return self
end

--- Store margin on one or more edges in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param edge string    Use EDGE_* constants
---@param value number   Margin in pixels
---@return Flow.FlexNode self
function Node:set_margin(edge, value)
	set_edge(self.style, "margin", edge, value)
	return self
end

--- Store margin on one or more edges as a percentage of parent size. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param edge string    Use EDGE_* constants
---@param value number   Margin as percentage (0..100)
---@return Flow.FlexNode self
function Node:set_margin_percent(edge, value)
	set_edge(self.style, "margin", edge, to_percent(value))
	return self
end

--- Store border width on one or more edges in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param edge string    Use EDGE_* constants
---@param value number   Border width in pixels
---@return Flow.FlexNode self
function Node:set_border(edge, value)
	set_edge(self.style, "border", edge, value)
	return self
end

--- Store position offsets on one or more edges in pixels. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param edge string    Use EDGE_* constants
---@param value number   Position offset in pixels
---@return Flow.FlexNode self
function Node:set_position(edge, value)
	set_edge(self.style, "position", edge, value)
	return self
end

--- Store the position type (static / relative / absolute). Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value string   Use POSITION_TYPE_* constants
---@return Flow.FlexNode self
function Node:set_position_type(value)
	self.style.position_type = value
	return self
end

--- Store the flex wrap behavior. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value string   Use WRAP_* constants
---@return Flow.FlexNode self
function Node:set_flex_wrap(value)
	self.style.flex_wrap = value
	return self
end

--- Store the overflow behavior. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value string   Use OVERFLOW_* constants
---@return Flow.FlexNode self
function Node:set_overflow(value)
	self.style.overflow = value
	return self
end

--- Store the display mode. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value string   Use DISPLAY_FLEX or DISPLAY_NONE
---@return Flow.FlexNode self
function Node:set_display(value)
	self.style.display = value
	return self
end

--- Store the aspect ratio (width / height). Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value number   Desired width-to-height ratio (e.g. 16/9)
---@return Flow.FlexNode self
function Node:set_aspect_ratio(value)
	self.style.aspect_ratio = value
	return self
end

--- Store the text direction for this subtree. Chainable.
--- Kept for API compatibility; the current layout engine does not consume it.
---@param value string   Use DIRECTION_* constants
---@return Flow.FlexNode self
function Node:set_direction(value)
	self.style.direction = value
	return self
end

--- Attach a custom measure function to this node.
--- The measure function is called by the layout engine to determine intrinsic
--- content size (e.g. for text or image elements). Not used by the default
--- flow/layout.lua but reserved for compatibility with future extensions.
---@param fn function  Returns measured width and height
---@return Flow.FlexNode self
function Node:set_measure_func(fn)
	self.measure = fn
	return self
end

--- Run the layout engine on this node tree and store results in node.layout.
--- After calling this, use get_computed_* or get_layout() to read the results.
---@param width number|nil    Available width in pixels (falls back to numeric style.width or 0)
---@param height number|nil   Available height in pixels (falls back to numeric style.height or 0)
---@return Flow.FlexNode      self (for chaining or immediate result reading)
function Node:calculate_layout(width, height)
	layout.compute(
		self,
		0,
		0,
		width or resolve_root_dimension(self.style.width),
		height or resolve_root_dimension(self.style.height)
	)
	return self
end

--- Return the full layout result table ({x, y, w, h}) after calculate_layout().
---@return Flow.LayoutRect|nil  The computed layout, or nil if not yet calculated
function Node:get_layout()
	return self.layout
end

--- Return the computed left edge (x) of this node in layout space.
---@return number  The x coordinate, or 0 if layout has not been computed
function Node:get_computed_left()
	return self.layout and self.layout.x or 0
end

--- Return the computed top edge (y + h) of this node in layout space.
--- Note: layout uses bottom-left origin, so "top" = y + height.
---@return number  The top coordinate, or 0 if layout has not been computed
function Node:get_computed_top()
	return self.layout and (self.layout.y + self.layout.h) or 0
end

--- Return the computed width of this node in pixels.
---@return number  Width in pixels, or 0 if layout has not been computed
function Node:get_computed_width()
	return self.layout and self.layout.w or 0
end

--- Return the computed height of this node in pixels.
---@return number  Height in pixels, or 0 if layout has not been computed
function Node:get_computed_height()
	return self.layout and self.layout.h or 0
end

FL.Node = Node

--- Run the layout engine on a node tree without creating a Node instance.
--- Convenience function for callers using plain Lua table element trees.
---@param root Flow.Element      The root element tree to compute layout for
---@param width number|nil       Available width (falls back to numeric root.style.width or 0)
---@param height number|nil      Available height (falls back to numeric root.style.height or 0)
---@return Flow.Element          The root element (layout written to root.layout and descendants)
function FL.calculate_layout(root, width, height)
	local style = root.style or {}
	layout.compute(
		root,
		0,
		0,
		width or resolve_root_dimension(style.width),
		height or resolve_root_dimension(style.height)
	)
	return root
end

return FL
