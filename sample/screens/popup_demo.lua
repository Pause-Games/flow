local flow = require "flow/flow"
local rgba = flow.color.rgba

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Popup = flow.ui.cp.Popup
local Scroll = flow.ui.cp.Scroll
local Text = flow.ui.cp.Text

local C = {
	bg = rgba(0.08, 0.09, 0.13, 1),
	header = rgba(0.10, 0.12, 0.18, 1),
	panel = rgba(0.12, 0.15, 0.22, 1),
	panel_alt = rgba(0.15, 0.18, 0.27, 1),
	muted = rgba(0.78, 0.82, 0.90, 1),
	red = rgba(0.78, 0.29, 0.29, 1),
	orange = rgba(0.86, 0.50, 0.15, 1),
	yellow = rgba(0.83, 0.76, 0.29, 1),
	green = rgba(0.25, 0.60, 0.40, 1),
	blue = rgba(0.28, 0.48, 0.78, 1),
	purple = rgba(0.53, 0.41, 0.78, 1),
}

local function label(key, text, h, color, font, align, width)
	return Text({
		key = key,
		text = text,
		color = color,
		font = font,
		align = align,
		style = { width = width, height = h },
	})
end

local function status_row(key, title, value, color)
	return Box({
		key = key,
		style = { height = 26, flex_direction = "row", gap = 8 },
		color = rgba(0, 0, 0, 0),
		children = {
			label(key .. "_title", title, 22, C.muted, nil, nil, 92),
			label(key .. "_value", value, 22, color),
		},
	})
end

local function action_button(key, text, color, on_click)
	return Button({
		key = key,
		style = { flex_grow = 1, height = 52, align_items = "center", justify_content = "center" },
		color = color,
		on_click = on_click,
		children = {
			label(key .. "_label", text, 28, nil, nil, "center", "100%"),
		},
	})
end

