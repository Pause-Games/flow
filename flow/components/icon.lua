-- flow/components/icon.lua
-- Atlas-based icon component for the Flow library.
-- Renders a GUI box node with a texture atlas frame set via gui.play_flipbook().
-- The atlas texture must be added to the .gui file's Textures list.
-- Default atlas name is "icons"; override with el.texture.
local ui = require "flow/ui"
local SCRATCH_SIZE = vmath.vector3()

---@param node userdata
---@param w number
---@param h number
local function set_node_size(node, w, h)
	SCRATCH_SIZE.x = w
	SCRATCH_SIZE.y = h
	SCRATCH_SIZE.z = 0
	gui.set_size(node, SCRATCH_SIZE)
end

---@param el Flow.IconProps
---@param node userdata
local function apply_scale_mode(el, node)
	local scale_mode = el.scale_mode
	local layout = el.layout
	local aspect = el.image_aspect
	if not layout or not aspect or aspect <= 0 then
		return
	end
	if scale_mode ~= "fit" then
		return
	end

	local target_w = layout.w or 0
	local target_h = layout.h or 0
	if target_w <= 0 or target_h <= 0 then
		return
	end

	local target_aspect = target_w / target_h
	local render_w
	local render_h
	if target_aspect > aspect then
		render_h = target_h
		render_w = target_h * aspect
	else
		render_w = target_w
		render_h = target_w / aspect
	end

	set_node_size(node, render_w, render_h)
end

--- Register the "icon" element type with the renderer.
ui.register("icon", {
	--- Create a new Defold box GUI node for an icon element.
	--- Created at 32×32 with PIVOT_CENTER so the layout center matches the node center.
	---@param _ Flow.Element  The icon element being instantiated (unused here)
	---@return userdata       A new gui box node configured for icon display
	create_node = function(_)
		local node = gui.new_box_node(vmath.vector3(), vmath.vector3(32, 32, 0))
		if gui.set_size_mode and gui.SIZE_MODE_MANUAL then
			gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
		end
		gui.set_pivot(node, gui.PIVOT_CENTER)
		return node
	end,

	--- Set the atlas texture and animation frame on the GUI node each frame.
	--- Only runs when el.image is set; no-op for icon elements without an image.
	---@param _ table          The gui_script self table (unused)
	---@param el Flow.IconProps  The icon element providing texture and image frame name
	---@param node userdata    The existing Defold box node to update
	apply = function(_, el, node)
		if el.image then
			gui.set_texture(node, el.texture or "icons")
			gui.play_flipbook(node, hash(el.image))
			apply_scale_mode(el, node)
		end
	end,
})

--- Create an icon element.
--- Displays a single frame from a texture atlas. The image name is hashed and
--- passed to gui.play_flipbook(), so it must match an animation id in the atlas.
---@param t Flow.IconProps        Element definition table (mutated in place)
---@return Flow.Element           The same table with type = "icon" and texture defaulted to "icons"
local function Icon(t)
	t.type = "icon"
	-- Default to the "icons" atlas texture registered in the .gui file
	t.texture = t.texture or "icons"
	return t
end

return Icon
