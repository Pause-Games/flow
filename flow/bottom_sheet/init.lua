local component = require "flow/bottom_sheet/component"
local host = require "flow/bottom_sheet/host"

local M = {
	init = host.init,
	final = host.final,
	update = host.update,
	present = host.present,
	dismiss = host.dismiss,
	invalidate = host.invalidate,
	on_input = host.on_input,
	on_message = host.on_message,
}

return setmetatable(M, {
	__call = function(_, props)
		return component(props)
	end,
})
