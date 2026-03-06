-- flow/components/box.lua
-- Box component for the Flow library.
-- A box is the basic building block: a rectangular GUI node that participates
-- in flex layout and can have a background color and child elements.
-- Higher-level components often return nested box trees, but `box` itself is
-- just the plain rectangular container primitive.
local ui = require "flow/ui"

--- Register the "box" element type with the renderer.
--- create_node: creates a plain box GUI node at (0,0) with a 10×10 placeholder size.
--- The renderer overwrites position and size every frame from layout data.
ui.register("box", {
	--- Create a new Defold box GUI node for a box element.
	--- Position and size are set to placeholders; the renderer applies final values.
	---@param el Flow.Element   The box element being instantiated (unused here)
	---@return userdata        A new gui box node
	create_node = function(el)
		local node = gui.new_box_node(vmath.vector3(), vmath.vector3(10, 10, 0))
		if gui.set_size_mode and gui.SIZE_MODE_MANUAL then
			gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
		end
		if el and el._clips_children then
			gui.set_clipping_mode(node, gui.CLIPPING_MODE_STENCIL)
			gui.set_clipping_visible(node, el._clipping_visible ~= false)
			gui.set_clipping_inverted(node, false)
		end
		return node
	end,
})

--- Create a box element.
--- A box is a rectangular container that participates in flex layout.
--- Set style.flex_direction to control whether children flow in a column (default) or row.
--- Set color to render a solid background; omit for a transparent/invisible container.
---@param t Flow.BoxProps         Element definition table (mutated in place by type = "box")
---@return Flow.Element           The same table with type set to "box"
local function Box(t)
	t.type = "box"
	return t
end

return Box
