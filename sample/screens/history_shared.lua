local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


local M = {}

-- Mock history data (15 entries to demonstrate pagination)
local HISTORY_DATA = (function()
	local data = {}
	local times = {
		"22:09:34","21:45:12","20:30:55","19:15:03","18:42:27",
		"17:20:11","16:05:48","15:33:22","14:18:09","13:47:56",
		"12:22:31","11:08:44","10:55:17","09:40:02","08:25:38",
	}
	for i = 1, 15 do
		local won = (i % 4 == 0)
		local val = (i % 3 + 1) * 2.5
		table.insert(data, {
			id         = i,
			time       = times[i],
			date       = "04-03-26",
			bet        = string.format("%d%d%d%d-%d", i%9+1,(i+1)%9+1,(i+2)%9+1,(i+3)%9+1,i%5+1),
			value      = val,
			return_val = won and val * 3 or 0.00,
			balance    = 1000.00 - i * val + (won and val * 2 or 0),
			lines      = (i % 5 + 1) * 2,
			level      = 0.1 * (i % 5 + 1),
			result     = won and "Winning combination!" or "No winning combination",
			won        = won,
		})
	end
	return data
end)()

local function history_row(item, key_suffix, on_click)
	local C_green  = rgba(0.30, 0.85, 0.40, 1)
	local C_white  = rgba(0.90, 0.90, 0.90, 1)
	local C_transp = rgba(0, 0, 0, 0)
	local C_row    = rgba(0.12, 0.14, 0.20, 1)
	local function fmt(v)
		return ("R$ " .. string.format("%.2f", v)):gsub("%.", ",")
	end
	return Button({
		key   = "hist_row_" .. key_suffix,
		style = { height = 60, flex_direction = "row", align_items = "center",
		          padding_left = 12, padding_right = 12 },
		color = C_row,
		on_click = on_click,
		children = {
			-- Date: two stacked lines
			Box({
				key   = "date_box_" .. key_suffix,
				style = { width = 120, height = 44, flex_direction = "column", justify_content = "center" },
				color = C_transp,
				children = {
					Text({ key = "time_" .. key_suffix, text = item.time, style = { height = 22 } }),
					Text({ key = "date_" .. key_suffix, text = item.date, style = { height = 20 } }),
				}
			}),
			-- Bet
			Text({ key = "bet_" .. key_suffix, text = item.bet,
			          style = { flex_grow = 1, height = 22 } }),
			-- Value
			Text({ key = "val_" .. key_suffix, text = fmt(item.value),
			          style = { width = 90, height = 22 }, align = "center" }),
			-- Return
			Text({ key = "ret_" .. key_suffix, text = fmt(item.return_val),
			          style = { width = 90, height = 22 }, align = "center",
			          color = item.won and C_green or C_white }),
			-- Arrow
			Text({ key = "arr_" .. key_suffix, text = ">",
			          style = { width = 20, height = 22 }, align = "center" }),
		}
	})
end

M.data = HISTORY_DATA
M.row = history_row

return M
