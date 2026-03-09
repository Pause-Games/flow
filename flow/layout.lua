-- flow/layout.lua
-- Pure flexbox layout engine with no Defold dependencies.
-- Computes absolute {x, y, w, h} rectangles for a UI element tree.
-- Implements a focused flexbox-style subset: flex_direction, justify_content,
-- align_items, align_self, flex_grow, gap, width/height, and padding.
-- Overlay children (popup, bottom_sheet) are laid out at full parent bounds,
-- outside of the normal flex flow.
-- Entry point: M.compute(node, x, y, w, h)
local M = {}

--- Resolve a size value against a parent dimension.
--- Accepts a plain number (returned as-is) or a percentage string like "50%"
--- (converted to the corresponding fraction of parent).
---@param v number|string          The value to resolve; a number or "N%" string
---@param parent number            The parent dimension used to resolve percentages
---@return number                  The resolved absolute pixel value
local function resolve(v, parent)
	if type(v) == "string" and v:sub(-1) == "%" then
		return parent * tonumber(v:sub(1, -2)) / 100
	end
	return type(v) == "number" and v or tonumber(v) or 0
end

--- Resolve a size value, returning a fallback when the value is nil.
--- Combines nil-check with resolve() so callers don't need to guard separately.
---@param v number|string|nil      The value to resolve; nil triggers fallback
---@param parent number            The parent dimension used to resolve percentages
---@param fallback number          The value to return when v is nil
---@return number                  The resolved absolute pixel value, or fallback
local function resolve_or(v, parent, fallback)
	if v == nil then return fallback end
	return resolve(v, parent)
end

--- Return true when a child element is an overlay (popup, bottom_sheet).
--- Overlay children are skipped during flex flow and instead laid out
--- at full parent bounds in a separate pass.
---@param child Flow.Element       The child element to test
---@return boolean                 True if the child has _is_overlay == true
local function is_overlay_child(child)
	return child._is_overlay == true
end

--- Compute layout for a node tree. Writes layout.x/y/w/h to every node
--- in the tree recursively, using bottom-left origin coordinates.
---
--- Algorithm:
--- 1. Measure all regular (non-overlay) children to sum fixed sizes and flex_grow weights.
--- 2. Distribute remaining free space according to justify_content.
--- 3. Place each child along the main axis, applying align_items / align_self on the cross axis.
--- 4. Recurse into each child.
--- 5. Layout overlay children (popup, bottom_sheet) at full parent bounds as a final pass.
---@param node Flow.Element        The root element to compute layout for
---@param x number                 Left edge of the available area in layout space (px)
---@param y number                 Bottom edge of the available area in layout space (px)
---@param w number                 Available width in pixels
---@param h number                 Available height in pixels
function M.compute(node, x, y, w, h)
	local style = node.style or {}
	local children = node.children or {}

	local padding = style.padding
	local gap = style.gap or 0
	local dir = style.flex_direction or "column"
	local align = style.align_items or "stretch"
	local justify = style.justify_content or "start"

	node.layout = { x = x, y = y, w = w, h = h }

	-- inner box after padding
	local pl = resolve_or(style.padding_left, w, resolve_or(padding, w, 0))
	local pr = resolve_or(style.padding_right, w, resolve_or(padding, w, 0))
	local pt = resolve_or(style.padding_top, h, resolve_or(padding, h, 0))
	local pb = resolve_or(style.padding_bottom, h, resolve_or(padding, h, 0))

	local ix = x + pl
	local iy = y + pb
	local iw = w - pl - pr
	local ih = h - pt - pb

	-- Pass 1: measure regular children — sum fixed sizes and flex_grow weights
	local fixed = 0
	local grow_sum = 0
	local regular_count = 0

	for i = 1, #children do
		local c = children[i]
		if not is_overlay_child(c) then
			regular_count = regular_count + 1
			local s = c.style or {}
			local size
			if dir == "column" then
				size = s.height
			else
				size = s.width
			end
			if size then
				fixed = fixed + resolve(size, dir == "column" and ih or iw)
			else
				grow_sum = grow_sum + (s.flex_grow or 0)
			end
		end
	end

	fixed = fixed + gap * math.max(0, regular_count - 1)
	local free = (dir == "column" and ih or iw) - fixed
	local grow_free = math.max(0, free)
	-- justify_free is 0 when there are flex_grow children (they consume free space)
	local justify_free = (grow_sum > 0) and 0 or math.max(0, free)
	local gap_extra = 0
	local start_offset = 0

	-- Distribute justify_free according to justify_content
	if justify == "center" then
		start_offset = justify_free * 0.5
	elseif justify == "end" then
		start_offset = justify_free
	elseif justify == "space-between" and regular_count > 1 then
		gap_extra = justify_free / (regular_count - 1)
	elseif justify == "space-around" and regular_count > 0 then
		gap_extra = justify_free / regular_count
		start_offset = gap_extra * 0.5
	elseif justify == "space-evenly" and regular_count > 0 then
		gap_extra = justify_free / (regular_count + 1)
		start_offset = gap_extra
	end

	local cursor = start_offset

	-- Pass 2: place regular children along the main axis
	for i = 1, #children do
		local c = children[i]
		if not is_overlay_child(c) then
			local s = c.style or {}
			local cw, ch
			local child_align = s.align_self or align

			if dir == "column" then
				ch = s.height and resolve(s.height, ih) or (grow_sum > 0 and grow_free * (s.flex_grow or 0) / grow_sum or 0)
				cw = s.width and resolve(s.width, iw) or iw

				local child_x = ix
				if child_align == "center" then
					child_x = ix + (iw - cw) * 0.5
				elseif child_align == "end" then
					child_x = ix + (iw - cw)
				end

				local child_y = iy + ih - cursor - ch
				M.compute(c, child_x, child_y, cw, ch)
				cursor = cursor + ch + gap + gap_extra
			else
				cw = s.width and resolve(s.width, iw) or (grow_sum > 0 and grow_free * (s.flex_grow or 0) / grow_sum or 0)
				ch = s.height and resolve(s.height, ih) or ih

				local child_y = iy + ih - ch
				if child_align == "center" then
					child_y = iy + (ih - ch) * 0.5
				elseif child_align == "end" then
					child_y = iy
				end

				M.compute(c, ix + cursor, child_y, cw, ch)
				cursor = cursor + cw + gap + gap_extra
			end
		end
	end

	-- Pass 3: layout overlay children at full parent bounds (outside flex flow)
	for i = 1, #children do
		local child = children[i]
		if is_overlay_child(child) then
			M.compute(child, x, y, w, h)
		end
	end
end

return M
