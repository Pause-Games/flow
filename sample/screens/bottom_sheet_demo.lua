local flow = require "flow/flow"

local BottomSheet = flow.ui.cp.BottomSheet
local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text

local function reset_sheet_animation(params)
	params.sheet_anim_y = nil
	params.sheet_anim_vel = nil
end

local function sync_sheet_state(params)
	if params.sheet_type ~= params._prev_sheet_type then
		reset_sheet_animation(params)
		params._prev_sheet_type = params.sheet_type
	end

	if params.sheet_size ~= params._prev_sheet_size then
		reset_sheet_animation(params)
		params._prev_sheet_size = params.sheet_size
	end
end

local function build_handle(key)
	return Box({
		key = key .. "_handle_row",
		style = { height = 28, align_items = "center", justify_content = "center" },
		color = vmath.vector4(0, 0, 0, 0),
		children = {
			Box({
				key = key .. "_handle",
				style = { width = 40, height = 5 },
				color = vmath.vector4(0.42, 0.45, 0.52, 1),
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
		color = destructive and vmath.vector4(0.24, 0.15, 0.15, 1) or vmath.vector4(0.15, 0.17, 0.2, 1),
		on_click = on_click,
		children = {
			Box({ key = key .. "_icon", style = { width = 30, height = 30 }, color = icon_color }),
			Text({ key = key .. "_label", text = label, style = { height = 25 } }),
		},
	})
end

local function build_sheet_content(params, close_sheet, open_sheet)
	if params.sheet_type == "actions" then
		return Box({
			key = "sheet_actions",
			style = { width = "100%", height = 304, flex_direction = "column", gap = 0 },
			color = vmath.vector4(0.15, 0.15, 0.2, 1),
			children = {
				build_handle("sheet_actions"),
				Box({
					key = "sheet_actions_title_box",
					style = { height = 64, flex_direction = "column", gap = 4, padding_left = 20, justify_content = "center" },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						Text({ key = "sheet_actions_title", text = "Actions", font = "heading", style = { height = 28 } }),
						Text({ key = "sheet_actions_subtitle", text = "Compact action list with fast dismissal", style = { height = 20 } }),
					},
				}),
				build_list_button("action_share", "Share", vmath.vector4(0.2, 0.2, 0.25, 1), function()
					params.last_action = "Share"
					close_sheet("Share clicked")
				end),
				build_list_button("action_copy", "Copy Link", vmath.vector4(0.2, 0.2, 0.25, 1), function()
					params.last_action = "Copy Link"
					close_sheet("Copy link clicked")
				end),
				build_list_button("action_delete", "Delete", vmath.vector4(0.32, 0.15, 0.15, 1), function()
					params.last_action = "Delete"
					close_sheet("Delete clicked")
				end),
			},
		})
	end

	if params.sheet_type == "info" then
		return Box({
			key = "sheet_info",
			style = { width = "100%", height = 232, flex_direction = "column", gap = 10, padding = 20 },
			color = vmath.vector4(0.12, 0.15, 0.18, 1),
			children = {
				build_handle("sheet_info"),
				Text({ key = "info_title", text = "Information", font = "heading", style = { height = 30 } }),
				Text({ key = "info_text1", text = "This example uses the animated bottom-sheet mode.", style = { height = 24 } }),
				Text({ key = "info_text2", text = "Tap the backdrop, close button, or any action to dismiss.", style = { height = 24 } }),
				Button({
					key = "info_btn_ok",
					style = { width = 132, height = 42, align_self = "end" },
					color = vmath.vector4(0.3, 0.5, 0.6, 1),
					on_click = function()
						params.last_action = "Got it"
						close_sheet("Got it!")
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
			color = vmath.vector4(0.1, 0.12, 0.15, 1),
			children = {
				build_handle("sheet_menu"),
				Box({
					key = "sheet_menu_title_box",
					style = { height = 56, padding_left = 20, justify_content = "center" },
					color = vmath.vector4(0, 0, 0, 0),
					children = {
						Text({ key = "sheet_menu_title", text = "Menu", font = "heading", style = { height = 28 } }),
					},
				}),
				build_menu_button("menu_profile", "Profile", vmath.vector4(0.4, 0.5, 0.7, 1), function()
					params.last_action = "Profile"
					close_sheet("Profile selected")
				end, false),
				build_menu_button("menu_settings", "Settings", vmath.vector4(0.5, 0.6, 0.4, 1), function()
					params.last_action = "Settings"
					open_sheet("options", "full")
					params.message = "Opened settings sheet from menu"
				end, false),
				build_menu_button("menu_help", "Help & Support", vmath.vector4(0.6, 0.5, 0.4, 1), function()
					params.last_action = "Help & Support"
					close_sheet("Help selected")
				end, false),
				build_menu_button("menu_logout", "Logout", vmath.vector4(0.7, 0.4, 0.4, 1), function()
					params.last_action = "Logout"
					close_sheet("Logout selected")
				end, true),
			},
		})
	end

	local panel_height = params.sheet_size == "full" and "100%" or "50%"
	return Box({
		key = "sheet_options",
		style = { width = "100%", height = panel_height, flex_direction = "column", gap = 0 },
		color = vmath.vector4(0.13, 0.15, 0.22, 1),
		children = {
			build_handle("sheet_options"),
			Box({
				key = "sheet_options_title_row",
				style = { height = 60, flex_direction = "row", align_items = "center", padding_left = 20, padding_right = 12 },
				color = vmath.vector4(0, 0, 0, 0),
				children = {
					Box({ key = "sheet_options_title_spacer_l", style = { flex_grow = 1 }, color = vmath.vector4(0, 0, 0, 0) }),
					Text({ key = "sheet_options_title", text = "Quick Settings", font = "heading", style = { height = 28 } }),
					Box({ key = "sheet_options_title_spacer_r", style = { flex_grow = 1 }, color = vmath.vector4(0, 0, 0, 0) }),
					Button({
						key = "sheet_options_close_btn",
						style = { width = 36, height = 36 },
						color = vmath.vector4(0.25, 0.27, 0.35, 1),
						on_click = function()
							close_sheet("Options sheet closed")
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
				color = vmath.vector4(0, 0, 0, 0),
				children = {
					Text({
						key = "sheet_options_meta_text",
						text = params.sheet_size == "full" and "Full-height animated sheet" or "Half-height animated sheet",
						style = { height = 20 },
					}),
				},
			}),
			Box({
				key = "sheet_options_grid",
				style = { flex_grow = 1, flex_direction = "column", gap = 10, padding = 15 },
				color = vmath.vector4(0, 0, 0, 0),
				children = {
					Box({
						key = "sheet_options_row1",
						style = { height = 65, flex_direction = "row", gap = 10 },
						color = vmath.vector4(0, 0, 0, 0),
						children = {
							Button({
								key = "sheet_options_music_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = vmath.vector4(0.87, 0.47, 0.1, 1),
								on_click = function()
									params.last_action = "Music"
									close_sheet("Music selected")
								end,
								children = {
									Text({ key = "sheet_options_music_label", text = "Music", style = { height = 30 } }),
								},
							}),
							Button({
								key = "sheet_options_sound_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = vmath.vector4(0.87, 0.47, 0.1, 1),
								on_click = function()
									params.last_action = "Sound"
									close_sheet("Sound selected")
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
						color = vmath.vector4(0, 0, 0, 0),
						children = {
							Button({
								key = "sheet_options_rules_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = vmath.vector4(0.18, 0.20, 0.28, 1),
								on_click = function()
									params.last_action = "Rules"
									close_sheet("Rules selected")
								end,
								children = {
									Text({ key = "sheet_options_rules_label", text = "Rules", style = { height = 30 } }),
								},
							}),
							Button({
								key = "sheet_options_history_btn",
								style = { flex_grow = 1, height = 65, align_items = "center", justify_content = "center" },
								color = vmath.vector4(0.18, 0.20, 0.28, 1),
								on_click = function()
									params.last_action = "History"
									close_sheet("History selected")
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

return {
	view = function(params, navigation)
		if not params then params = {} end

		if params.sheet_visible == nil then
			params.sheet_visible = false
		end
		if params.sheet_type == nil then
			params.sheet_type = "actions"
		end
		if params.sheet_size == nil then
			params.sheet_size = "half"
		end
		if params.message == nil then
			params.message = "Choose a bottom sheet example"
		end
		sync_sheet_state(params)

		local function open_sheet(sheet_type, sheet_size)
			params.sheet_type = sheet_type
			if sheet_size then
				params.sheet_size = sheet_size
			end
			params.sheet_visible = true
			navigation.invalidate()
		end

		local function close_sheet(message)
			if message then
				params.message = message
			end
			params.sheet_visible = false
			navigation.invalidate()
		end

		local sheet_content = build_sheet_content(params, close_sheet, open_sheet)

		-- Main content
		local main_children = {
			-- Header
			Box({
				key = "header",
				style = { height = 60, flex_direction = "row", gap = 8, align_items = "center" },
				color = vmath.vector4(0.2, 0.2, 0.2, 0.8),
				children = {
					Button({
						key = "btn_back",
						style = { width = 80, height = 40 },
						color = vmath.vector4(0.8, 0.3, 0.3, 1),
						on_click = function() navigation.pop("slide_right") end,
						children = { Text({ key = "btn_back_label", text = "BACK", style = { width = "100%", height = "100%" } }) }
					}),
					Text({
						key = "title",
						text = "Bottom Sheets",
						font = "heading",
						style = { flex_grow = 1, height = 40 }
					})
				}
			}),
			-- Content
			Box({
				key = "content",
				style = { flex_grow = 1, flex_direction = "column", gap = 20, align_items = "center", justify_content = "center", padding = 20 },
				color = vmath.vector4(0.05, 0.05, 0.1, 1),
				children = {
					-- Status message
					Box({
						key = "status_box",
						style = { width = 440, height = 88, flex_direction = "column", gap = 6, align_items = "center", justify_content = "center" },
						color = vmath.vector4(0.15, 0.15, 0.2, 1),
						children = {
							Text({ key = "status_text", text = params.message, style = { height = 28 } }),
							Text({
								key = "status_meta",
								text = "Sheet: " .. params.sheet_type .. "   Size: " .. params.sheet_size .. "   Last action: " .. tostring(params.last_action or "none"),
								style = { height = 20 },
								align = "center",
							}),
						}
					}),
					-- Instruction
					Text({
						key = "instruction",
						text = "Choose a sheet preset. The menu sheet now contains the merged settings flow.",
						style = { height = 25 }
					}),
					-- Buttons row
					Box({
						key = "buttons_row_primary",
						style = { height = 70, flex_direction = "row", gap = 15 },
						color = vmath.vector4(0, 0, 0, 0),
						children = {
							Button({
								key = "btn_actions",
								style = { width = 130, height = 60 },
								color = vmath.vector4(0.3, 0.5, 0.5, 1),
								on_click = function()
									open_sheet("actions")
								end,
								children = { Text({ key = "btn_actions_label", text = "Actions", style = { width = "100%", height = "100%" } }) }
							}),
							Button({
								key = "btn_info",
								style = { width = 130, height = 60 },
								color = vmath.vector4(0.4, 0.4, 0.6, 1),
								on_click = function()
									open_sheet("info")
								end,
								children = { Text({ key = "btn_info_label", text = "Info", style = { width = "100%", height = "100%" } }) }
							}),
							Button({
								key = "btn_menu",
								style = { width = 130, height = 60 },
								color = vmath.vector4(0.5, 0.4, 0.4, 1),
								on_click = function()
									open_sheet("menu")
								end,
								children = { Text({ key = "btn_menu_label", text = "Menu", style = { width = "100%", height = "100%" } }) }
							})
						}
					}),
					-- Info text
					Box({
						key = "info_box",
						style = { width = "80%", height = 74, padding = 15, flex_direction = "column", gap = 6 },
						color = vmath.vector4(0.1, 0.1, 0.15, 1),
						children = {
							Text({
								key = "info_text",
								text = "The old settings screen is now part of the Menu sheet under the Settings action.",
								style = { height = 22 },
								align = "center"
							}),
							Text({
								key = "info_text_detail",
								text = "Tap backdrop, close button, or any action to dismiss.",
								style = { height = 20 },
								align = "center"
							})
						}
					})
				}
			})
		}

		table.insert(main_children, BottomSheet({
			key = "bottom_sheet_overlay",
			backdrop_color = vmath.vector4(0, 0, 0, 0.55),
			_open = params.sheet_visible,
			_anim_y = params.sheet_anim_y,
			_anim_velocity = params.sheet_anim_vel,
			_on_anim_update = function(y, vel)
				params.sheet_anim_y = y
				params.sheet_anim_vel = vel
			end,
			on_backdrop_click = function()
				close_sheet("Dismissed by backdrop")
			end,
			children = { sheet_content }
		}))

		return Box({
			key = "bottom_sheet_demo_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0, padding = 0 },
			color = vmath.vector4(0.1, 0.1, 0.15, 1),
			children = main_children
		})
	end
}
