local M = {}

M.OPEN_MESSAGE_ID = hash("sample_bottom_sheet_open")
M.CLOSE_MESSAGE_ID = hash("sample_bottom_sheet_close")
M.DISMISSED_MESSAGE_ID = hash("sample_bottom_sheet_dismissed")

function M.host_url()
	return msg.url("main:/bottom_sheet_host#bottom_sheet_host")
end

function M.background_url()
	return msg.url("main:/go#sample1")
end

return M
