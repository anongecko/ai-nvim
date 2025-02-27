local core = require("ai-assistant.core")
local api = require("ai-assistant.core.api")
local utils = require("ai-assistant.utils")
local log = utils.log

local M = {
  _VERSION = "0.1.0",
}

function M.setup(opts)
  if core.is_initialized() then
    log.warn("AI Assistant is already initialized")
    return M
  end
  
  -- Initialize core components
  local ok = core.setup(opts)
  if not ok then
    log.error("Failed to initialize AI Assistant")
    return M
  end
  
  return M
end

-- API functions
M.query = api.query
M.stream_query = api.stream_query
M.cancel_query = api.cancel_query
M.get_current_provider = api.get_current_provider
M.set_provider = api.set_provider
M.list_available_providers = api.list_available_providers
M.open_panel = api.open_panel
M.close_panel = api.close_panel
M.toggle_panel = api.toggle_panel
M.explain_code = api.explain_code
M.refactor_code = api.refactor_code
M.document_code = api.document_code
M.generate_tests = api.generate_tests
M.clear_context_cache = api.clear_context_cache

return M
