local utils = require("ai-assistant.utils")
local log = utils.log
local config = require("ai-assistant.config")
local provider = require("ai-assistant.provider")
local context = require("ai-assistant.context")
local commands = require("ai-assistant.core.commands")

local M = {
  _initialized = false,
}

function M.setup(opts)
  if M._initialized then
    log.warn("AI Assistant is already initialized")
    return true
  end
  
  -- Initialize configuration
  local cfg = config.setup(opts)
  if not cfg then
    log.error("Failed to initialize configuration")
    return false
  end
  
  -- Set up logging
  log.setup(cfg.log)
  log.info("Initializing AI Assistant")
  
  -- Initialize provider
  local provider_ok = provider.setup()
  if not provider_ok then
    log.error("Failed to initialize provider")
    return false
  end
  
  -- Initialize context
  local context_ok = context.setup()
  if not context_ok then
    log.error("Failed to initialize context")
    return false
  end
  
  -- Register commands
  local commands_ok = commands.setup()
  if not commands_ok then
    log.error("Failed to register commands")
    return false
  end
  
  M._initialized = true
  log.info("AI Assistant initialized successfully")
  return true
end

function M.is_initialized()
  return M._initialized
end

-- Health check function (for :checkhealth)
function M.check_health()
  vim.health.start("AI Assistant")
  
  if not M._initialized then
    vim.health.error("AI Assistant is not initialized")
    return
  end
  
  -- Check configuration
  local cfg = config.get()
  if not cfg then
    vim.health.error("Configuration is not initialized")
  else
    vim.health.ok("Configuration loaded")
  end
  
  -- Check provider
  local current_provider = provider.get_current()
  if not current_provider then
    vim.health.error("No AI provider available")
  else
    vim.health.ok("Using provider: " .. current_provider.name)
    
    if current_provider.is_available() then
      vim.health.ok("Provider is available")
    else
      vim.health.error("Provider is not available. Check API key and connectivity.")
    end
  end
  
  -- Check dependencies
  local dependencies = {
    { name = "curl", check = function() return vim.fn.executable("curl") == 1 end },
    { name = "nui.nvim", check = function() return pcall(require, "nui.popup") end },
    { name = "plenary.nvim", check = function() return pcall(require, "plenary.job") end },
  }
  
  for _, dep in ipairs(dependencies) do
    if dep.check() then
      vim.health.ok(dep.name .. " is installed")
    else
      vim.health.error(dep.name .. " is required but not found")
    end
  end
  
  -- Check optional integrations
  local integrations = {
    { name = "telescope.nvim", check = function() return pcall(require, "telescope") end },
    { name = "nvim-treesitter", check = function() return pcall(require, "nvim-treesitter") end },
    { name = "nvim-notify", check = function() return pcall(require, "notify") end },
  }
  
  for _, integration in ipairs(integrations) do
    if integration.check() then
      vim.health.ok(integration.name .. " integration is available")
    else
      vim.health.info(integration.name .. " integration is not available (optional)")
    end
  end
end

return M
