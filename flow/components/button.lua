-- flow/components/button.lua
-- Interactive button component for the Flow library.
-- A button is a box node that responds to press/release input events.
-- Press visual feedback is applied immediately (darkened color on press_begin);
-- the on_click callback fires only when the touch is released over the same button
-- that was pressed (standard mobile tap behavior).
--
-- Buttons capture descendant hits: any touch starting inside a button's children
-- is treated as a button press, not a child element press.
local ui = require "flow/ui"
local SLICE9 = vmath.vector4()
local SCALE_NORMAL = vmath.vector3(1, 1, 1)
local SCALE_HOVER = vmath.vector3(1.03, 1.03, 1)

---@param border number|{left?: number, top?: number, right?: number, bottom?: number}|nil
---@return vector4|nil
local function resolve_slice9(border)
	if border == nil then
		return nil
	end

	if type(border) == "number" then
		SLICE9.x = border
		SLICE9.y = border
		SLICE9.z = border
		SLICE9.w = border
		return SLICE9
	end

	if type(border) == "table" then
		SLICE9.x = border.left or 0
		SLICE9.y = border.top or 0
		SLICE9.z = border.right or 0
		SLICE9.w = border.bottom or 0
		return SLICE9
	end

	return nil
end

--- Apply the current button visual state to the backing GUI node.
--- Hover only affects scale. Press only affects color.
---@param self table               The gui_script self table with a mounted renderer
---@param el Flow.ButtonProps      The button element (reads color/pressed/hover state)
local function apply_button_visual(self, el)
	local cache_key = el._cache_key or el.key
	local node = self.ui.nodes[cache_key]
	if not node then return end
	local is_active_press = self.ui and self.ui._pressed_element == el
	local is_hovered = el._hovered or (is_active_press and el._pressed)

	if gui.set_scale then
		gui.set_scale(node, is_hovered and SCALE_HOVER or SCALE_NORMAL)
	end

	if is_active_press and el._pressed then
		local c = el._pressed_color or el._color
		if c then
			self.ui._set_node_color(node, c.x * 0.7, c.y * 0.7, c.z * 0.7, c.w)
		elseif el.image then
			self.ui._set_node_color(node, 0.7, 0.7, 0.7, 1)
		end
	elseif is_active_press then
		if el._color then
			local c = el._color
			self.ui._set_node_color(node, c.x, c.y, c.z, c.w)
		elseif el.image then
			self.ui._set_node_color(node, 1, 1, 1, 1)
		end
	elseif el._color then
		local c = el._color
		self.ui._set_node_color(node, c.x, c.y, c.z, c.w)
	elseif el.image then
		self.ui._set_node_color(node, 1, 1, 1, 1)
	end
end

--- Register the "button" element type with the renderer.
ui.register("button", {
	--- Create a new Defold box GUI node for a button element.
	---@param _ Flow.Element  The button element being instantiated (unused here)
	---@return userdata       A new gui box node
	create_node = function(_)
		local node = gui.new_box_node(vmath.vector3(), vmath.vector3(10, 10, 0))
		if gui.set_size_mode and gui.SIZE_MODE_MANUAL then
			gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
		end
		return node
	end,

	---@param _ table
	---@param el Flow.ButtonProps
	---@param node userdata
	apply = function(_, el, node)
		if el.image then
			gui.set_texture(node, el.texture or "icons")
			gui.play_flipbook(node, hash(el.image))
			if gui.set_slice9 then
				local slice9 = resolve_slice9(el.border)
				if slice9 then
					gui.set_slice9(node, slice9)
				else
					SLICE9.x = 0
					SLICE9.y = 0
					SLICE9.z = 0
					SLICE9.w = 0
					gui.set_slice9(node, SLICE9)
				end
			end
		end
		apply_button_visual(_, el)
	end,

	--- When true, a hit on any child element is captured and returned as a hit
	--- on this button. This ensures child text/icon labels don't block button taps.
	capture_descendant_hits = true,

	--- Called when a touch press begins on this button.
	--- Sets _pressed = true and applies the pressed (darkened) visual state.
	---@param self table           The gui_script self table with a mounted renderer
	---@param el Flow.ButtonProps  The button element being pressed
	press_begin = function(self, el)
		el._pressed = true
		apply_button_visual(self, el)
	end,

	--- Called each frame while a press is active (touch move).
	--- Updates visual to pressed when the touch is still over the button (is_hot),
	--- and to released when the touch moves outside.
	---@param self table           The gui_script self table with a mounted renderer
	---@param el Flow.ButtonProps  The button element being tracked
	---@param is_hot boolean       True when the current touch position is still over this button
	press_update = function(self, el, is_hot)
		el._pressed = is_hot
		apply_button_visual(self, el)
	end,

	--- Called when the touch is released.
	--- Restores the released visual state, clears _pressed, and fires on_click
	--- only when activated (released over the same button that was pressed).
	---@param self table           The gui_script self table with a mounted renderer
	---@param el Flow.ButtonProps  The button element being released
	---@param activated boolean    True when the release occurred over this button
	press_end = function(self, el, activated)
		el._pressed = false
		apply_button_visual(self, el)
		if activated and el.on_click then
			el.on_click(el)
		end
	end,

	---@param self table
	---@param el Flow.ButtonProps
	hover_begin = function(self, el)
		el._hovered = true
		apply_button_visual(self, el)
	end,

	---@param self table
	---@param el Flow.ButtonProps
	hover_end = function(self, el)
		el._hovered = false
		apply_button_visual(self, el)
	end,
})

--- Create a button element.
--- Buttons capture input and fire on_click when tapped. Press visual feedback
--- (darkened color) is applied automatically between press_begin and press_end.
--- When the pointer moves over a button without pressing, the node scales up
--- slightly and returns to normal size on hover end.
---@param t Flow.ButtonProps      Element definition table (mutated in place)
---@return Flow.Element           The same table with type = "button" and interaction state flags reset
local function Button(t)
	t.type = "button"
	t._pressed = false
	t._hovered = false
	if t.image and t.color == nil then
		t.color = "#ffffff"
	end
	return t
end

return Button
