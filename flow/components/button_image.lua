-- flow/components/button_image.lua
-- Image-backed button convenience wrapper for the Flow library.
-- Uses the same primitive/runtime behavior as Button, but requires an image.
local Button = require "flow/components/button"

---@param t Flow.ButtonImageProps
---@return Flow.Element
local function ButtonImage(t)
	assert(t and t.image, "ButtonImage requires an image")
	if t.texture == nil then
		t.texture = "icons"
	end
	if t.color == nil then
		t.color = vmath.vector4(1, 1, 1, 1)
	end
	return Button(t)
end

return ButtonImage
