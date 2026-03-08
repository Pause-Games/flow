local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text

local function build_handle(key)
	return Box({
		key = key .. "_handle_row",
		style = { height = 28, align_items = "center", justify_content = "center" },
		color = "transparent",
		children = {
			Box({
				key = key .. "_handle",
				style = { width = 40, height = 5 },
				color = rgba(0.42, 0.45, 0.52, 1),
			}),
		},
	})
end

local function build_list_button(key, label, color, on_click)
	return Button({
		key = key,
		style = { height = 54, padding_left = 20, justify_content = "center" },
		color = color,
		on_click = on_click,
		children = {
			Text({ key = key .. "_label", text = label, style = { height = 26 } }),
		},
	})
end

local function build_menu_button(key, label, icon_color, on_click, destructive)
	return Button({
		key = key,
		style = { height = 56, padding_left = 20, flex_direction = "row", gap = 15, align_items = "center" },
		color = destructive and rgba(0.24, 0.15, 0.15, 1) or rgba(0.15, 0.17, 0.2, 1),
		on_click = on_click,
		children = {
			Box({ key = key .. "_icon", style = { width = 30, height = 30 }, color = icon_color }),
			Text({ key = key .. "_label", text = label, style = { height = 25 } }),
		},
	})
end

return function(params, api)
	params.sheet_type = params.sheet_type or "actions"
	params.sheet_size = params.sheet_size or "half"

	local function dismiss(result)
		api.dismiss(result)
	end

	if params.sheet_type == "actions" then
		return Box({
			key = "sheet_actions",
			style = { width = "100%", height = 304, flex_direction = "column", gap = 0 },
			color = rgba(0.15, 0.15, 0.2, 1),
			children = {
				build_handle("sheet_actions"),
				Box({
					key = "sheet_actions_title_box",
					style = { height = 64, flex_direction = "column", gap = 4, padding_left = 20, justify_content = "center" },
					color = "transparent",
					children = {
						Text({ key = "sheet_actions_title", text = "Actions", font = "heading", style = { height = 28 } }),
						Text({ key = "sheet_actions_subtitle", text = "Compact action list with hosted dismissal", style = { height = 20 } }),
					},
				}),
				build_list_button("action_share", "Share", rgba(0.2, 0.2, 0.25, 1), function()
					params.last_action = "Share"
					dismiss("Share clicked")
				end),
				build_list_button("action_copy", "Copy Link", rgba(0.2, 0.2, 0.25, 1), function()
					params.last_action = "Copy Link"
					dismiss("Copy link clicked")
				end),
				build_list_button("action_delete", "Delete", rgba(0.32, 0.15, 0.15, 1), function()
					params.last_action = "Delete"
					dismiss("Delete clicked")
				end),
			},
		})
	end

	if params.sheet_type == "info" then
		return Box({
			key = "sheet_info",
			style = { width = "100%", height = 232, flex_direction = "column", gap = 10, padding = 20 },
			color = rgba(0.12, 0.15, 0.18, 1),
			children = {
				build_handle("sheet_info"),
				Text({ key = "info_title", text = "Information", font = "heading", style = { height = 30 } }),
				Text({ key = "info_text1", text = "This sample bottom sheet is hosted outside the screen tree.", style = { height = 24 } }),
				Text({ key = "info_text2", text = "Tap the backdrop or any action to dismiss it.", style = { height = 24 } }),
				Button({
					key = "info_btn_ok",
					style = { width = 132, height = 42, align_self = "end" },
					color = rgba(0.3, 0.5, 0.6, 1),
					on_click = function()
						params.last_action = "Got it"
						dismiss("Got it!")
					end,
					children = { Text({ key = "info_btn_ok_label", text = "Got it", style = { width = "100%", height = "100%" } }) },
				}),
			},
		})
	end

	if params.sheet_type == "menu" then
		return Box({
			key = "sheet_menu",
			style = { width = "100%", height = 320, flex_direction = "column", gap = 0 },
			color = rgba(0.1, 0.12, 0.15, 1),
			children = {
				build_handle("sheet_menu"),
				Box({
					key = "sheet_menu_title_box",
					style = { height = 56, padding_left = 20, justify_content = "center" },
					color = "transparent",
					children = {
						Text({ key = "sheet_menu_title", text = "Menu", font = "heading", style = { height = 28 } }),
					},
				}),
				build_menu_button("menu_profile", "Profile", rgba(0.4, 0.5, 0.7, 1), function()
					params.last_action = "Profile"
					dismiss("Profile selected")
				end, false),
				build_menu_button("menu_settings", "Settings", rgba(0.5, 0.6, 0.4, 1), function()
					params.last_action = "Settings"
					params.sheet_type = "options"
					params.sheet_size = "full"
					api.invalidate()
				end, false),
				build_menu_button("menu_help", "Help & Support", rgba(0.6, 0.5, 0.4, 1), function()
					params.last_action = "Help & Support"
					dismiss("Help selected")
				end, false),
				build_menu_button("menu_logout", "Logout", rgba(0.7, 0.4, 0.4, 1), function()
					params.last_action = "Logout"
					dismiss("Logout selected")
				end, true),
			},
		})
	end

	local panel_height = params.sheet_size == "full" and "100%" or "50%"
	return Box({
		key = "sheet_options",
		style = { width = "100%", height = panel_height, flex_direction = "column", gap = 0 },
		color = rgba(0.13, 0.15, 0.22, 1),
		children = {
			build_handle("sheet_options"),
			Box({
				key = "sheet_options_title_row",
				style = { height = 60, flex_direction = "row", align_items = "center", padding_left = 20, padding_right = 12 },
				color = "transparent",
				children = {
					Box({ key = "sheet_options_title_spacer_l", style = { flex_grow = 1 }, color = "transparent" }),
					Text({ key = "sheet_options_title", text = "Quick Settings", font = "heading", style = { height = 28 } }),
					Box({ key = "sheet_options_title_spacer_r", style = { flex_grow = 1 }, color = "transparent" }),
					Button({
						key = "sheet_options_close_btn",
						style = { width = 36, height = 36 },
						color = rgba(0.25, 0.27, 0.35, 1),
						on_click = function()
							dismiss("Options sheet closed")
						end,
						children = {
							Text({ key = "sheet_options_close_label", text = "X", style = { width = "100%", height = "100%" } }),
						},
					}),
				},
			}),
			Box({
				key = "sheet_options_meta",
				style = { height = 34, padding_left = 20, justify_content = "center" },
				color = "transparent",
				children = {
					Text({
						key = "sheet_options_meta_text",
						text = params.sheet_size == "full" and "Full-height hosted sheet" or "Half-height hosted sheet",
						style = { height = 20 },
					}),
				},
			}),
			Box({
				key = "sheet_options_grid",
				style = { flex_grow = 1, flex_direction = "column", gap = 10, padding = 15 },
				color = "transparent",
				children = {
					Box({
						key = "sheet_options_row1",
						style = { height = 65, flex_direction = "row", gap = 10 },
						color = "transparent",
						children = {
							Button({
								key = "sheet_options_music_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = rgba(0.87, 0.47, 0.1, 1),
								on_click = function()
									params.last_action = "Music"
									dismiss("Music selected")
								end,
								children = {
									Text({ key = "sheet_options_music_label", text = "Music", style = { height = 30 } }),
								},
							}),
							Button({
								key = "sheet_options_sound_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = rgba(0.87, 0.47, 0.1, 1),
								on_click = function()
									params.last_action = "Sound"
									dismiss("Sound selected")
								end,
								children = {
									Text({ key = "sheet_options_sound_label", text = "Sound", style = { height = 30 } }),
								},
							}),
						},
					}),
					Box({
						key = "sheet_options_row2",
						style = { height = 65, flex_direction = "row", gap = 10 },
						color = "transparent",
						children = {
							Button({
								key = "sheet_options_rules_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = rgba(0.18, 0.20, 0.28, 1),
								on_click = function()
									params.last_action = "Rules"
									dismiss("Rules selected")
								end,
								children = {
									Text({ key = "sheet_options_rules_label", text = "Rules", style = { height = 30 } }),
								},
							}),
							Button({
								key = "sheet_options_history_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = rgba(0.18, 0.20, 0.28, 1),
								on_click = function()
									params.last_action = "History"
									dismiss("History selected")
								end,
								children = {
									Text({ key = "sheet_options_history_label", text = "History", style = { height = 30 } }),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end
