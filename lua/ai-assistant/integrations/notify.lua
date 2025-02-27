local config = require("ai-assistant.config")
local log = require("ai-assistant.utils.log")

local M = {
  _notify = nil,
  _initialized = false
}

function M.setup()
  local ok, notify = pcall(require, "notify")
  if not ok then
    log.debug("nvim-notify is not available")
    return false
  end
  
  M._notify = notify
  M._initialized = true
  
  -- Override the log functions to use notify
  log.original_info = log.info
  log.original_warn = log.warn
  log.original_error = log.error
  
  log.info = function(msg, ...)
    msg = string.format(msg, ...)
    log.original_info(msg)
    if M._initialized and M._notify then
      local cfg = config.get()
      M._notify(msg, "info", {
        title = "AI Assistant",
        timeout = cfg.ui.notification.timeout,
      })
    end
  end
  
  log.warn = function(msg, ...)
    msg = string.format(msg, ...)
    log.original_warn(msg)
    if M._initialized and M._notify then
      local cfg = config.get()
      M._notify(msg, "warn", {
        title = "AI Assistant",
        timeout = cfg.ui.notification.timeout,
      })
    end
  end
  
  log.error = function(msg, ...)
    msg = string.format(msg, ...)
    log.original_error(msg)
    if M._initialized and M._notify then
      local cfg = config.get()
      M._notify(msg, "error", {
        title = "AI Assistant",
        timeout = cfg.ui.notification.timeout,
      })
    end
  end
  
  return true
end

function M.notify(message, level, options)
  if not M._initialized or not M._notify then
    -- Fallback to vim.notify
    vim.notify(message, vim.log.levels[level:upper()] or vim.log.levels.INFO)
    return
  end
  
  options = options or {}
  options.title = options.title or "AI Assistant"
  
  if not options.timeout then
    local cfg = config.get()
    options.timeout = cfg.ui.notification.timeout
  end
  
  M._notify(message, level, options)
end

function M.info(message, options)
  M.notify(message, "info", options)
end

function M.warn(message, options)
  M.notify(message, "warn", options)
end

function M.error(message, options)
  M.notify(message, "error", options)
end

return M
