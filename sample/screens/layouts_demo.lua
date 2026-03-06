local flow = require "flow/flow"

local Box = flow.ui.cp.Box
local Button = flow.ui.cp.Button
local Text = flow.ui.cp.Text


return {
	view = function(params, navigation)
		return Box({
			key = "layouts_root",
			style = { width="100%", height="100%", flex_direction="column", gap=8, padding=10 },
			color = vmath.vector4(0.15, 0.1, 0.15, 1),
			children = {
				-- Header with back button
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
							text="Layouts Demo",
							style={ flex_grow=1, height=40 }
						})
					}
				}),
				-- Row layout demo
				Box({
					key="row_demo",
					style={ height=100, flex_direction="row", gap=8 },
					children = {
						Box({ key="r1", style={ flex_grow=1 }, color=vmath.vector4(0.8, 0.2, 0.2, 0.5) }),
						Box({ key="r2", style={ flex_grow=2 }, color=vmath.vector4(0.2, 0.8, 0.2, 0.5) }),
						Box({ key="r3", style={ flex_grow=1 }, color=vmath.vector4(0.2, 0.2, 0.8, 0.5) })
					}
				}),
				-- Column layout demo
				Box({
					key="col_demo",
					style={ flex_grow=1, flex_direction="column", gap=8 },
					children = {
						Box({ key="c1", style={ flex_grow=1 }, color=vmath.vector4(0.8, 0.8, 0.2, 0.5) }),
						Box({ key="c2", style={ flex_grow=1 }, color=vmath.vector4(0.2, 0.8, 0.8, 0.5) }),
						Box({ key="c3", style={ flex_grow=1 }, color=vmath.vector4(0.8, 0.2, 0.8, 0.5) })
					}
				})
			}
		})
	end
}
