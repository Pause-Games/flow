local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		local non_gui_result = params and params.non_gui_result or nil
		local result_status = non_gui_result and tostring(non_gui_result.status or "unknown") or "none"
		local result_score = non_gui_result and tostring(non_gui_result.score or "-") or "-"
		local result_level = non_gui_result and tostring(non_gui_result.entered_level or "-") or "-"

		return Box({
			key = "hub_root",
			style = { width="100%", height="100%", flex_direction="column", gap=0, padding=0 },
			color = vmath.vector4(0.05, 0.05, 0.1, 1),
			children = {
				-- Header with title at top left
				Box({
					key = "header",
					style = { height=88, padding_left=20, padding_top=10, padding_bottom=10, flex_direction="column", gap=4, align_items="start", justify_content="center" },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						Text({
							key = "hub_title",
							text = "Flow UI Demo Hub",
							font = "heading",
							style = { height=30 }
						}),
						Text({
							key = "hub_font_hint",
							text = "Header uses Text.font = \"heading\" from sample.gui",
							color = vmath.vector4(0.80, 0.86, 0.98, 1),
							style = { height = 20 }
						})
					}
				}),
				-- Main content area with centered grid
				Box({
					key = "content",
					style = { flex_grow=1, align_items="center", justify_content="center" },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						Box({
							key = "grid",
							style = { width=456, height=410, flex_direction="column", gap=12 },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								-- Row 1
								Box({
									key = "row1",
									style = { height=70, flex_direction="row", gap=12 },
									color = vmath.vector4(0, 0, 0, 0),
									children = {
										Button({
											key = "btn_buttons",
											style = { width=140, height=70 },
											color = vmath.vector4(0.2, 0.4, 0.7, 1),
											on_click = function() navigation.push("buttons_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_buttons_label", text = "BUTTONS", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_layouts",
											style = { width=140, height=70 },
											color = vmath.vector4(0.4, 0.2, 0.7, 1),
											on_click = function() navigation.push("layouts_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_layouts_label", text = "LAYOUTS", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_alignment",
											style = { width=140, height=70 },
											color = vmath.vector4(0.7, 0.4, 0.2, 1),
											on_click = function() navigation.push("alignment_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_alignment_label", text = "ALIGNMENT", style = { width="100%", height="100%" } }) }
										})
									}
								}),
								-- Row 2
								Box({
									key = "row2",
									style = { height=70, flex_direction="row", gap=12 },
									color = vmath.vector4(0, 0, 0, 0),
									children = {
										Button({
											key = "btn_scroll",
											style = { width=140, height=70 },
											color = vmath.vector4(0.3, 0.7, 0.5, 1),
											on_click = function() navigation.push("scroll_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_scroll_label", text = "SCROLL", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_counter",
											style = { width=140, height=70 },
											color = vmath.vector4(0.6, 0.3, 0.7, 1),
											on_click = function() navigation.push("counter_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_counter_label", text = "COUNTER", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_game_guide",
											style = { width=140, height=70 },
											color = vmath.vector4(0.7, 0.5, 0.3, 1),
											on_click = function() navigation.push("game_guide", nil, "slide_left") end,
											children = { Text({ key = "btn_game_guide_label", text = "GUIDE", style = { width="100%", height="100%" } }) }
										})
									}
								}),
								-- Row 3
								Box({
									key = "row3",
									style = { height=70, flex_direction="row", gap=12 },
									color = vmath.vector4(0, 0, 0, 0),
									children = {
										Button({
											key = "btn_hscroll",
											style = { width=140, height=70 },
											color = vmath.vector4(0.8, 0.4, 0.6, 1),
											on_click = function() navigation.push("horizontal_scroll_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_hscroll_label", text = "H-SCROLL", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_popup",
											style = { width=140, height=70 },
											color = vmath.vector4(0.5, 0.6, 0.8, 1),
											on_click = function() navigation.push("popup_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_popup_label", text = "POPUP", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_bottom_sheet",
											style = { width=140, height=70 },
											color = vmath.vector4(0.4, 0.6, 0.5, 1),
											on_click = function() navigation.push("bottom_sheet_demo", nil, "slide_left") end,
											children = { Text({ key = "btn_bottom_sheet_label", text = "SHEET", style = { width="100%", height="100%" } }) }
										})
									}
								}),
								-- Row 4
								Box({
									key = "row4",
									style = { height=70, flex_direction="row", gap=12 },
									color = vmath.vector4(0, 0, 0, 0),
									children = {
										Button({
											key = "btn_history",
											style = { width=210, height=70 },
											color = vmath.vector4(0.2, 0.45, 0.70, 1),
											on_click = function() navigation.push("history", nil, "slide_left") end,
											children = { Text({ key = "btn_history_label", text = "HISTORY", style = { width="100%", height="100%" } }) }
										}),
										Button({
											key = "btn_non_gui_flow",
											style = { width=210, height=70 },
											color = vmath.vector4(0.20, 0.58, 0.52, 1),
											on_click = function()
												msg.post("main:/navigation#navigation_bootstrap", hash("open_non_gui_flow"), {
													level = 7,
													opened_from = "hub",
													previous_result = non_gui_result,
												})
											end,
											children = { Text({ key = "btn_non_gui_flow_label", text = "SCRIPT FLOW", style = { width="100%", height="100%" } }) }
										})
									}
								}),
								Box({
									key = "non_gui_status",
									style = { min_height = 82, flex_direction = "column", gap = 6, padding = 12 },
									color = vmath.vector4(0.10, 0.14, 0.22, 1),
									children = {
										Text({
											key = "non_gui_status_title",
											text = "Non-GUI navigation result",
											style = { height = 22 },
										}),
										Text({
											key = "non_gui_status_summary",
											text = "Status: " .. result_status .. "   Score: " .. result_score .. "   Level: " .. result_level,
											style = { height = 22 },
										}),
										Text({
											key = "non_gui_status_detail",
											text = "Opened and completed through navigation_bootstrap.script",
											style = { height = 22 },
										}),
									},
								})
							}
						})
					}
				})
			}
		})
	end
}
