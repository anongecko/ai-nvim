local core = require("ai-assistant.core")

local M = {}

function M.check()
  core.check_health()
end

return M
