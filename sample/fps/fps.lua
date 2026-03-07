local M = {}
local resolve_color = require("flow/color").resolve

M.POSITION = vmath.vector3(10, 20, 0)
M.FORMAT = "FPS %.2f"
M.COLOR = resolve_color("#0000ff")

function M.create(samples, format, text_node_id)
	samples = samples or 60
	format = format or M.FORMAT
	local instance = {}
	local frames = {}
	local fps = 0

	-- Update the frame times and calculate FPS
	function instance.update()
		table.insert(frames, socket.gettime())
		if #frames == samples + 1 then
			table.remove(frames, 1)
			fps = 1 / ((frames[#frames] - frames[1]) / (#frames - 1))
		end
	end

	-- Get the current FPS
	function instance.fps()
		return fps
	end

	-- Update the GUI text node
	function instance.draw()
		if text_node_id then
			local fps_text = format:format(fps)
			gui.set_text(gui.get_node(text_node_id), fps_text)
		end
	end

	return instance
end

local singleton = M.create()

function M.update()
	singleton.update()
end

function M.fps()
	return singleton.fps()
end

function M.draw()
	singleton.draw()
end

return M
