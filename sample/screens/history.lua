local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Popup = flow.ui.cp.Popup
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text


local history_shared = require "sample/screens/history_shared"

local HISTORY_DATA = history_shared.data
local history_row = history_shared.row

return {
	view = function(params, navigation)
		if not params then params = {} end
		params.page = params.page or 1
		-- Filter state (all stored in history params, no separate screen)
		if params.filter_type       == nil then params.filter_type       = "today" end
		if params.filter_month      == nil then params.filter_month      = 3 end
		if params.filter_year       == nil then params.filter_year       = 2026 end
		if params.show_filter       == nil then params.show_filter       = false end
		if params.show_month_popup  == nil then params.show_month_popup  = false end
		if params.show_year_popup   == nil then params.show_year_popup   = false end

		local PER_PAGE    = 8
		local total       = #HISTORY_DATA
		local total_pages = math.max(1, math.ceil(total / PER_PAGE))
		params.page = math.min(params.page, total_pages)

		local C_bg       = rgba(0.10, 0.12, 0.18, 1)
		local C_header   = rgba(0.08, 0.10, 0.15, 1)
		local C_sep      = rgba(0.25, 0.28, 0.38, 1)
		local C_orange   = rgba(0.87, 0.62, 0.15, 1)
		local C_transp   = rgba(0, 0, 0, 0)
		local C_radio_bg = rgba(0.20, 0.23, 0.32, 1)
		local C_radio_on = rgba(0.80, 0.80, 0.85, 1)
		local C_dark_box = rgba(0.08, 0.10, 0.15, 1)
		local C_cell_bg  = rgba(0.20, 0.23, 0.32, 1)
		local C_panel    = rgba(0.13, 0.15, 0.22, 1)
		local C_list_bg  = rgba(0.12, 0.14, 0.20, 1)

		-- Column header
		local col_header = Box({
			key   = "col_header",
			style = { height = 36, flex_direction = "row", align_items = "center",
			          padding_left = 12, padding_right = 12 },
			color = C_transp,
			children = {
				Text({ key = "ch_data",    text = "Date",   style = { width = 120, height = 20 }, color = C_orange }),
				Text({ key = "ch_aposta",  text = "Bet",    style = { flex_grow = 1, height = 20 }, color = C_orange }),
				Text({ key = "ch_valor",   text = "Value",  style = { width = 90, height = 20 }, color = C_orange, align = "center" }),
				Text({ key = "ch_retorno", text = "Return", style = { width = 90, height = 20 }, color = C_orange, align = "center" }),
				Box({ key = "ch_arr_pad", style = { width = 20, height = 20 }, color = C_transp }),
			}
		})

		-- Build current page rows
		local first = (params.page - 1) * PER_PAGE + 1
		local last  = math.min(first + PER_PAGE - 1, total)
		local rows  = {}
		for i = first, last do
			local item = HISTORY_DATA[i]
			table.insert(rows, history_row(item, tostring(i), function()
				navigation.push("history_detail", { item = item }, "slide_left")
			end))
			if i < last then
				table.insert(rows, Box({
					key   = "sep_" .. i,
					style = { height = 1, width = "100%" },
					color = C_sep,
				}))
			end
		end

		-- Pagination bar
		local can_prev = params.page > 1
		local can_next = params.page < total_pages
		local btn_on   = rgba(0.20, 0.25, 0.38, 1)
		local btn_off  = rgba(0.15, 0.17, 0.22, 0.5)

		local pagination = Box({
			key   = "pagination",
			style = { height = 50, flex_direction = "row", align_items = "center",
			          justify_content = "center", gap = 20 },
			color = C_transp,
			children = {
				Button({
					key = "btn_prev", style = { width = 70, height = 36 },
					color = can_prev and btn_on or btn_off,
					on_click = function()
						if can_prev then params.page = params.page - 1; navigation.invalidate() end
					end,
					children = { Text({ key = "prev_lbl", text = "< Prev", style = { width = "100%", height = "100%" } }) }
				}),
				Text({
					key   = "page_lbl",
					text  = string.format("Page %d/%d", params.page, total_pages),
					style = { width = 130, height = 26 }, align = "center", color = C_orange,
				}),
				Button({
					key = "btn_next", style = { width = 70, height = 36 },
					color = can_next and btn_on or btn_off,
					on_click = function()
						if can_next then params.page = params.page + 1; navigation.invalidate() end
					end,
					children = { Text({ key = "next_lbl", text = "Next >", style = { width = "100%", height = "100%" } }) }
				}),
			}
		})

		-- ── Filter panel (inline popup overlay) ───────────────────────────────

		-- Radio helper
		local function radio_row(key, label, value)
			local sel = (params.filter_type == value)
			return Button({
				key   = "frad_" .. key,
				style = { height = 56, flex_direction = "row", align_items = "center",
				          gap = 16, padding_left = 24 },
				color = C_transp,
				on_click = function() params.filter_type = value; navigation.invalidate() end,
				children = {
					Box({
						key   = "frad_out_" .. key,
						style = { width = 36, height = 36, align_items = "center", justify_content = "center" },
						color = C_radio_bg,
						children = {
							Box({ key = "frad_in_" .. key, style = { width = 16, height = 16 },
							        color = sel and C_radio_on or C_radio_bg })
						}
					}),
					Text({ key = "frad_lbl_" .. key, text = label,
					          style = { flex_grow = 1, height = 28 }, color = C_orange }),
				}
			})
		end

		local custom_sel = (params.filter_type == "custom")
		local date_row = Box({
			key   = "flt_date_row",
			style = { height = 56, flex_direction = "row", align_items = "center",
			          gap = 12, padding_left = 24 },
			color = C_transp,
			children = {
				Button({
					key   = "frad_out_custom",
					style = { width = 36, height = 36, align_items = "center", justify_content = "center" },
					color = C_radio_bg,
					on_click = function() params.filter_type = "custom"; navigation.invalidate() end,
					children = {
						Box({ key = "frad_in_custom", style = { width = 16, height = 16 },
						        color = custom_sel and C_radio_on or C_radio_bg })
					}
				}),
				Text({ key = "flt_data_lbl", text = "Date:", style = { width = 52, height = 28 }, color = C_orange }),
				Button({
					key   = "flt_month_btn",
					style = { width = 56, height = 40, align_items = "center", justify_content = "center" },
					color = C_dark_box,
					on_click = function()
						params.filter_type = "custom"
						params.show_month_popup = true
						params.show_year_popup  = false
						navigation.invalidate()
					end,
					children = { Text({ key = "flt_month_val", text = string.format("%02d", params.filter_month),
					             style = { width = "100%", height = "100%" } }) }
				}),
				Text({ key = "flt_date_sep", text = "/", style = { width = 16, height = 28 }, align = "center" }),
				Button({
					key   = "flt_year_btn",
					style = { width = 72, height = 40, align_items = "center", justify_content = "center" },
					color = C_dark_box,
					on_click = function()
						params.filter_type = "custom"
						params.show_month_popup = false
						params.show_year_popup  = true
						navigation.invalidate()
					end,
					children = { Text({ key = "flt_year_val", text = tostring(params.filter_year),
					             style = { width = "100%", height = "100%" } }) }
				}),
			}
		})

		-- Filter panel box (sits at top inside the popup overlay)
		local filter_panel = Box({
			key   = "filter_panel",
			style = { width = "100%", height = 370, flex_direction = "column" },
			color = C_panel,
			children = {
				-- Panel header
				Box({
					key   = "flt_hdr",
					style = { height = 80, flex_direction = "row", align_items = "center",
					          padding_left = 12, padding_right = 12 },
					color = C_header,
					children = {
						Button({
							key   = "flt_close",
							style = { width = 50, height = 50 },
							color = C_transp,
							on_click = function()
								params.show_filter = false
								params.show_month_popup = false
								params.show_year_popup  = false
								navigation.invalidate()
							end,
							children = { Text({ key = "flt_close_lbl", text = "<",
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
								          color = rgba(0.6, 0.6, 0.7, 1) }),
							}
						}),
						Box({ key = "flt_hdr_pad", style = { width = 50, height = 50 }, color = C_transp }),
					}
				}),
				-- Radio options
				radio_row("today", "Today", "today"),
				radio_row("last7", "Last 7 days", "last7"),
				date_row,
				-- Spacer
				Box({ key = "flt_spacer", style = { flex_grow = 1 }, color = C_transp }),
				-- Apply Filter button with side padding
				Box({
					key   = "filtrar_wrap",
					style = { height = 72, flex_direction = "row",
					          padding_left = 24, padding_right = 24, padding_bottom = 12 },
					color = C_transp,
					children = {
						Button({
							key   = "filtrar_btn",
							style = { flex_grow = 1, height = 56, align_items = "center", justify_content = "center" },
							color = C_orange,
							on_click = function()
								params.show_filter = false
								params.show_month_popup = false
								params.show_year_popup  = false
								params.page = 1
								navigation.invalidate()
							end,
							children = { Text({ key = "filtrar_lbl", text = "Apply Filter",
							             style = { width = "100%", height = "100%" } }) }
						}),
					}
				}),
			}
		})

		-- Month picker: 3×4 grid
		local function month_cell(m)
			local sel = (params.filter_month == m)
			return Button({
				key   = "fmc_" .. m,
				style = { width = 80, height = 50, align_items = "center", justify_content = "center" },
				color = sel and C_orange or C_cell_bg,
				on_click = function()
					params.filter_month = m
					params.show_month_popup = false
					navigation.invalidate()
				end,
				children = { Text({ key = "fmc_lbl_" .. m, text = string.format("%02d", m),
				             style = { width = "100%", height = "100%" } }) }
			})
		end

		local month_popup_box = Box({
			key   = "month_popup_box",
			style = { width = 292, height = 298, flex_direction = "column",
			          align_items = "center", gap = 10, padding = 16 },
			color = rgba(0.12, 0.15, 0.22, 1),
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

		-- Year picker
		local YEARS = { 2025, 2026 }
		local year_cells = {}
		for _, y in ipairs(YEARS) do
			local sel = (params.filter_year == y); local yy = y
			table.insert(year_cells, Button({
				key   = "fyc_" .. y,
				style = { width = 100, height = 50, align_items = "center", justify_content = "center" },
				color = sel and C_orange or C_cell_bg,
				on_click = function()
					params.filter_year = yy
					params.show_year_popup = false
					navigation.invalidate()
				end,
				children = { Text({ key = "fyc_lbl_" .. y, text = tostring(y),
				             style = { width = "100%", height = "100%" } }) }
			}))
		end

		local year_popup_box = Box({
			key   = "year_popup_box",
			style = { width = 260, height = 126, flex_direction = "column",
			          align_items = "center", gap = 10, padding = 16 },
			color = rgba(0.12, 0.15, 0.22, 1),
			children = {
				Text({ key = "yp_title", text = "Select Year",
				          style = { height = 28 }, align = "center", color = C_orange }),
				Box({ key = "yr1", style = { height = 50, flex_direction = "row", gap = 10 }, color = C_transp,
					children = year_cells }),
			}
		})

		-- ── Assemble root children ──────────────────────────────────────────────

		local children = {
			-- Header
			Box({
				key   = "hist_hdr",
				style = { height = 80, flex_direction = "row", align_items = "center",
				          padding_left = 12, padding_right = 12 },
				color = C_header,
				children = {
					Button({
						key   = "hist_back",
						style = { width = 50, height = 50 },
						color = C_transp,
						on_click = function() navigation.pop("slide_right") end,
						children = { Text({ key = "hist_back_lbl", text = "<",
						             style = { width = "100%", height = "100%" } }) }
					}),
					Box({
						key   = "hist_title_box",
						style = { flex_grow = 1, height = 50, flex_direction = "column",
						          align_items = "center", justify_content = "center" },
						color = C_transp,
						children = {
							Text({ key = "hist_title",    text = "Game History",
							          style = { height = 26 }, align = "center" }),
							Text({ key = "hist_subtitle",
							          text = (params.filter_type == "last7") and "Last 7 days"
							               or (params.filter_type == "custom") and string.format("%02d/%d", params.filter_month, params.filter_year)
							               or "Today",
							          style = { height = 20 }, align = "center",
							          color = rgba(0.6, 0.6, 0.7, 1) }),
						}
					}),
					Button({
						key   = "hist_filter_btn",
						style = { width = 80, height = 40, align_items = "center", justify_content = "center" },
						color = rgba(0.20, 0.25, 0.38, 1),
						on_click = function()
							params.show_filter = true
							navigation.invalidate()
						end,
						children = { Text({ key = "hist_filter_lbl", text = "Filter",
						             style = { width = "100%", height = "100%" } }) }
					}),
				}
			}),
			-- Column headers
			col_header,
			Box({ key = "col_sep", style = { height = 1, width = "100%" }, color = C_sep }),
			-- Scrollable page rows
			Scroll({
				key      = "hist_list",
				style    = { flex_grow = 1, flex_direction = "column", gap = 0 },
				color    = C_list_bg,
				_scrollbar = false,
				children = rows,
			}),
			-- Pagination
			Box({ key = "pag_sep", style = { height = 1, width = "100%" }, color = C_sep }),
			pagination,
		}

		-- Filter overlay: top-anchored panel + semi-transparent backdrop below
		if params.show_filter then
			table.insert(children, Popup({
				key = "filter_overlay",
				style = { width = "100%", height = "100%",
				          align_items = "stretch", justify_content = "start" },
				backdrop_color = rgba(0, 0, 0, 0.6),
				_visible = true,
				on_backdrop_click = function()
					params.show_filter = false
					params.show_month_popup = false
					params.show_year_popup  = false
					navigation.invalidate()
				end,
				children = { filter_panel },
			}))
		end

		-- Month picker popup (stacked on top of filter overlay)
		if params.show_month_popup then
			table.insert(children, Popup({
				key = "month_picker_popup",
				style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
				backdrop_color = rgba(0, 0, 0, 0.4),
				_visible = true,
				on_backdrop_click = function()
					params.show_month_popup = false
					navigation.invalidate()
				end,
				children = { month_popup_box },
			}))
		end

		-- Year picker popup (stacked on top of filter overlay)
		if params.show_year_popup then
			table.insert(children, Popup({
				key = "year_picker_popup",
				style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
				backdrop_color = rgba(0, 0, 0, 0.4),
				_visible = true,
				on_backdrop_click = function()
					params.show_year_popup = false
					navigation.invalidate()
				end,
				children = { year_popup_box },
			}))
		end

		return Box({
			key   = "history_root",
			style = { width = "100%", height = "100%", flex_direction = "column" },
			color = C_bg,
			children = children,
		})
	end
}
