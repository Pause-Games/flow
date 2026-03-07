local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Popup = flow.ui.cp.Popup
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		-- Initialize params if nil
		if not params then params = {} end

		-- Initialize state
		if params.popup_visible == nil then
			params.popup_visible = false
		end
		if params.popup_type == nil then
			params.popup_type = "confirm"
		end
		if params.message == nil then
			params.message = "Click a button to show a popup"
		end

		-- Close popup helper
		local function close_popup()
			params.popup_visible = false
			navigation.invalidate()
		end

		-- Build popup content based on type
		local popup_content = nil
		if params.popup_visible then
			if params.popup_type == "confirm" then
				popup_content = Box({
					key = "popup_content",
					style = { width = 350, height = 180, flex_direction = "column", gap = 15, padding = 20, align_items = "center" },
					color = vmath.vector4(0.15, 0.15, 0.2, 1),
					children = {
						Text({
							key = "popup_title",
							text = "Confirm Action",
							style = { height = 30 }
						}),
						Text({
							key = "popup_message",
							text = "Are you sure you want to proceed?",
							style = { height = 25 }
						}),
						Box({
							key = "popup_buttons",
							style = { width = "100%", height = 55, flex_direction = "row", gap = 10, justify_content = "center" },
							children = {
								Button({
									key = "popup_btn_cancel",
									style = { width = 120, height = 45 },
									color = vmath.vector4(0.5, 0.3, 0.3, 1),
									on_click = function()
										params.message = "Cancelled!"
										close_popup()
									end,
									children = {
										Text({
											key = "popup_btn_cancel_label",
											text = "Cancel",
											style = { width = "100%", height = "100%" }
										})
									}
								}),
								Button({
									key = "popup_btn_confirm",
									style = { width = 120, height = 45 },
									color = vmath.vector4(0.3, 0.6, 0.4, 1),
									on_click = function()
										params.message = "Confirmed!"
										close_popup()
									end,
									children = {
										Text({
											key = "popup_btn_confirm_label",
											text = "Confirm",
											style = { width = "100%", height = "100%" }
										})
									}
								})
							}
						})
					}
				})
			elseif params.popup_type == "alert" then
				popup_content = Box({
					key = "popup_content",
					style = { width = 300, height = 220, flex_direction = "column", gap = 15, padding = 20, align_items = "center" },
					color = vmath.vector4(0.2, 0.15, 0.15, 1),
					children = {
						Text({
							key = "popup_title",
							text = "Alert!",
							style = { height = 30 }
						}),
						Box({
							key = "popup_icon",
							style = { width = 60, height = 60 },
							color = vmath.vector4(0.9, 0.4, 0.3, 1)
						}),
						Text({
							key = "popup_message",
							text = "Something important happened!",
							style = { height = 25 }
						}),
						Button({
							key = "popup_btn_ok",
							style = { width = 150, height = 45 },
							color = vmath.vector4(0.4, 0.5, 0.7, 1),
							on_click = function()
								params.message = "Alert dismissed"
								close_popup()
							end,
							children = {
								Text({
									key = "popup_btn_ok_label",
									text = "OK",
									style = { width = "100%", height = "100%" }
								})
							}
						})
					}
				})
			elseif params.popup_type == "form" then
				popup_content = Box({
					key = "popup_content",
					style = { width = 380, height = 280, flex_direction = "column", gap = 12, padding = 20 },
					color = vmath.vector4(0.12, 0.15, 0.18, 1),
					children = {
						Text({
							key = "popup_title",
							text = "Settings",
							style = { height = 30 },
							align = "center"
						}),
						-- Fake form rows
						Box({
							key = "form_row1",
							style = { height = 40, flex_direction = "row", gap = 10, align_items = "center" },
							children = {
								Text({
									key = "form_label1",
									text = "Sound:",
									style = { width = 100, height = 30 }
								}),
								Box({
									key = "form_field1",
									style = { flex_grow = 1, height = 30 },
									color = vmath.vector4(0.3, 0.5, 0.3, 1)
								})
							}
						}),
						Box({
							key = "form_row2",
							style = { height = 40, flex_direction = "row", gap = 10, align_items = "center" },
							children = {
								Text({
									key = "form_label2",
									text = "Music:",
									style = { width = 100, height = 30 }
								}),
								Box({
									key = "form_field2",
									style = { flex_grow = 1, height = 30 },
									color = vmath.vector4(0.5, 0.5, 0.3, 1)
								})
							}
						}),
						Box({
							key = "form_row3",
							style = { height = 40, flex_direction = "row", gap = 10, align_items = "center" },
							children = {
								Text({
									key = "form_label3",
									text = "Vibration:",
									style = { width = 100, height = 30 }
								}),
								Box({
									key = "form_field3",
									style = { flex_grow = 1, height = 30 },
									color = vmath.vector4(0.3, 0.3, 0.5, 1)
								})
							}
						}),
						Box({
							key = "form_buttons",
							style = { height = 50, flex_direction = "row", gap = 10, justify_content = "end", padding_top = 10 },
							children = {
								Button({
									key = "form_btn_cancel",
									style = { width = 100, height = 40 },
									color = vmath.vector4(0.4, 0.3, 0.3, 1),
									on_click = function()
										params.message = "Settings not saved"
										close_popup()
									end,
									children = {
										Text({
											key = "form_btn_cancel_label",
											text = "Cancel",
											style = { width = "100%", height = "100%" }
										})
									}
								}),
								Button({
									key = "form_btn_save",
									style = { width = 100, height = 40 },
									color = vmath.vector4(0.3, 0.5, 0.6, 1),
									on_click = function()
										params.message = "Settings saved!"
										close_popup()
									end,
									children = {
										Text({
											key = "form_btn_save_label",
											text = "Save",
											style = { width = "100%", height = "100%" }
										})
									}
								})
							}
						})
					}
				})
			end
		end

		-- Main content children
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
						on_click = function()
							navigation.pop("slide_right")
						end,
						children = {
							Text({
								key = "btn_back_label",
								text = "BACK",
								style = { width = "100%", height = "100%" }
							})
						}
					}),
					Text({
						key = "title",
						text = "Popup Demo",
						style = { flex_grow = 1, height = 40 }
					})
				}
			}),
			-- Content area
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
							Text({
								key = "status_text",
								text = params.message,
								style = { height = 30 }
							})
						}
					}),
					-- Popup trigger buttons
					Text({
						key = "instruction",
						text = "Choose a popup type:",
						style = { height = 25 }
					}),
					Box({
						key = "buttons_row",
						style = { height = 70, flex_direction = "row", gap = 15 },
						children = {
							Button({
								key = "btn_confirm",
								style = { width = 140, height = 60 },
								color = vmath.vector4(0.3, 0.5, 0.4, 1),
								on_click = function()
									params.popup_type = "confirm"
									params.popup_visible = true
									navigation.invalidate()
								end,
								children = {
									Text({
										key = "btn_confirm_label",
										text = "Confirm\nDialog",
										style = { width = "100%", height = "100%" },
										align = "center"
									})
								}
							}),
							Button({
								key = "btn_alert",
								style = { width = 140, height = 60 },
								color = vmath.vector4(0.6, 0.4, 0.3, 1),
								on_click = function()
									params.popup_type = "alert"
									params.popup_visible = true
									navigation.invalidate()
								end,
								children = {
									Text({
										key = "btn_alert_label",
										text = "Alert\nPopup",
										style = { width = "100%", height = "100%" },
										align = "center"
									})
								}
							}),
							Button({
								key = "btn_form",
								style = { width = 140, height = 60 },
								color = vmath.vector4(0.4, 0.4, 0.6, 1),
								on_click = function()
									params.popup_type = "form"
									params.popup_visible = true
									navigation.invalidate()
								end,
								children = {
									Text({
										key = "btn_form_label",
										text = "Settings\nForm",
										style = { width = "100%", height = "100%" },
										align = "center"
									})
								}
							})
						}
					}),
					-- Info text
					Box({
						key = "info_box",
						style = { width = "80%", height = 80, padding = 15 },
						color = vmath.vector4(0.1, 0.1, 0.15, 1),
						children = {
							Text({
								key = "info_text",
								text = "Popups appear as modal overlays.\nClick the backdrop to close, or use the buttons.",
								style = { height = 50 },
								align = "center"
							})
						}
					})
				}
			})
		}

		-- Add popup if visible
		if params.popup_visible and popup_content then
			table.insert(main_children, Popup({
				key = "popup_overlay",
				style = { width = "100%", height = "100%", align_items = "center", justify_content = "center" },
				backdrop_color = vmath.vector4(0, 0, 0, 0.7),
				_visible = true,
				on_backdrop_click = function()
					params.message = "Closed by backdrop click"
					close_popup()
				end,
				children = { popup_content }
			}))
		end

		return Box({
			key = "popup_demo_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0, padding = 0 },
			color = vmath.vector4(0.1, 0.1, 0.15, 1),
			children = main_children
		})
	end
}
