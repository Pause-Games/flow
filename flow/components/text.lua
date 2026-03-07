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

--- Apply the configured Defold GUI font, falling back to the scene's default font.
--- This is called on creation and every render so runtime font changes take effect.
---@param node userdata            The Defold text GUI node to update
---@param font string|nil          Registered GUI font name; falls back to "default"
local function apply_text_font(node, font)
	gui.set_font(node, font or "default")
end

--- Register the "text" element type with the renderer.
ui.register("text", {
	--- Create a new Defold text GUI node for a text element.
	--- Initializes the node at origin with el.text as content (empty string fallback).
	--- Sets pivot and font immediately so that the first render is correctly aligned.
	---@param el Flow.TextProps  The text element; el.text, el.align, and el.font are read
	---@return userdata        A new gui text node
	create_node = function(el)
		local node = gui.new_text_node(vmath.vector3(), el.text or "")
		apply_text_alignment(node, el.align)
		apply_text_font(node, el.font)
		return node
	end,

	--- Update the text content, alignment, and font of an existing node each frame.
	--- Only called when the element is visible; the renderer skips invisible elements.
	---@param _ table          The gui_script self table (unused)
	---@param el Flow.TextProps  The text element providing new text, align, and font values
	---@param node userdata    The existing Defold text node to update
	apply = function(_, el, node)
		apply_text_alignment(node, el.align)
		apply_text_font(node, el.font)
		gui.set_text(node, el.text or "")
	end,

	--- Tell the renderer which horizontal anchor to use for text positioning.
	--- The renderer matches the GUI pivot:
	---   left   -> layout.x
	---   center -> layout.x + layout.w / 2
	---   right  -> layout.x + layout.w
	---@param el Flow.TextProps  The text element
	---@return "left"|"center"|"right"
	get_text_anchor = function(el)
		return el.align or "left"
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
