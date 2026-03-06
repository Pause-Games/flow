-- flow/ui/animation.lua
-- Per-frame animation ticker for the Flow renderer.
-- Walks the element tree depth-first, calling each element type's
-- update_anim(el, dt, deps) handler. Tracks whether any animation
-- is still running (to keep the renderer dirty) and whether any
-- scroll offset changed (to trigger a scroll-state save).
local M = {}

--- Recursively advance animations for an element and all its descendants.
--- For each element, looks up its type definition in deps.registry and calls
--- def.update_anim(el, dt, deps) if present. Combines results bottom-up:
--- if any node reports animating=true the whole subtree is considered animating.
---@param el Flow.Element          The element to process; may have children
---@param dt number                Delta time in seconds since the last frame
---@param deps Flow.AnimationDeps  Dependency bundle from flow/ui.lua (ANIMATION_DEPS)
---@return boolean animating       True if this element or any descendant is still animating
---@return boolean scroll_changed  True if any scroll offset changed this frame
local function update_recursive(el, dt, deps)
	local animating = false
	local scroll_changed = false
	local def = deps.registry[el.type]

	if def and def.update_anim then
		local def_animating, def_scroll_changed = def.update_anim(el, dt, deps)
		animating = def_animating == true
		scroll_changed = def_scroll_changed == true
	end

	for _, child in ipairs(el.children or {}) do
		local child_animating, child_scroll_changed = update_recursive(child, dt, deps)
		if child_animating then animating = true end
		if child_scroll_changed then scroll_changed = true end
	end

	return animating, scroll_changed
end

--- Advance all animations in the current tree by dt seconds.
--- Called once per frame from flow/ui.lua M.update_animations().
--- Sets self.ui._scroll_dirty when any scroll offset changed so that
--- the navigation layer can persist the new scroll position.
--- Marks the renderer dirty via deps.mark_dirty() when still animating.
---@param self table               The gui_script self table with a mounted renderer
---@param dt number                Delta time in seconds since the last frame
---@param deps Flow.AnimationDeps  Dependency bundle from flow/ui.lua (ANIMATION_DEPS)
---@return boolean                 True if at least one animation is still running this frame
function M.update(self, dt, deps)
	if not self.ui or not self.ui.tree then return false end
	local animating, scroll_changed = update_recursive(self.ui.tree, dt, deps)
	if scroll_changed then
		self.ui._scroll_dirty = true
	end
	if animating then
		deps.mark_dirty(self)
	end
	return animating
end

return M
