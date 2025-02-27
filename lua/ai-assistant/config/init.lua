local defaults = require("ai-assistant.utils.config.defaults")
local utils = require("ai-assistant.utils")
local log = utils.log
local path = utils.path
local fs = utils.fs

local M = {
  _config = nil,
  _initialized = false,
}

local function ensure_config_paths(config)
  for _, dir in pairs(config.path) do
    fs.mkdir_p(dir)
  end
end

local function validate_provider_config(config)
  local provider_name = config.provider.default
  local provider = config.provider[provider_name]
  
  if not provider then
    log.error("Default provider '%s' not found in configuration", provider_name)
    config.provider.default = "openai"
    return false
  end
  
  if not provider.api_key or provider.api_key == "" then
    log.warn("API key not configured for provider '%s'", provider_name)
    return false
  end
  
  return true
end

function M.setup(opts)
  if M._initialized then
    log.warn("Configuration already initialized")
    return M._config
  end
  
  -- Use vim.v.lua to get the version of this neovim instance
  if vim.v.version < 7 then
    -- Neovim 0.7.0 is the minimum supported version
    log.error("Neovim 0.7.0 or higher is required for this plugin")
    return nil
  end
  
  -- Deep merge provided config with defaults
  opts = opts or {}
  local config = utils.tbl_deep_extend("force", defaults, opts)
  
  -- Ensure configuration paths exist
  ensure_config_paths(config)
  
  -- Set up logging first
  log.setup({
    level = config.log.level,
    file = config.log.file or path.join(config.path.logs, "ai-assistant.log"),
  })
  
  -- Basic validation
  if not validate_provider_config(config) then
    log.warn("Provider configuration is invalid or incomplete")
  end
  
  -- Initialize file paths
  M._config = config
  M._initialized = true
  
  log.debug("Configuration initialized successfully")
  return M._config
end

function M.get()
  if not M._initialized then
    error("Configuration not initialized. Call setup() first.")
  end
  return M._config
end

function M.get_provider_config(provider_name)
  if not M._initialized then
    error("Configuration not initialized. Call setup() first.")
  end
  
  provider_name = provider_name or M._config.provider.default
  return M._config.provider[provider_name]
end

function M.update(updated_config)
  if not M._initialized then
    error("Configuration not initialized. Call setup() first.")
  end
  
  M._config = utils.tbl_deep_extend("force", M._config, updated_config)
  return M._config
end

function M.reset()
  M._config = utils.tbl_deep_extend("force", {}, defaults)
  M._initialized = true
  return M._config
end

return M
