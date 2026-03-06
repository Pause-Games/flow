local flow = require "flow/flow"

local BottomSheet = flow.ui.cp.BottomSheet
local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		if not params then params = {} end

		if params.sheet_visible == nil then
			params.sheet_visible = false
		end
		if params.sheet_type == nil then
			params.sheet_type = "actions"
		end
		if params.message == nil then
			params.message = "Tap a button to show a bottom sheet"
		end

		local function close_sheet()
			params.sheet_visible = false
			navigation.mark_dirty()
		end

		-- Build sheet content based on type
		local sheet_content = nil
		if params.sheet_visible then
			if params.sheet_type == "actions" then
				sheet_content = Box({
					key = "sheet_content",
					style = { width = "100%", height = 280, flex_direction = "column", gap = 0, padding = 0 },
					color = vmath.vector4(0.15, 0.15, 0.2, 1),
					children = {
						-- Handle bar
						Box({
							key = "sheet_handle_container",
							style = { height = 30, align_items = "center", justify_content = "center" },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								Box({
									key = "sheet_handle",
									style = { width = 40, height = 5 },
									color = vmath.vector4(0.4, 0.4, 0.4, 1)
								})
							}
						}),
						-- Title
						Box({
							key = "sheet_title_box",
							style = { height = 40, padding_left = 20, justify_content = "center" },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								Text({
									key = "sheet_title",
									text = "Actions",
									style = { height = 25 }
								})
							}
						}),
						-- Action buttons
						Button({
							key = "action_share",
							style = { height = 50, padding_left = 20, justify_content = "center" },
							color = vmath.vector4(0.2, 0.2, 0.25, 1),
							on_click = function()
								params.message = "Share clicked"
								close_sheet()
							end,
							children = { Text({ key = "action_share_label", text = "Share", style = { height = 25 } }) }
						}),
						Button({
							key = "action_copy",
							style = { height = 50, padding_left = 20, justify_content = "center" },
							color = vmath.vector4(0.2, 0.2, 0.25, 1),
							on_click = function()
								params.message = "Copy link clicked"
								close_sheet()
							end,
							children = { Text({ key = "action_copy_label", text = "Copy Link", style = { height = 25 } }) }
						}),
						Button({
							key = "action_delete",
							style = { height = 50, padding_left = 20, justify_content = "center" },
							color = vmath.vector4(0.3, 0.15, 0.15, 1),
							on_click = function()
								params.message = "Delete clicked"
								close_sheet()
							end,
							children = { Text({ key = "action_delete_label", text = "Delete", style = { height = 25 } }) }
						})
					}
				})
			elseif params.sheet_type == "info" then
				sheet_content = Box({
					key = "sheet_content",
					style = { width = "100%", height = 200, flex_direction = "column", gap = 10, padding = 20 },
					color = vmath.vector4(0.12, 0.15, 0.18, 1),
					children = {
						-- Handle bar
						Box({
							key = "sheet_handle_container",
							style = { height = 20, align_items = "center", justify_content = "start" },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								Box({
									key = "sheet_handle",
									style = { width = 40, height = 5 },
									color = vmath.vector4(0.4, 0.4, 0.4, 1)
								})
							}
						}),
						Text({
							key = "info_title",
							text = "Information",
							style = { height = 30 }
						}),
						Text({
							key = "info_text1",
							text = "This is a bottom sheet with information.",
							style = { height = 25 }
						}),
						Text({
							key = "info_text2",
							text = "Tap the backdrop to dismiss.",
							style = { height = 25 }
						}),
						Button({
							key = "info_btn_ok",
							style = { width = 120, height = 40, align_self = "end" },
							color = vmath.vector4(0.3, 0.5, 0.6, 1),
							on_click = function()
								params.message = "Got it!"
								close_sheet()
							end,
							children = { Text({ key = "info_btn_ok_label", text = "Got it", style = { width = "100%", height = "100%" } }) }
						})
					}
				})
			elseif params.sheet_type == "menu" then
				sheet_content = Box({
					key = "sheet_content",
					style = { width = "100%", height = 320, flex_direction = "column", gap = 0 },
					color = vmath.vector4(0.1, 0.12, 0.15, 1),
					children = {
						-- Handle bar
						Box({
							key = "sheet_handle_container",
							style = { height = 25, align_items = "center", justify_content = "center" },
							color = vmath.vector4(0, 0, 0, 0),
							children = {
								Box({
									key = "sheet_handle",
									style = { width = 40, height = 5 },
									color = vmath.vector4(0.4, 0.4, 0.4, 1)
								})
							}
						}),
						-- Menu items
						Button({
							key = "menu_profile",
							style = { height = 55, padding_left = 20, flex_direction = "row", gap = 15, align_items = "center" },
							color = vmath.vector4(0.15, 0.17, 0.2, 1),
							on_click = function() params.message = "Profile selected"; close_sheet() end,
							children = {
								Box({ key = "menu_profile_icon", style = { width = 30, height = 30 }, color = vmath.vector4(0.4, 0.5, 0.7, 1) }),
								Text({ key = "menu_profile_label", text = "Profile", style = { height = 25 } })
							}
						}),
						Button({
							key = "menu_settings",
							style = { height = 55, padding_left = 20, flex_direction = "row", gap = 15, align_items = "center" },
							color = vmath.vector4(0.15, 0.17, 0.2, 1),
							on_click = function() params.message = "Settings selected"; close_sheet() end,
							children = {
								Box({ key = "menu_settings_icon", style = { width = 30, height = 30 }, color = vmath.vector4(0.5, 0.6, 0.4, 1) }),
								Text({ key = "menu_settings_label", text = "Settings", style = { height = 25 } })
							}
						}),
						Button({
							key = "menu_help",
							style = { height = 55, padding_left = 20, flex_direction = "row", gap = 15, align_items = "center" },
							color = vmath.vector4(0.15, 0.17, 0.2, 1),
							on_click = function() params.message = "Help selected"; close_sheet() end,
							children = {
								Box({ key = "menu_help_icon", style = { width = 30, height = 30 }, color = vmath.vector4(0.6, 0.5, 0.4, 1) }),
								Text({ key = "menu_help_label", text = "Help & Support", style = { height = 25 } })
							}
						}),
						Button({
							key = "menu_logout",
							style = { height = 55, padding_left = 20, flex_direction = "row", gap = 15, align_items = "center" },
							color = vmath.vector4(0.2, 0.15, 0.15, 1),
							on_click = function() params.message = "Logout selected"; close_sheet() end,
							children = {
								Box({ key = "menu_logout_icon", style = { width = 30, height = 30 }, color = vmath.vector4(0.7, 0.4, 0.4, 1) }),
								Text({ key = "menu_logout_label", text = "Logout", style = { height = 25 } })
							}
						})
					}
				})
			end
		end

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
						text = "Bottom Sheet Demo",
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
						style = { width = 400, height = 50, align_items = "center", justify_content = "center" },
						color = vmath.vector4(0.15, 0.15, 0.2, 1),
						children = {
							Text({ key = "status_text", text = params.message, style = { height = 30 } })
						}
					}),
					-- Instruction
					Text({
						key = "instruction",
						text = "Choose a bottom sheet type:",
						style = { height = 25 }
					}),
					-- Buttons row
					Box({
						key = "buttons_row",
						style = { height = 70, flex_direction = "row", gap = 15 },
						color = vmath.vector4(0, 0, 0, 0),
						children = {
							Button({
								key = "btn_actions",
								style = { width = 130, height = 60 },
								color = vmath.vector4(0.3, 0.5, 0.5, 1),
								on_click = function()
									params.sheet_type = "actions"
									params.sheet_visible = true
									navigation.mark_dirty()
								end,
								children = { Text({ key = "btn_actions_label", text = "Actions", style = { width = "100%", height = "100%" } }) }
							}),
							Button({
								key = "btn_info",
								style = { width = 130, height = 60 },
								color = vmath.vector4(0.4, 0.4, 0.6, 1),
								on_click = function()
									params.sheet_type = "info"
									params.sheet_visible = true
									navigation.mark_dirty()
								end,
								children = { Text({ key = "btn_info_label", text = "Info", style = { width = "100%", height = "100%" } }) }
							}),
							Button({
								key = "btn_menu",
								style = { width = 130, height = 60 },
								color = vmath.vector4(0.5, 0.4, 0.4, 1),
								on_click = function()
									params.sheet_type = "menu"
									params.sheet_visible = true
									navigation.mark_dirty()
								end,
								children = { Text({ key = "btn_menu_label", text = "Menu", style = { width = "100%", height = "100%" } }) }
							})
						}
					}),
					-- Info text
					Box({
						key = "info_box",
						style = { width = "80%", height = 60, padding = 15 },
						color = vmath.vector4(0.1, 0.1, 0.15, 1),
						children = {
							Text({
								key = "info_text",
								text = "Bottom sheets slide up from the bottom.\nTap backdrop or buttons to dismiss.",
								style = { height = 40 },
								align = "center"
							})
						}
					})
				}
			})
		}

		-- Add bottom sheet if visible
		if params.sheet_visible and sheet_content then
			table.insert(main_children, BottomSheet({
				key = "bottom_sheet_overlay",
				backdrop_color = vmath.vector4(0, 0, 0, 0.5),
				_visible = true,
				on_backdrop_click = function()
					params.message = "Dismissed by backdrop"
					close_sheet()
				end,
				children = { sheet_content }
			}))
		end

		return Box({
			key = "bottom_sheet_demo_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0, padding = 0 },
			color = vmath.vector4(0.1, 0.1, 0.15, 1),
			children = main_children
		})
	end
}
