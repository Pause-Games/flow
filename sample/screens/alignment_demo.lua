local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		return Box({
			key = "align_root",
			style = { width="100%", height="100%", flex_direction="column", gap=8, padding=10 },
			color = vmath.vector4(0.1, 0.15, 0.1, 1),
			children = {
				-- Header
				Box({
					key="header",
					style={ height=60, flex_direction="row", gap=8, align_items="center" },
					color=vmath.vector4(0.2, 0.2, 0.2, 0.8),
					children = {
						Button({
							key="btn_back",
							style={ width=80, height=40 },
							color=vmath.vector4(0.8, 0.3, 0.3, 1),
							on_click = function()
								navigation.pop("slide_right")
							end,
							children = {
								Text({
									key="btn_back_label",
									text="BACK",
									style={ width="100%", height="100%" }
								})
							}
						}),
						Text({
							key="title",
							text="Alignment Demo",
							style={ flex_grow=1, height=40 }
						})
					}
				}),
				-- align_items: start
				Box({
					key="align_start",
					style={ flex_grow=1, flex_direction="row", gap=8, align_items="start" },
					color=vmath.vector4(0.2, 0.2, 0.2, 0.3),
					children = {
						Box({ key="as1", style={ width=60, height=40 }, color=vmath.vector4(0.8, 0.3, 0.3, 1) }),
						Box({ key="as2", style={ width=60, height=60 }, color=vmath.vector4(0.3, 0.8, 0.3, 1) }),
						Box({ key="as3", style={ width=60, height=50 }, color=vmath.vector4(0.3, 0.3, 0.8, 1) })
					}
				}),
				-- align_items: center
				Box({
					key="align_center",
					style={ flex_grow=1, flex_direction="row", gap=8, align_items="center" },
					color=vmath.vector4(0.2, 0.2, 0.2, 0.3),
					children = {
						Box({ key="ac1", style={ width=60, height=40 }, color=vmath.vector4(0.8, 0.3, 0.3, 1) }),
						Box({ key="ac2", style={ width=60, height=60 }, color=vmath.vector4(0.3, 0.8, 0.3, 1) }),
						Box({ key="ac3", style={ width=60, height=50 }, color=vmath.vector4(0.3, 0.3, 0.8, 1) })
					}
				}),
				-- align_items: end
				Box({
					key="align_end",
					style={ flex_grow=1, flex_direction="row", gap=8, align_items="end" },
					color=vmath.vector4(0.2, 0.2, 0.2, 0.3),
					children = {
						Box({ key="ae1", style={ width=60, height=40 }, color=vmath.vector4(0.8, 0.3, 0.3, 1) }),
						Box({ key="ae2", style={ width=60, height=60 }, color=vmath.vector4(0.3, 0.8, 0.3, 1) }),
						Box({ key="ae3", style={ width=60, height=50 }, color=vmath.vector4(0.3, 0.3, 0.8, 1) })
					}
				})
			}
		})
	end
}
