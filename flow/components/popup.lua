-- flow/components/popup.lua
-- Modal overlay popup component for the Flow library.
-- Renders as a full-screen semi-transparent backdrop over all other content.
-- It does not participate in the parent's normal flex flow: as an overlay child
-- it is always laid out at its parent's full bounds regardless of sibling flow.
-- Its own children are still laid out using the popup's style properties.
-- Clicking the backdrop (not the content children) fires on_backdrop_click.
local ui = require "flow/ui"

--- Register the "popup" element type with the renderer.
ui.register("popup", {
	--- Create a new Defold box GUI node for the popup backdrop.
	---@param _ Flow.Element  The popup element being instantiated (unused here)
	---@return userdata       A new gui box node used as the full-screen backdrop
	create_node = function(_)
		return gui.new_box_node(vmath.vector3(), vmath.vector3(10, 10, 0))
	end,

	--- Marks this element as a backdrop-click target.
	--- When the user taps the backdrop node (not a child), input_core checks
	--- is_backdrop_click_target and fires on_backdrop_click on the element.
	is_backdrop_click_target = true,

	--- Apply the backdrop color to the GUI node each frame.
	--- Alpha is multiplied by the accumulated parent alpha for transition fading.
	---@param self table           The gui_script self table with a mounted renderer
	---@param el Flow.PopupProps  The popup element (reads el.backdrop_color)
	---@param node userdata        The backdrop GUI node to color
	---@param alpha number         Accumulated alpha from parent transitions [0..1]
	apply = function(self, el, node, alpha)
		local c = el._backdrop_color
		self.ui._set_node_color(node, c.x, c.y, c.z, c.w * alpha)
	end,
})

--- Create a popup element.
--- The popup covers its parent's full bounds as an overlay (does not flex-flow).
--- Content children are positioned by the popup's own style (use align_items/justify_content
--- to center a dialog box). The backdrop color fills the entire popup area.
---
--- IMPORTANT: content child boxes must have an explicit height in their style —
--- the layout system cannot calculate intrinsic/auto heights.
---@param t Flow.PopupProps       Element definition table (mutated in place)
---@return Flow.Element           The table with type = "popup", _is_overlay = true, _visible set
local function Popup(t)
	t.type = "popup"
	-- _is_overlay = true causes layout.lua to skip this element in the flex pass
	-- and lay it out at full parent bounds in a separate overlay pass.
	t._is_overlay = true
	t._visible = t._visible ~= false
	t.backdrop_color = t.backdrop_color or "#000000b3"
	return t
end

return Popup
