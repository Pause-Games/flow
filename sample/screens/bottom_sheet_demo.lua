local flow = require "flow/flow"
local rgba = flow.color.rgba

local bottom_sheet_sample = require "sample/screens/bottom_sheet/shared"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text

local function open_sheet(params, navigation, sheet_type, sheet_size)
	params.sheet_type = sheet_type
	params.sheet_size = sheet_size or "half"
	params.sheet_active = true
	params.message = "Opening " .. sheet_type .. " sheet"
	msg.post(bottom_sheet_sample.host_url(), bottom_sheet_sample.OPEN_MESSAGE_ID, {
		params = {
			sheet_type = params.sheet_type,
			sheet_size = params.sheet_size,
			last_action = params.last_action,
		},
	})
	navigation.invalidate()
end

return {
	view = function(params, navigation)
		if not params then params = {} end
		params.sheet_active = params.sheet_active == true
		params.sheet_type = params.sheet_type or "actions"
		params.sheet_size = params.sheet_size or "half"
		params.message = params.message or "Use the hosted API to present a bottom sheet"

		return Box({
			key = "bottom_sheet_demo_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0, padding = 0 },
			color = rgba(0.1, 0.1, 0.15, 1),
			children = {
				Box({
					key = "header",
					style = { height = 60, flex_direction = "row", gap = 8, align_items = "center" },
					color = rgba(0.2, 0.2, 0.2, 0.8),
					children = {
						Button({
							key = "btn_back",
							style = { width = 80, height = 40 },
							color = rgba(0.8, 0.3, 0.3, 1),
							on_click = function() navigation.pop("slide_right") end,
							children = { Text({ key = "btn_back_label", text = "BACK", style = { width = "100%", height = "100%" } }) },
						}),
						Text({
							key = "title",
							text = "Bottom Sheet Host",
							font = "heading",
							style = { flex_grow = 1, height = 40 },
						}),
					},
				}),
				Box({
					key = "content",
					style = { flex_grow = 1, flex_direction = "column", gap = 20, align_items = "center", justify_content = "center", padding = 20 },
					color = rgba(0.05, 0.05, 0.1, 1),
					children = {
						Box({
							key = "status_box",
							style = { width = 470, height = 100, flex_direction = "column", gap = 6, align_items = "center", justify_content = "center" },
							color = rgba(0.15, 0.15, 0.2, 1),
							children = {
								Text({ key = "status_text", text = params.message, style = { height = 28 } }),
								Text({
									key = "status_meta",
									text = "Active: " .. (params.sheet_active and "yes" or "no")
										.. "   Sheet: " .. params.sheet_type
										.. "   Size: " .. params.sheet_size
										.. "   Last action: " .. tostring(params.last_action or "none"),
									style = { height = 20 },
									align = "center",
								}),
							},
						}),
						Text({
							key = "instruction",
							text = "These buttons post messages to a dedicated bottom-sheet host gui.",
							style = { height = 25 },
							align = "center",
						}),
						Box({
							key = "buttons_row_primary",
							style = { height = 70, flex_direction = "row", gap = 15 },
							color = "rgba(0, 0, 0, 0)",
							children = {
								Button({
									key = "btn_actions",
									style = { width = 130, height = 60 },
									color = rgba(0.3, 0.5, 0.5, 1),
									on_click = function()
										open_sheet(params, navigation, "actions", "half")
									end,
									children = { Text({ key = "btn_actions_label", text = "Actions", style = { width = "100%", height = "100%" } }) },
								}),
								Button({
									key = "btn_info",
									style = { width = 130, height = 60 },
									color = rgba(0.4, 0.4, 0.6, 1),
									on_click = function()
										open_sheet(params, navigation, "info", "half")
									end,
									children = { Text({ key = "btn_info_label", text = "Info", style = { width = "100%", height = "100%" } }) },
								}),
								Button({
									key = "btn_menu",
									style = { width = 130, height = 60 },
									color = rgba(0.5, 0.4, 0.4, 1),
									on_click = function()
										open_sheet(params, navigation, "menu", "half")
									end,
									children = { Text({ key = "btn_menu_label", text = "Menu", style = { width = "100%", height = "100%" } }) },
								}),
							},
						}),
						Box({
							key = "buttons_row_options",
							style = { height = 64, flex_direction = "row", gap = 15 },
							color = "rgba(0, 0, 0, 0)",
							children = {
								Button({
									key = "btn_options_half",
									style = { width = 160, height = 54 },
									color = rgba(0.42, 0.36, 0.62, 1),
									on_click = function()
										open_sheet(params, navigation, "options", "half")
									end,
									children = { Text({ key = "btn_options_half_label", text = "Options Half", style = { width = "100%", height = "100%" } }) },
								}),
								Button({
									key = "btn_options_full",
									style = { width = 160, height = 54 },
									color = rgba(0.46, 0.40, 0.70, 1),
									on_click = function()
										open_sheet(params, navigation, "options", "full")
									end,
									children = { Text({ key = "btn_options_full_label", text = "Options Full", style = { width = "100%", height = "100%" } }) },
								}),
							},
						}),
						Box({
							key = "api_box",
							style = { width = "84%", height = 132, padding = 15, flex_direction = "column", gap = 8 },
							color = rgba(0.1, 0.1, 0.15, 1),
							children = {
								Text({
									key = "api_text_1",
									text = "Host init: flow.bottom_sheet.init(self, { id, sheet, open_message_id, ... })",
									style = { height = 22 },
								}),
								Text({
									key = "api_text_2",
									text = "Open: msg.post(host_url, OPEN_MESSAGE_ID, { params = {...} })",
									style = { height = 22 },
								}),
								Text({
									key = "api_text_3",
									text = "Dismiss results return through the host on_dismiss callback.",
									style = { height = 22 },
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
