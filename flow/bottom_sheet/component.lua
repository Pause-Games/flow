-- flow/bottom_sheet/component.lua
-- Internal visual bottom sheet element.
-- This is not part of the primitive `flow.ui.cp.*` surface because bottom sheets
-- also have a higher-level hosted API in `flow.bottom_sheet.*`.
local ui = require "flow/ui"

local function update_anim(el, dt)
	if el._open == nil then
		return false, false
	end

	local animating = false
	local sheet_h = 0
	for _, child in ipairs(el.children or {}) do
		if child.layout then
			sheet_h = math.max(sheet_h, child.layout.h)
		end
	end
	if sheet_h < 10 then sheet_h = el._sheet_height or 300 end
	el._sheet_height = sheet_h

	if el._anim_y == nil then
		el._anim_y = sheet_h
		el._anim_velocity = 0
	end

	local target_y = el._open and 0 or sheet_h
	local delta = target_y - el._anim_y

	if math.abs(delta) > 0.5 or math.abs(el._anim_velocity or 0) > 2 then
		el._anim_velocity = (el._anim_velocity or 0) + delta * 600 * dt - (el._anim_velocity or 0) * 28 * dt
		el._anim_y = el._anim_y + el._anim_velocity * dt
		el._anim_y = math.max(-30, math.min(sheet_h + 30, el._anim_y))
		if el._on_anim_update then
			el._on_anim_update(el._anim_y, el._anim_velocity)
		end
		animating = true
	else
		el._anim_y = target_y
		el._anim_velocity = 0
		if el._on_anim_update then
			el._on_anim_update(el._anim_y, 0)
		end
	end

	return animating, false
end

ui.register("bottom_sheet", {
	create_node = function(_)
		return gui.new_box_node(vmath.vector3(), vmath.vector3(10, 10, 0))
	end,

	apply = function(self, el, node, alpha)
		local c = el._backdrop_color
		if el._open ~= nil then
			local progress
			if el._anim_y == nil then
				progress = el._open and 1.0 or 0.0
			elseif el._sheet_height and el._sheet_height > 0 then
				progress = 1 - math.min(1, math.max(0, el._anim_y / el._sheet_height))
			else
				progress = el._open and 1.0 or 0.0
			end
			alpha = alpha * progress
		end
		self.ui._set_node_color(node, c.x, c.y, c.z, c.w * alpha)
	end,

	is_hittable = function(el)
		if el._visible == false then
			return false
		end
		if el._open ~= nil then
			local sh = el._sheet_height or 300
			return (el._anim_y or sh) < sh - 5
		end
		return true
	end,

	get_child_extra_offset_y = function(el)
		if el._open ~= nil then
			return -(el._anim_y or 0)
		end
		return 0
	end,

	is_backdrop_click_target = true,
	update_anim = update_anim,
})

local function BottomSheet(t)
	t.type = "bottom_sheet"
	t._is_overlay = true
	t.backdrop_color = t.backdrop_color or "#00000080"
	t.style = t.style or {}
	t.style.width = t.style.width or "100%"
	t.style.height = t.style.height or "100%"
	t.style.justify_content = t.style.justify_content or "end"
	t.style.align_items = t.style.align_items or "center"

	if t._open ~= nil then
		t._visible = true
	else
		t._visible = t._visible ~= false
	end

	return t
end

return BottomSheet
