local M = {}

M.panel = require("ai-assistant.ui.panel")

function M.setup()
  local has_nui, nui = pcall(require, "nui.popup")
  if not has_nui then
    require("ai-assistant.utils.log").warn("nui.nvim is required for UI components")
    return false
  end
  
  return true
end

return M
