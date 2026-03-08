local BottomSheet = require "flow/bottom_sheet/component"
local Box = require "flow/components/box"
local ui = require "flow/ui"

local TRANSPARENT = "#00000000"

local function get_window_size()
	return window.get_size()
end

local function sync_window_baseline(self)
	self.last_window_w, self.last_window_h = get_window_size()
end

local function set_background_input_enabled(config, enabled)
	if not config or not config.background_focus_url then
		return
	end

	msg.post(config.background_focus_url, enabled and "acquire_input_focus" or "release_input_focus")
end

local function copy_params(params)
	local out = {}
	for key, value in pairs(params or {}) do
		out[key] = value
	end
	return out
end

local function build_idle_tree()
	return Box({
		key = "flow_bottom_sheet_idle_root",
		color = TRANSPARENT,
		style = {
			width = "100%",
			height = "100%",
		},
	})
end

local function set_tree(self, tree)
	local state = self.bottom_sheet_state
	state.tree = tree
	self.tree = tree
	ui.request_redraw(self)
	return tree
end

local function build_sheet_api(self)
	return {
		dismiss = function(result)
			local state = self.bottom_sheet_state
			if not state or not state.params or state.params._bottom_sheet_closing then
				return false
			end

			state.params._bottom_sheet_open = false
			state.params._bottom_sheet_closing = true
			state.params._bottom_sheet_result = result
			set_tree(self, state.build_tree())
			return true
		end,
		invalidate = function()
			local state = self.bottom_sheet_state
			if not state then
				return false
			end

			set_tree(self, state.build_tree())
			return true
		end,
	}
end

local function build_tree(self)
	local state = self.bottom_sheet_state
	if not state or not state.params then
		return build_idle_tree()
	end

	local sheet_def = state.config.sheet
	local params = state.params
	local content = sheet_def.view and sheet_def.view(params, build_sheet_api(self)) or nil
	assert(content, "bottom_sheet host sheet must return content")

	return Box({
		key = state.config.id .. "_bottom_sheet_root",
		color = TRANSPARENT,
		style = {
			width = "100%",
			height = "100%",
		},
		children = {
			BottomSheet({
				key = state.config.id .. "_sheet",
				backdrop_color = sheet_def.backdrop_color or "#00000080",
				_open = params._bottom_sheet_open,
				_anim_y = params._bottom_sheet_anim_y,
				_anim_velocity = params._bottom_sheet_anim_velocity,
				_on_anim_update = function(y, velocity)
					params._bottom_sheet_anim_y = y
					params._bottom_sheet_anim_velocity = velocity
				end,
				on_backdrop_click = sheet_def.dismiss_on_backdrop == false and nil or function()
					build_sheet_api(self).dismiss()
				end,
				children = {
					content,
				},
			}),
		},
	})
end

local function finalize_close(self)
	local state = self.bottom_sheet_state
	if not state or not state.params or not state.params._bottom_sheet_closing then
		return false
	end

	if state.params._bottom_sheet_anim_y == nil or state.params._bottom_sheet_anim_velocity == nil then
		return false
	end
	if state.params._bottom_sheet_anim_velocity ~= 0 or state.params._bottom_sheet_anim_y <= 1 then
		return false
	end

	local params = state.params
	local result = params._bottom_sheet_result
	state.params = nil
	set_tree(self, build_idle_tree())
	set_background_input_enabled(state.config, true)

	if state.config.sheet.on_dismiss then
		state.config.sheet.on_dismiss(params, result, build_sheet_api(self))
	end

	return true
end

local M = {}

function M.init(self, config)
	assert(type(config) == "table", "bottom_sheet.init(self, config): config must be a table")
	assert(type(config.id) == "string" and config.id ~= "", "bottom_sheet.init: config.id is required")
	assert(type(config.sheet) == "table", "bottom_sheet.init: config.sheet is required")

	msg.post(".", "acquire_input_focus")
	ui.mount(self, { debug = config.debug == true })

	self.bottom_sheet_state = {
		config = config,
		params = nil,
		tree = nil,
	}
	self.bottom_sheet_state.build_tree = function()
		return build_tree(self)
	end

	gui.set_render_order(config.render_order or 15)
	sync_window_baseline(self)
	set_tree(self, build_idle_tree())
end

function M.final(self)
	local state = self.bottom_sheet_state
	if state then
		set_background_input_enabled(state.config, true)
	end
	msg.post(".", "release_input_focus")
end

function M.update(self, dt)
	local state = self.bottom_sheet_state
	if not state then
		return false
	end

	local animating = ui.update_animations(self, dt)
	local hook_requested_rebuild = state.config.on_update and state.config.on_update(self, dt, build_sheet_api(self)) == true or false
	local closed = finalize_close(self)
	if hook_requested_rebuild then
		set_tree(self, state.build_tree())
	end

	local redrew = ui.update(self, self.tree)
	return animating or closed or hook_requested_rebuild or redrew
end

function M.present(self, params)
	local state = self.bottom_sheet_state
	state.params = copy_params(params)
	state.params._bottom_sheet_open = true
	state.params._bottom_sheet_closing = false
	state.params._bottom_sheet_result = nil
	state.params._bottom_sheet_anim_y = nil
	state.params._bottom_sheet_anim_velocity = nil
	set_background_input_enabled(state.config, false)
	set_tree(self, state.build_tree())
end

function M.dismiss(self, result)
	return build_sheet_api(self).dismiss(result)
end

function M.invalidate(self)
	return build_sheet_api(self).invalidate()
end

function M.on_input(self, action_id, action)
	local w, h = get_window_size()
	local size_changed = (self.last_window_w ~= w or self.last_window_h ~= h)
	if size_changed then
		sync_window_baseline(self)
		if self.tree then
			ui.render(self, self.tree)
		end
	end

	return ui.on_input(self, action_id, action)
end

function M.on_message(self, message_id, message, sender)
	local state = self.bottom_sheet_state
	if not state then
		return false
	end

	if message_id == state.config.open_message_id then
		M.present(self, message and message.params or nil)
		return true
	end

	if state.config.close_message_id and message_id == state.config.close_message_id then
		M.dismiss(self, message and message.result or nil)
		return true
	end

	if state.config.on_message then
		return state.config.on_message(self, message_id, message, sender, build_sheet_api(self)) == true
	end

	return false
end

return M