local function popup_shell(key, title, subtitle, body_children, tone_color, height)
	local children = {
		Box({
			key = key .. "_hero",
			style = { height = 58, flex_direction = "row", gap = 12, align_items = "center" },
			color = rgba(0, 0, 0, 0),
			children = {
				Box({
					key = key .. "_badge",
					style = { width = 42, height = 42 },
					color = tone_color,
				}),
				Box({
					key = key .. "_titles",
					style = { flex_grow = 1, flex_direction = "column", gap = 4 },
					color = rgba(0, 0, 0, 0),
					children = {
						label(key .. "_title", title, 28, nil, "heading"),
						label(key .. "_subtitle", subtitle, 18, C.muted),
					},
				}),
			},
		}),
	}

	for _, child in ipairs(body_children) do
		children[#children + 1] = child
	end

	return Box({
		key = key,
		style = { width = "82%", height = height, flex_direction = "column", gap = 14, padding = 20 },
		color = C.panel,
		children = children,
	})
end

return {
	view = function(params, navigation)
		params = params or {}
		if params.popup_visible == nil then
			params.popup_visible = false
		end
		if params.popup_type == nil then
			params.popup_type = "confirm"
		end
		if params.message == nil then
			params.message = "Choose a popup pattern"
		end
		if params.last_close == nil then
			params.last_close = "none"
		end

		local function close_popup(message, close_reason)
			if message then
				params.message = message
			end
			params.last_close = close_reason or "action"
			params.popup_visible = false
			navigation.invalidate()
		end

		local function open_popup(kind, message)
			params.popup_type = kind
			params.popup_visible = true
			params.message = message
			navigation.invalidate()
		end

		local popup_content
		if params.popup_type == "confirm" then
			popup_content = popup_shell(
				"popup_confirm",
				"Confirm Action",
				"Use this for destructive or irreversible actions.",
				{
					label("popup_confirm_message", "Are you sure you want to archive this item?", 24),
					Box({
						key = "popup_confirm_note",
						style = { height = 48, padding = 12, justify_content = "center" },
						color = C.panel_alt,
						children = {
							label("popup_confirm_note_text", "The backdrop is clickable, so the user always has a fast escape route.", 22, C.muted),
						},
					}),
					Box({
						key = "popup_confirm_actions",
						style = { height = 54, flex_direction = "row", gap = 10 },
						color = rgba(0, 0, 0, 0),
						children = {
							action_button("popup_confirm_cancel", "Cancel", C.red, function()
								close_popup("Cancelled archive action", "cancel")
							end),
							action_button("popup_confirm_ok", "Archive", C.green, function()
								close_popup("Archived successfully", "confirm")
							end),
						},
					}),
				},
				C.orange,
				276
			)
		elseif params.popup_type == "alert" then
			popup_content = popup_shell(
				"popup_alert",
				"System Alert",
				"Good for notifications that need acknowledgement.",
				{
					Box({
						key = "popup_alert_message_box",
						style = { height = 74, padding = 14, justify_content = "center" },
						color = C.panel_alt,
						children = {
							label("popup_alert_message", "A sync task finished with warnings. Review the summary before continuing.", 44, nil, nil, "center", "100%"),
						},
					}),
					Box({
						key = "popup_alert_meta",
						style = { height = 26, justify_content = "center" },
						color = rgba(0, 0, 0, 0),
						children = {
							label("popup_alert_meta_text", "Warnings: 2   Updated: now", 22, C.muted, nil, "center", "100%"),
						},
					}),
					Button({
						key = "popup_alert_ok",
						style = { width = "100%", height = 50, align_items = "center", justify_content = "center" },
						color = C.blue,
						on_click = function()
							close_popup("Alert acknowledged", "acknowledge")
						end,
						children = {
							label("popup_alert_ok_label", "OK", 26, nil, nil, "center", "100%"),
						},
					}),
				},
				C.red,
				290
			)
		elseif params.popup_type == "form" then
			popup_content = popup_shell(
				"popup_settings",
				"Settings Form",
				"A denser popup layout with multiple rows and two actions.",
				{
					Box({
						key = "popup_settings_fields",
						style = { height = 112, flex_direction = "column", gap = 8 },
						color = rgba(0, 0, 0, 0),
						children = {
							status_row("settings_sound", "Sound", "Enabled", C.green),
							status_row("settings_music", "Music", "Ambient", C.yellow),
							status_row("settings_haptics", "Haptics", "Minimal", C.blue),
							status_row("settings_language", "Language", "English", C.purple),
						},
					}),
					Box({
						key = "popup_settings_note",
						style = { height = 66, padding = 10, flex_direction = "column", gap = 4, justify_content = "center" },
						color = C.panel_alt,
						children = {
							label("popup_settings_note_text_a", "Form popups should stay compact.", 20, C.muted),
							label("popup_settings_note_text_b", "For larger flows, prefer a full screen or bottom sheet.", 20, C.muted),
						},
					}),
					Box({
						key = "popup_settings_actions",
						style = { height = 54, flex_direction = "row", gap = 10 },
						color = rgba(0, 0, 0, 0),
						children = {
							action_button("popup_settings_cancel", "Cancel", C.red, function()
								close_popup("Settings were not saved", "cancel")
							end),
							action_button("popup_settings_save", "Save", C.blue, function()
								close_popup("Settings saved", "save")
							end),
						},
					}),
				},
				C.purple,
				372
			)
		else
			popup_content = popup_shell(
				"popup_blocking",
				"Blocking Modal",
				"This one can only close through its explicit action button.",
				{
					Box({
						key = "popup_blocking_message_box",
						style = { height = 88, padding = 14, flex_direction = "column", gap = 6, justify_content = "center" },
						color = C.panel_alt,
						children = {
							label("popup_blocking_message_a", "Finish reading this critical notice before continuing.", 22, nil, nil, "center", "100%"),
							label("popup_blocking_message_b", "Tapping outside does nothing in this case.", 22, C.muted, nil, "center", "100%"),
						},
					}),
					Box({
						key = "popup_blocking_meta",
						style = { height = 48, padding = 10, justify_content = "center" },
						color = C.panel_alt,
						children = {
							label("popup_blocking_meta_text", "Use sparingly: blocking modals are appropriate only when dismissal must be acknowledged.", 22, C.muted, nil, "center", "100%"),
						},
					}),
					Button({
						key = "popup_blocking_ack",
						style = { width = "100%", height = 50, align_items = "center", justify_content = "center" },
						color = C.orange,
						on_click = function()
							close_popup("Blocking modal acknowledged", "acknowledge")
						end,
						children = {
							label("popup_blocking_ack_label", "I Understand", 26, nil, nil, "center", "100%"),
						},
					}),
				},
				C.orange,
				306
			)
		end

		local children = {
			Box({
				key = "header",
				style = { height = 64, flex_direction = "row", gap = 10, align_items = "center", padding_left = 12, padding_right = 12 },
				color = C.header,
				children = {
					Button({
						key = "btn_back",
						style = { width = 84, height = 42 },
						color = C.red,
						on_click = function()
							navigation.pop("slide_right")
						end,
						children = {
							label("btn_back_label", "BACK", 24),
						},
					}),
					Text({
						key = "title",
						text = "Popup Demo",
						font = "heading",
						style = { flex_grow = 1, height = 32 },
					}),
				},
			}),
			Scroll({
				key = "popup_demo_scroll",
				style = { flex_grow = 1, flex_direction = "column", gap = 16, padding = 16 },
				color = C.bg,
				children = {
					Box({
						key = "hero",
						style = { height = 88, flex_direction = "column", gap = 8, padding = 16 },
						color = C.panel,
						children = {
							label("hero_title", "Three popup patterns", 28, nil, "heading"),
							label("hero_copy", "Use confirm for decisions, alert for acknowledgements, and compact forms for short edits.", 18, C.muted),
						},
					}),
					Box({
						key = "status_card",
						style = { height = 132, flex_direction = "column", gap = 8, padding = 14 },
						color = C.panel,
						children = {
							label("status_title", "Current Demo State", 24, nil, "heading"),
							status_row("status_popup_kind", "Type", params.popup_type, C.blue),
							status_row("status_last_close", "Last close", params.last_close, C.orange),
						},
					}),
					Box({
						key = "trigger_intro",
						style = { height = 44, flex_direction = "column", gap = 4 },
						color = rgba(0, 0, 0, 0),
						children = {
							label("trigger_title", "Open A Popup", 24, nil, "heading"),
							label("trigger_copy", "The trigger area stays responsive on narrower screens by stacking buttons vertically.", 16, C.muted),
						},
					}),
					Box({
						key = "trigger_buttons",
						style = { height = 252, flex_direction = "column", gap = 12 },
						color = rgba(0, 0, 0, 0),
						children = {
							Button({
								key = "btn_confirm",
								style = { height = 54, align_items = "center", justify_content = "center" },
								color = C.green,
								on_click = function()
									open_popup("confirm", "Opened confirm popup")
								end,
								children = {
									label("btn_confirm_label", "Confirm Dialog", 28, nil, nil, "center", "100%"),
								},
							}),
							Button({
								key = "btn_alert",
								style = { height = 54, align_items = "center", justify_content = "center" },
								color = C.orange,
								on_click = function()
									open_popup("alert", "Opened alert popup")
								end,
								children = {
									label("btn_alert_label", "Alert Popup", 28, nil, nil, "center", "100%"),
								},
							}),
							Button({
								key = "btn_form",
								style = { height = 54, align_items = "center", justify_content = "center" },
								color = C.purple,
								on_click = function()
									open_popup("form", "Opened settings popup")
								end,
								children = {
									label("btn_form_label", "Settings Form", 28, nil, nil, "center", "100%"),
								},
							}),
							Button({
								key = "btn_blocking",
								style = { height = 54, align_items = "center", justify_content = "center" },
								color = C.orange,
								on_click = function()
									open_popup("blocking", "Opened blocking modal")
								end,
								children = {
									label("btn_blocking_label", "Blocking Modal", 28, nil, nil, "center", "100%"),
								},
							}),
						},
					}),
					Box({
						key = "guidance_card",
						style = { height = 168, flex_direction = "column", gap = 10, padding = 16 },
						color = C.panel_alt,
						children = {
							label("guidance_title", "When to use which popup", 24, nil, "heading"),
							label("guidance_line_a", "Confirm: ask before a costly action.", 18, C.muted),
							label("guidance_line_b", "Alert: communicate a result or warning.", 18, C.muted),
							label("guidance_line_c", "Form: keep edits short and obvious.", 18, C.muted),
							label("guidance_line_d", "Blocking: require an explicit acknowledgement; do not allow backdrop dismissal.", 18, C.muted),
						},
					}),
					Box({
						key = "message_card",
						style = { height = 92, flex_direction = "column", gap = 8, padding = 14 },
						color = C.panel,
						children = {
							label("message_title", "Last Message", 22, nil, "heading"),
							label("message_value", params.message, 34, C.muted),
						},
					}),
				},
			}),
		}

		if params.popup_visible then
			local overlay = {
				key = "popup_overlay",
				style = { width = "100%", height = "100%", align_items = "center", justify_content = "center", padding_left = 12, padding_right = 12 },
				backdrop_color = rgba(0, 0, 0, 0.72),
				children = { popup_content },
			}
			if params.popup_type ~= "blocking" then
				overlay.on_backdrop_click = function()
					close_popup("Closed by backdrop click", "backdrop")
				end
			end
			children[#children + 1] = Popup(overlay)
		end

		return Box({
			key = "popup_demo_root",
			style = { width = "100%", height = "100%", flex_direction = "column", gap = 0 },
			color = C.bg,
			children = children,
		})
	end,
}
