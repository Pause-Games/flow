local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Popup = flow.ui.cp.Popup
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		if not params then params = {} end
		if params.filter_type       == nil then params.filter_type       = "today" end
		if params.month             == nil then params.month             = 3 end
		if params.year              == nil then params.year              = 2026 end
		if params.show_month_popup  == nil then params.show_month_popup  = false end
		if params.show_year_popup   == nil then params.show_year_popup   = false end

		local C_bg       = vmath.vector4(0.10, 0.12, 0.18, 1)
		local C_header   = vmath.vector4(0.08, 0.10, 0.15, 1)
		local C_orange   = vmath.vector4(0.87, 0.62, 0.15, 1)
		local C_transp   = vmath.vector4(0, 0, 0, 0)
		local C_radio_bg = vmath.vector4(0.20, 0.23, 0.32, 1)
		local C_radio_on = vmath.vector4(0.80, 0.80, 0.85, 1)
		local C_dark_box = vmath.vector4(0.08, 0.10, 0.15, 1)
		local C_popup_bg = vmath.vector4(0.12, 0.15, 0.22, 1)
		local C_cell_bg  = vmath.vector4(0.20, 0.23, 0.32, 1)

		-- Radio indicator circle (outer box + inner dot)
		local function radio_indicator(key, selected)
			return Box({
				key   = "ri_outer_" .. key,
				style = { width = 36, height = 36, align_items = "center", justify_content = "center" },
				color = C_radio_bg,
				children = {
					Box({
						key   = "ri_inner_" .. key,
						style = { width = 16, height = 16 },
						color = selected and C_radio_on or C_radio_bg,
					})
				}
			})
		 end

		-- Simple radio row: indicator + orange label
		local function radio_row(key, label, value)
			local selected = (params.filter_type == value)
			return Button({
				key   = "radio_" .. key,
				style = { height = 56, flex_direction = "row", align_items = "center",
				          gap = 16, padding_left = 24 },
				color = C_transp,
				on_click = function()
					params.filter_type = value
					navigation.invalidate()
				end,
				children = {
					radio_indicator(key, selected),
					Text({ key = "rl_" .. key, text = label,
					          style = { flex_grow = 1, height = 28 }, color = C_orange }),
				}
			})
		end

		-- Custom date row: indicator + "Date:" + [MM] / [YYYY]
		local custom_selected = (params.filter_type == "custom")
		local date_row = Box({
			key   = "date_row",
			style = { height = 56, flex_direction = "row", align_items = "center",
			          gap = 12, padding_left = 24 },
			color = C_transp,
			children = {
				Button({
					key   = "radio_custom_outer",
					style = { width = 36, height = 36, align_items = "center", justify_content = "center" },
					color = C_radio_bg,
					on_click = function() params.filter_type = "custom"; navigation.invalidate() end,
					children = {
						Box({ key = "radio_custom_inner", style = { width = 16, height = 16 },
						        color = custom_selected and C_radio_on or C_radio_bg })
					}
				}),
				Text({ key = "data_lbl", text = "Date:", style = { width = 52, height = 28 }, color = C_orange }),
				-- Month picker button
				Button({
					key   = "month_btn",
					style = { width = 56, height = 40, align_items = "center", justify_content = "center" },
					color = C_dark_box,
					on_click = function()
						params.filter_type = "custom"
						params.show_month_popup = true
						params.show_year_popup  = false
						navigation.invalidate()
					end,
					children = { Text({ key = "month_val", text = string.format("%02d", params.month),
					             style = { width = "100%", height = "100%" } }) }
				}),
				Text({ key = "date_sep", text = "/", style = { width = 16, height = 28 }, align = "center" }),
				-- Year picker button
				Button({
					key   = "year_btn",
					style = { width = 72, height = 40, align_items = "center", justify_content = "center" },
					color = C_dark_box,
					on_click = function()
						params.filter_type = "custom"
						params.show_month_popup = false
						params.show_year_popup  = true
						navigation.invalidate()
					end,
					children = { Text({ key = "year_val", text = tostring(params.year),
					             style = { width = "100%", height = "100%" } }) }
				}),
			}
		})

		-- Month popup: 3-column × 4-row grid (01-12)
		local function month_cell(m)
			local sel = (params.month == m)
			return Button({
				key   = "mc_" .. m,
				style = { width = 80, height = 50, align_items = "center", justify_content = "center" },
				color = sel and C_orange or C_cell_bg,
				on_click = function()
					params.month = m
					params.show_month_popup = false
					navigation.invalidate()
				end,
				children = { Text({ key = "mc_lbl_" .. m, text = string.format("%02d", m),
				             style = { width = "100%", height = "100%" } }) }
			})
		end

		local month_popup_box = Box({
			key   = "month_popup_box",
			style = { width = 292, height = 298, flex_direction = "column",
			          align_items = "center", gap = 10, padding = 16 },
			color = C_popup_bg,
			children = {
				Text({ key = "mp_title", text = "Select Month",
				          style = { height = 28 }, align = "center", color = C_orange }),
				Box({ key = "mr1", style = { height = 50, flex_direction = "row", gap = 10 }, color = C_transp,
					children = { month_cell(1), month_cell(2), month_cell(3) } }),
				Box({ key = "mr2", style = { height = 50, flex_direction = "row", gap = 10 }, color = C_transp,
					children = { month_cell(4), month_cell(5), month_cell(6) } }),
				Box({ key = "mr3", style = { height = 50, flex_direction = "row", gap = 10 }, color = C_transp,
					children = { month_cell(7), month_cell(8), month_cell(9) } }),
				Box({ key = "mr4", style = { height = 50, flex_direction = "row", gap = 10 }, color = C_transp,
					children = { month_cell(10), month_cell(11), month_cell(12) } }),
			}
		})

		-- Year popup: available years in a row
		local YEARS = { 2025, 2026 }
		local year_cells = {}
		for _, y in ipairs(YEARS) do
			local sel = (params.year == y)
			local yy = y
			table.insert(year_cells, Button({
				key   = "yc_" .. y,
				style = { width = 100, height = 50, align_items = "center", justify_content = "center" },
				color = sel and C_orange or C_cell_bg,
				on_click = function()
					params.year = yy
					params.show_year_popup = false
					navigation.invalidate()
				end,
				children = { Text({ key = "yc_lbl_" .. y, text = tostring(y),
				             style = { width = "100%", height = "100%" } }) }
			}))
		end

		local year_popup_box = Box({
			key   = "year_popup_box",
			style = { width = 260, height = 126, flex_direction = "column",
			          align_items = "center", gap = 10, padding = 16 },
			color = C_popup_bg,
			children = {
				Text({ key = "yp_title", text = "Select Year",
				          style = { height = 28 }, align = "center", color = C_orange }),
				Box({ key = "yr1", style = { height = 50, flex_direction = "row", gap = 10 }, color = C_transp,
					children = year_cells }),
			}
		})

		-- Build screen children
		local children = {
			-- Header
			Box({
				key   = "flt_hdr",
				style = { height = 80, flex_direction = "row", align_items = "center",
				          padding_left = 12, padding_right = 12 },
				color = C_header,
				children = {
					Button({
						key   = "flt_back",
						style = { width = 50, height = 50 },
						color = C_transp,
						on_click = function() navigation.pop("slide_right") end,
						children = { Text({ key = "flt_back_lbl", text = "<",
						             style = { width = "100%", height = "100%" } }) }
					}),
					Box({
						key   = "flt_title_box",
						style = { flex_grow = 1, height = 50, flex_direction = "column",
						          align_items = "center", justify_content = "center" },
						color = C_transp,
						children = {
							Text({ key = "flt_title",    text = "Filter Data",
							          style = { height = 26 }, align = "center" }),
							Text({ key = "flt_subtitle", text = "Select Period",
							          style = { height = 20 }, align = "center",
							          color = vmath.vector4(0.6, 0.6, 0.7, 1) }),
						}
					}),
					Box({ key = "flt_right_pad", style = { width = 50, height = 50 }, color = C_transp }),
				}
			}),
			-- Radio options
			radio_row("today", "Today", "today"),
			radio_row("last7", "Last 7 days", "last7"),
			date_row,
			-- Spacer
			Box({ key = "flt_spacer", style = { flex_grow = 1 }, color = C_transp }),
			-- Apply Filter button (with horizontal padding via wrapper)
			Box({
				key   = "filtrar_wrap",
				style = { height = 72, flex_direction = "row", padding_left = 24, padding_right = 24,
				          padding_bottom = 16 },
				color = C_transp,
				children = {
					Button({
						key   = "filtrar_btn",
						style = { flex_grow = 1, height = 56, align_items = "center", justify_content = "center" },
						color = C_orange,
						on_click = function()
							if params.on_apply then params.on_apply(params) end
							navigation.pop("slide_right")
					end,
						children = { Text({ key = "filtrar_lbl", text = "Apply Filter",
						             style = { width = "100%", height = "100%" } }) }
					}),
				}
			}),
		}

		-- Month picker popup (rendered on top)
		if params.show_month_popup then
			table.insert(children, Popup({
				key = "month_popup",
				style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
				backdrop_color = vmath.vector4(0, 0, 0, 0.65),
				_visible = true,
				on_backdrop_click = function()
					params.show_month_popup = false
					navigation.invalidate()
				end,
				children = { month_popup_box },
			}))
		end

		-- Year picker popup (rendered on top)
		if params.show_year_popup then
			table.insert(children, Popup({
				key = "year_popup",
				style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
				backdrop_color = vmath.vector4(0, 0, 0, 0.65),
				_visible = true,
				on_backdrop_click = function()
					params.show_year_popup = false
					navigation.invalidate()
				end,
				children = { year_popup_box },
			}))
		end

		return Box({
			key   = "filter_root",
			style = { width = "100%", height = "100%", flex_direction = "column" },
			color = C_bg,
			children = children,
		})
	end
}
