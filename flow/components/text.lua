-- flow/components/text.lua
-- Text label component for the Flow library.
-- Renders a Defold text node whose content and alignment are driven by
-- element properties. Pivot is set based on the align field:
--   "left" (default) → PIVOT_W  (text anchored to left edge of layout box)
--   "center"         → PIVOT_CENTER
--   "right"          → PIVOT_E  (text anchored to right edge of layout box)
local ui = require "flow/ui"

--- Apply a text alignment to a Defold text node by setting its pivot.
--- Called both on node creation and on every render update so that
--- alignment changes (e.g. dynamic locale switches) are reflected.
---@param node userdata            The Defold text GUI node to update
---@param align string|nil         "left", "center", or "right" (defaults to "left")
local function apply_text_alignment(node, align)
	align = align or "left"
	if align == "center" then
		gui.set_pivot(node, gui.PIVOT_CENTER)
	elseif align == "right" then
		gui.set_pivot(node, gui.PIVOT_E)
	else
		-- Default: left-aligned with PIVOT_W so the text origin is the left edge
		gui.set_pivot(node, gui.PIVOT_W)
	end
end

--- Register the "text" element type with the renderer.
ui.register("text", {
	--- Create a new Defold text GUI node for a text element.
	--- Initializes the node at origin with el.text as content (empty string fallback).
	--- Sets pivot immediately so that the first render is correctly aligned.
	---@param el Flow.TextProps  The text element; el.text and el.align are read
	---@return userdata        A new gui text node
	create_node = function(el)
		local node = gui.new_text_node(vmath.vector3(), el.text or "")
		apply_text_alignment(node, el.align)
		return node
	end,

	--- Update the text content and alignment of an existing node each frame.
	--- Only called when the element is visible; the renderer skips invisible elements.
	---@param _ table          The gui_script self table (unused)
	---@param el Flow.TextProps  The text element providing new text and align values
	---@param node userdata    The existing Defold text node to update
	apply = function(_, el, node)
		apply_text_alignment(node, el.align)
		gui.set_text(node, el.text or "")
	end,

	--- Tell the renderer that this text element uses a left-anchored pivot (PIVOT_W).
	--- When true, the renderer places the node at (layout.x, layout.y + h/2) instead of
	--- the normal center-origin position, so the text renders inside the layout box.
	---@param el Flow.TextProps  The text element
	---@return boolean         True when el.align is nil or "left"
	is_left_aligned = function(el)
		return el.align == nil or el.align == "left"
	end,
})

--- Create a text element.
--- Renders a Defold text node positioned by the flex layout engine.
--- The text content is updated every frame from el.text, so you can change
--- it dynamically by mutating the element and calling nav.invalidate().
---@param t Flow.TextProps        Element definition table (mutated in place)
---@return Flow.Element           The same table with type set to "text"
local function Text(t)
	t.type = "text"
	return t
end

return Text
