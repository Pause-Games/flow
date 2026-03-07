local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


local history_shared = require "sample/screens/history_shared"

local HISTORY_DATA = history_shared.data

return {
	view = function(params, navigation)
		if not params then params = {} end
		local item = params.item or HISTORY_DATA[1]

		local C_bg     = vmath.vector4(0.10, 0.12, 0.18, 1)
		local C_header = vmath.vector4(0.08, 0.10, 0.15, 1)
		local C_sep    = vmath.vector4(0.25, 0.28, 0.38, 1)
		local C_orange = vmath.vector4(0.87, 0.62, 0.15, 1)
		local C_white  = vmath.vector4(0.90, 0.90, 0.90, 1)
		local C_green  = vmath.vector4(0.30, 0.85, 0.40, 1)
		local C_transp = vmath.vector4(0, 0, 0, 0)

		local function fmt(v)
			return ("R$ " .. string.format("%.2f", v)):gsub("%.", ",")
		end

		-- Column header (different columns from list: Bet | Value | Return | Balance)
		local col_header = Box({
			key   = "det_col_hdr",
			style = { height = 36, flex_direction = "row", align_items = "center",
			          padding_left = 12, padding_right = 12 },
			color = C_transp,
			children = {
				Text({ key = "dch_aposta",  text = "Bet",     style = { flex_grow = 1, height = 20 }, color = C_orange }),
				Text({ key = "dch_valor",   text = "Value",   style = { width = 90, height = 20 }, color = C_orange, align = "center" }),
				Text({ key = "dch_retorno", text = "Return",  style = { width = 90, height = 20 }, color = C_orange, align = "center" }),
				Text({ key = "dch_saldo",   text = "Balance", style = { width = 95, height = 20 }, color = C_orange, align = "center" }),
			}
		})

		-- Data row (same visual pattern as history_row but adapted columns)
		local data_row = Box({
			key   = "det_data_row",
			style = { height = 50, flex_direction = "row", align_items = "center",
			          padding_left = 12, padding_right = 12 },
			color = vmath.vector4(0.12, 0.14, 0.20, 1),
			children = {
				Text({ key = "ddr_aposta",  text = item.bet,
				          style = { flex_grow = 1, height = 22 } }),
				Text({ key = "ddr_valor",   text = fmt(item.value),
				          style = { width = 90, height = 22 }, align = "center" }),
				Text({ key = "ddr_retorno", text = fmt(item.return_val),
				          style = { width = 90, height = 22 }, align = "center",
				          color = item.won and C_green or C_white }),
				Text({ key = "ddr_saldo",   text = fmt(item.balance),
				          style = { width = 95, height = 22 }, align = "center" }),
			}
		})

		-- Slot machine placeholder grid (3 x 3 symbol cells)
		local function sym(k)
			return Box({ key = "sym_" .. k, style = { width = 80, height = 56 },
			                color = vmath.vector4(0.42, 0.22, 0.10, 1) })
		end
		local grid = Box({
			key   = "game_grid",
			style = { width = 280, height = 204, flex_direction = "column", gap = 6,
			          align_items = "center", justify_content = "center", padding = 8 },
			color = vmath.vector4(0.35, 0.18, 0.10, 1),
			children = {
				Box({ key = "gr1", style = { height = 56, flex_direction = "row", gap = 6 }, color = C_transp,
					children = { sym("1"), sym("2"), sym("3") } }),
				Box({ key = "gr2", style = { height = 56, flex_direction = "row", gap = 6 }, color = C_transp,
					children = { sym("4"), sym("5"), sym("6") } }),
				Box({ key = "gr3", style = { height = 56, flex_direction = "row", gap = 6 }, color = C_transp,
					children = { sym("7"), sym("8"), sym("9") } }),
			}
		})

		return Box({
			key   = "hist_detail_root",
			style = { width = "100%", height = "100%", flex_direction = "column" },
			color = C_bg,
			children = {
				-- Header
				Box({
					key   = "det_hdr",
					style = { height = 80, flex_direction = "row", align_items = "center",
					          padding_left = 12, padding_right = 12 },
					color = C_header,
					children = {
						Button({
							key   = "det_back",
							style = { width = 50, height = 50 },
							color = C_transp,
							on_click = function() navigation.pop("slide_right") end,
							children = { Text({ key = "det_back_lbl", text = "<",
							             style = { width = "100%", height = "100%" } }) }
						}),
						Box({
							key   = "det_title_box",
							style = { flex_grow = 1, height = 50, flex_direction = "column",
							          align_items = "center", justify_content = "center" },
							color = C_transp,
							children = {
								Text({ key = "det_title",    text = "Bet Details",
								          style = { height = 26 }, align = "center" }),
								Text({ key = "det_subtitle", text = item.time .. " " .. item.date,
								          style = { height = 20 }, align = "center",
								          color = vmath.vector4(0.6, 0.6, 0.7, 1) }),
							}
						}),
						Box({ key = "det_right_pad", style = { width = 50, height = 50 }, color = C_transp }),
					}
				}),
				-- Column headers + separator
				col_header,
				Box({ key = "det_sep1", style = { height = 1, width = "100%" }, color = C_sep }),
				-- Data row + separator
				data_row,
				Box({ key = "det_sep2", style = { height = 1, width = "100%" }, color = C_sep }),
				-- Game info section
				Box({
					key   = "game_info",
					style = { flex_grow = 1, flex_direction = "column", align_items = "center",
					          justify_content = "start", gap = 20, padding_top = 24 },
					color = C_transp,
					children = {
						Box({
							key   = "bet_info_row",
							style = { width = 340, height = 28, flex_direction = "row", align_items = "center",
							          justify_content = "center", gap = 20 },
							color = C_transp,
							children = {
								Text({ key = "bet_lines", text = string.format("Bet %d", item.lines),
								          style = { width = 120, height = 22 }, align = "center" }),
								Text({ key = "bet_level", text = string.format("Bet level %.1f", item.level),
								          style = { width = 200, height = 22 }, align = "center" }),
							}
						}),
						grid,
						Text({
							key   = "result_text",
							text  = item.result,
							style = { height = 28 },
							align = "center",
							color = item.won and C_green or C_white,
						}),
					}
				}),
			}
		})
	end
}
